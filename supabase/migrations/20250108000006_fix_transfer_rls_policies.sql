-- =============================================================================
-- إصلاح سياسات RLS لنظام التحويلات
-- تاريخ الإنشاء: 2025-01-08
-- =============================================================================

-- إصلاح سياسات جدول حدود التحويل
DROP POLICY IF EXISTS "Users can view own transfer limits" ON public.transfer_limits;
DROP POLICY IF EXISTS "Users can insert own transfer limits" ON public.transfer_limits;
DROP POLICY IF EXISTS "Users can update own transfer limits" ON public.transfer_limits;

-- سياسة عرض حدود التحويل
CREATE POLICY "Users can view own transfer limits" ON public.transfer_limits
    FOR SELECT USING (auth.uid() = user_id);

-- سياسة إدراج حدود التحويل (للمستخدمين الجدد)
CREATE POLICY "Users can insert own transfer limits" ON public.transfer_limits
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- سياسة تحديث حدود التحويل
CREATE POLICY "Users can update own transfer limits" ON public.transfer_limits
    FOR UPDATE USING (auth.uid() = user_id);

-- إصلاح سياسات جدول طلبات التحويل
DROP POLICY IF EXISTS "Users can view own transfer requests" ON public.transfer_requests;
DROP POLICY IF EXISTS "Users can create transfer requests" ON public.transfer_requests;
DROP POLICY IF EXISTS "Users can update own transfer requests" ON public.transfer_requests;

-- سياسة عرض طلبات التحويل
CREATE POLICY "Users can view own transfer requests" ON public.transfer_requests
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- سياسة إنشاء طلبات التحويل
CREATE POLICY "Users can create transfer requests" ON public.transfer_requests
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- سياسة تحديث طلبات التحويل (للنظام)
CREATE POLICY "Users can update own transfer requests" ON public.transfer_requests
    FOR UPDATE USING (auth.uid() = sender_id);

-- إصلاح سياسات جدول التحويلات المكتملة
DROP POLICY IF EXISTS "Users can view own completed transfers" ON public.completed_transfers;
DROP POLICY IF EXISTS "Users can insert completed transfers" ON public.completed_transfers;

-- سياسة عرض التحويلات المكتملة
CREATE POLICY "Users can view own completed transfers" ON public.completed_transfers
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- سياسة إدراج التحويلات المكتملة (للنظام)
CREATE POLICY "Users can insert completed transfers" ON public.completed_transfers
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- إصلاح سياسات دليل المستخدمين
DROP POLICY IF EXISTS "Users can search directory" ON public.user_directory;
DROP POLICY IF EXISTS "Users can view directory" ON public.user_directory;

-- سياسة البحث في دليل المستخدمين - السماح للجميع
CREATE POLICY "Users can search directory" ON public.user_directory
    FOR SELECT USING (true);

-- تحديث دالة التحقق من حدود التحويل لتتعامل مع RLS
CREATE OR REPLACE FUNCTION public.check_transfer_limits(
    p_user_id UUID,
    p_amount DECIMAL
)
RETURNS TABLE(
    can_transfer BOOLEAN,
    error_message TEXT,
    daily_remaining DECIMAL,
    monthly_remaining DECIMAL
) 
SECURITY DEFINER
AS $$
DECLARE
    v_limits RECORD;
    v_daily_remaining DECIMAL;
    v_monthly_remaining DECIMAL;
BEGIN
    -- جلب حدود المستخدم أو إنشاؤها
    SELECT * INTO v_limits
    FROM public.transfer_limits
    WHERE user_id = p_user_id;
    
    -- إنشاء حدود افتراضية إذا لم تكن موجودة
    IF v_limits IS NULL THEN
        INSERT INTO public.transfer_limits (user_id)
        VALUES (p_user_id)
        RETURNING * INTO v_limits;
    END IF;
    
    -- إعادة تعيين الحدود اليومية والشهرية إذا لزم الأمر
    IF v_limits.last_reset_date < CURRENT_DATE THEN
        UPDATE public.transfer_limits
        SET daily_used = 0,
            monthly_used = CASE 
                WHEN EXTRACT(MONTH FROM v_limits.last_reset_date) != EXTRACT(MONTH FROM CURRENT_DATE)
                     OR EXTRACT(YEAR FROM v_limits.last_reset_date) != EXTRACT(YEAR FROM CURRENT_DATE)
                THEN 0
                ELSE monthly_used
            END,
            last_reset_date = CURRENT_DATE,
            updated_at = NOW()
        WHERE user_id = p_user_id
        RETURNING * INTO v_limits;
    END IF;
    
    -- حساب المتبقي
    v_daily_remaining := COALESCE(v_limits.daily_limit, 50000) - COALESCE(v_limits.daily_used, 0);
    v_monthly_remaining := COALESCE(v_limits.monthly_limit, 500000) - COALESCE(v_limits.monthly_used, 0);
    
    -- التحقق من الحدود
    IF p_amount > COALESCE(v_limits.single_transfer_limit, 100000) THEN
        RETURN QUERY SELECT FALSE, 'المبلغ يتجاوز الحد الأقصى للتحويل الواحد (' || COALESCE(v_limits.single_transfer_limit, 100000) || ' دج)', v_daily_remaining, v_monthly_remaining;
        RETURN;
    END IF;
    
    IF p_amount > v_daily_remaining THEN
        RETURN QUERY SELECT FALSE, 'المبلغ يتجاوز الحد اليومي المتبقي (' || v_daily_remaining || ' دج)', v_daily_remaining, v_monthly_remaining;
        RETURN;
    END IF;
    
    IF p_amount > v_monthly_remaining THEN
        RETURN QUERY SELECT FALSE, 'المبلغ يتجاوز الحد الشهري المتبقي (' || v_monthly_remaining || ' دج)', v_daily_remaining, v_monthly_remaining;
        RETURN;
    END IF;
    
    RETURN QUERY SELECT TRUE, NULL::TEXT, v_daily_remaining, v_monthly_remaining;
END;
$$ LANGUAGE plpgsql;

-- تحديث دالة معالجة التحويلات لتتعامل مع RLS
CREATE OR REPLACE FUNCTION public.process_money_transfer(
    p_sender_id UUID,
    p_recipient_identifier TEXT,
    p_amount DECIMAL,
    p_currency TEXT DEFAULT 'dzd',
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    reference_number TEXT,
    sender_new_balance DECIMAL,
    recipient_new_balance DECIMAL,
    transfer_id UUID
) 
SECURITY DEFINER
AS $$
DECLARE
    v_sender_balance DECIMAL;
    v_recipient_info RECORD;
    v_limits_check RECORD;
    v_transfer_request_id UUID;
    v_reference_number TEXT;
    v_sender_new_balance DECIMAL;
    v_recipient_new_balance DECIMAL;
    v_recipient_balance DECIMAL;
    v_sender_info RECORD;
BEGIN
    -- تسجيل بداية العملية
    RAISE NOTICE 'بدء معالجة التحويل: المرسل=%, المستلم=%, المبلغ=%', p_sender_id, p_recipient_identifier, p_amount;
    
    -- التحقق من صحة المدخلات
    IF p_sender_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'معرف المرسل مطلوب', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    IF p_recipient_identifier IS NULL OR TRIM(p_recipient_identifier) = '' THEN
        RETURN QUERY SELECT FALSE, 'معرف المستلم مطلوب', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN QUERY SELECT FALSE, 'مبلغ التحويل يجب أن يكون أكبر من صفر', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    IF p_amount < 100 THEN
        RETURN QUERY SELECT FALSE, 'الحد الأدنى للتحويل هو 100 دج', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    -- التحقق من وجود المرسل
    SELECT * INTO v_sender_info
    FROM public.users
    WHERE id = p_sender_id;
    
    IF v_sender_info IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المرسل غير موجود', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    -- التحقق من رصيد المرسل
    SELECT dzd INTO v_sender_balance
    FROM public.balances
    WHERE user_id = p_sender_id;
    
    IF v_sender_balance IS NULL THEN
        RAISE NOTICE 'لم يتم العثور على رصيد المرسل، إنشاء رصيد جديد';
        -- إنشاء رصيد للمرسل إذا لم يكن موجوداً
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
        VALUES (p_sender_id, 0, 0, 0, 0);
        v_sender_balance := 0;
    END IF;
    
    RAISE NOTICE 'رصيد المرسل الحالي: %', v_sender_balance;
    
    IF v_sender_balance < p_amount THEN
        RETURN QUERY SELECT FALSE, 'الرصيد غير كافي لإجراء هذا التحويل (الرصيد الحالي: ' || v_sender_balance || ' دج)', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    -- التحقق من حدود التحويل
    SELECT * INTO v_limits_check
    FROM public.check_transfer_limits(p_sender_id, p_amount);
    
    IF NOT v_limits_check.can_transfer THEN
        RETURN QUERY SELECT FALSE, v_limits_check.error_message, NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    -- البحث عن المستلم
    -- البحث الدقيق بالبريد الإلكتروني المطبع
    RETURN QUERY
    SELECT 
        ud.user_id,
        ud.email,
        ud.full_name,
        ud.account_number,
        ud.can_receive_transfers,
        'exact_email'::TEXT as match_type
    FROM public.user_directory ud
    WHERE ud.email_normalized = normalized_identifier
    LIMIT 1;
    
    -- إذا لم يتم العثور على نتيجة، البحث برقم الحساب
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            ud.user_id,
            ud.email,
            ud.full_name,
            ud.account_number,
            ud.can_receive_transfers,
            'account_number'::TEXT as match_type
        FROM public.user_directory ud
        WHERE UPPER(ud.account_number) = UPPER(TRIM(identifier))
        LIMIT 1;
    END IF;
    
    -- إذا لم يتم العثور على نتيجة، البحث برقم الهاتف
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            ud.user_id,
            ud.email,
            ud.full_name,
            ud.account_number,
            ud.can_receive_transfers,
            'phone'::TEXT as match_type
        FROM public.user_directory ud
        WHERE ud.phone = TRIM(identifier)
        LIMIT 1;
    END IF;
    
    RAISE NOTICE 'تم العثور على المستلم: % (ID: %)', v_recipient_info.full_name, v_recipient_info.user_id;
    
    -- التحقق من أن المستلم يمكنه استقبال التحويلات
    IF NOT COALESCE(v_recipient_info.can_receive, true) THEN
        RETURN QUERY SELECT FALSE, 'المستلم لا يمكنه استقبال التحويلات حالياً', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    -- منع التحويل للنفس
    IF v_recipient_info.user_id = p_sender_id THEN
        RETURN QUERY SELECT FALSE, 'لا يمكن تحويل الأموال إلى نفس الحساب', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    -- إنشاء رقم مرجعي
    v_reference_number := public.generate_transfer_reference();
    RAISE NOTICE 'رقم المرجع المُنشأ: %', v_reference_number;
    
    -- جلب رصيد المستلم
    SELECT dzd INTO v_recipient_balance
    FROM public.balances
    WHERE user_id = v_recipient_info.user_id;
    
    IF v_recipient_balance IS NULL THEN
        RAISE NOTICE 'إنشاء رصيد جديد للمستلم';
        -- إنشاء رصيد للمستلم إذا لم يكن موجوداً
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
        VALUES (v_recipient_info.user_id, 0, 0, 0, 0);
        v_recipient_balance := 0;
    END IF;
    
    -- حساب الأرصدة الجديدة
    v_sender_new_balance := v_sender_balance - p_amount;
    v_recipient_new_balance := v_recipient_balance + p_amount;
    
    RAISE NOTICE 'الأرصدة الجديدة - المرسل: % -> %, المستلم: % -> %', 
        v_sender_balance, v_sender_new_balance, v_recipient_balance, v_recipient_new_balance;
    
    -- بدء المعاملة
    BEGIN
        -- إنشاء طلب التحويل
        INSERT INTO public.transfer_requests (
            sender_id,
            recipient_email,
            recipient_id,
            amount,
            currency,
            status,
            reference_number,
            description
        )
        VALUES (
            p_sender_id,
            v_recipient_info.email,
            v_recipient_info.user_id,
            p_amount,
            COALESCE(p_currency, 'dzd'),
            'processing',
            v_reference_number,
            COALESCE(p_description, 'تحويل أموال إلى ' || v_recipient_info.full_name)
        )
        RETURNING id INTO v_transfer_request_id;
        
        RAISE NOTICE 'تم إنشاء طلب التحويل: %', v_transfer_request_id;
        
        -- تحديث رصيد المرسل
        UPDATE public.balances
        SET dzd = v_sender_new_balance,
            updated_at = NOW()
        WHERE user_id = p_sender_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'فشل في تحديث رصيد المرسل';
        END IF;
        
        RAISE NOTICE 'تم تحديث رصيد المرسل';
        
        -- تحديث رصيد المستلم
        UPDATE public.balances
        SET dzd = v_recipient_new_balance,
            updated_at = NOW()
        WHERE user_id = v_recipient_info.user_id;
        
        IF NOT FOUND THEN
            RAISE EXCEPTION 'فشل في تحديث رصيد المستلم';
        END IF;
        
        RAISE NOTICE 'تم تحديث رصيد المستلم';
        
        -- تحديث حدود التحويل
        UPDATE public.transfer_limits
        SET daily_used = daily_used + p_amount,
            monthly_used = monthly_used + p_amount,
            updated_at = NOW()
        WHERE user_id = p_sender_id;
        
        -- إنشاء سجل التحويل المكتمل
        INSERT INTO public.completed_transfers (
            transfer_request_id,
            sender_id,
            recipient_id,
            amount,
            currency,
            reference_number,
            sender_balance_before,
            sender_balance_after,
            recipient_balance_before,
            recipient_balance_after
        )
        VALUES (
            v_transfer_request_id,
            p_sender_id,
            v_recipient_info.user_id,
            p_amount,
            COALESCE(p_currency, 'dzd'),
            v_reference_number,
            v_sender_balance,
            v_sender_new_balance,
            v_recipient_balance,
            v_recipient_new_balance
        );
        
        RAISE NOTICE 'تم إنشاء سجل التحويل المكتمل';
        
        -- تحديث حالة طلب التحويل
        UPDATE public.transfer_requests
        SET status = 'completed',
            processed_at = NOW(),
            updated_at = NOW()
        WHERE id = v_transfer_request_id;
        
        -- إنشاء سجلات المعاملات
        INSERT INTO public.transactions (user_id, type, amount, currency, description, recipient, reference, status)
        VALUES 
            (p_sender_id, 'transfer', p_amount, COALESCE(p_currency, 'dzd'), 'تحويل صادر إلى ' || v_recipient_info.full_name, v_recipient_info.email, v_reference_number, 'completed'),
            (v_recipient_info.user_id, 'transfer', p_amount, COALESCE(p_currency, 'dzd'), 'تحويل وارد من ' || v_sender_info.full_name, v_sender_info.email, v_reference_number, 'completed');
        
        RAISE NOTICE 'تم إنشاء سجلات المعاملات';
        
        -- إنشاء إشعارات
        INSERT INTO public.notifications (user_id, type, title, message)
        VALUES 
            (p_sender_id, 'success', 'تم إرسال التحويل', 'تم إرسال ' || p_amount || ' دج إلى ' || v_recipient_info.full_name || ' بنجاح'),
            (v_recipient_info.user_id, 'success', 'تم استلام تحويل', 'تم استلام ' || p_amount || ' دج من ' || v_sender_info.full_name);
        
        RAISE NOTICE 'تم إنشاء الإشعارات';
        
        -- إرجاع النتيجة الناجحة
        RAISE NOTICE 'تم التحويل بنجاح';
        RETURN QUERY SELECT TRUE, 'تم التحويل بنجاح', v_reference_number, v_sender_new_balance, v_recipient_new_balance, v_transfer_request_id;
        
    EXCEPTION WHEN OTHERS THEN
        -- في حالة حدوث خطأ، تحديث حالة طلب التحويل
        RAISE NOTICE 'خطأ في معالجة التحويل: %', SQLERRM;
        
        IF v_transfer_request_id IS NOT NULL THEN
            UPDATE public.transfer_requests
            SET status = 'failed',
                error_message = SQLERRM,
                updated_at = NOW()
            WHERE id = v_transfer_request_id;
        END IF;
        
        RETURN QUERY SELECT FALSE, 'خطأ في معالجة التحويل: ' || SQLERRM, NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
    END;
END;
$$ LANGUAGE plpgsql;

-- إنشاء حدود التحويل للمستخدمين الموجودين (مع تجاهل الأخطاء)
DO $$
BEGIN
    INSERT INTO public.transfer_limits (user_id)
    SELECT id FROM public.users
    WHERE id NOT IN (SELECT user_id FROM public.transfer_limits)
    ON CONFLICT (user_id) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'تم تجاهل خطأ في إنشاء حدود التحويل: %', SQLERRM;
END $$;