-- =============================================================================
-- تعديل سياسات RLS للسماح بالتحويل بين جميع الحسابات
-- تاريخ الإنشاء: 2025-01-08
-- الهدف: إزالة قيود حالة التفعيل من عمليات التحويل
-- =============================================================================

-- تحديث دالة البحث عن المستخدم لإزالة قيد is_active
CREATE OR REPLACE FUNCTION public.find_user_by_identifier(identifier TEXT)
RETURNS TABLE(
    user_id UUID,
    email TEXT,
    full_name TEXT,
    account_number TEXT,
    can_receive BOOLEAN,
    match_type TEXT
) AS $$
DECLARE
    normalized_identifier TEXT;
BEGIN
    normalized_identifier := public.normalize_email(identifier);
    
    -- البحث الدقيق بالبريد الإلكتروني المطبع (بدون قيد is_active)
    RETURN QUERY
    SELECT 
        ud.user_id,
        ud.email,
        ud.full_name,
        ud.account_number,
        COALESCE(ud.can_receive_transfers, true) as can_receive_transfers,
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
            COALESCE(ud.can_receive_transfers, true) as can_receive_transfers,
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
            COALESCE(ud.can_receive_transfers, true) as can_receive_transfers,
            'phone'::TEXT as match_type
        FROM public.user_directory ud
        WHERE ud.phone = TRIM(identifier)
        LIMIT 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- تحديث سياسة دليل المستخدمين للسماح بالوصول لجميع الحسابات
DROP POLICY IF EXISTS "Users can search directory" ON public.user_directory;
CREATE POLICY "Users can search directory" ON public.user_directory
    FOR SELECT USING (true);

-- تحديث دالة معالجة التحويلات لإزالة التحقق من حالة التفعيل
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
    
    -- البحث عن المستلم (بدون قيد حالة التفعيل)
    SELECT * INTO v_recipient_info
    FROM public.find_user_by_identifier(p_recipient_identifier)
    LIMIT 1;
    
    IF v_recipient_info IS NULL THEN
        RAISE NOTICE 'لم يتم العثور على المستلم: %', p_recipient_identifier;
        -- محاولة البحث المباشر في جدول المستخدمين (بدون قيد is_active)
        SELECT id as user_id, email, full_name, account_number, true as can_receive, 'direct_search'::TEXT as match_type
        INTO v_recipient_info
        FROM public.users
        WHERE LOWER(TRIM(email)) = LOWER(TRIM(p_recipient_identifier))
           OR UPPER(TRIM(account_number)) = UPPER(TRIM(p_recipient_identifier))
        LIMIT 1;
        
        IF v_recipient_info IS NULL THEN
            RETURN QUERY SELECT FALSE, 
                'لم يتم العثور على المستلم "' || p_recipient_identifier || '". تأكد من صحة البريد الإلكتروني أو رقم الحساب',
                NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
            RETURN;
        END IF;
    END IF;
    
    RAISE NOTICE 'تم العثور على المستلم: % (ID: %)', v_recipient_info.full_name, v_recipient_info.user_id;
    
    -- إزالة التحقق من can_receive_transfers - السماح للجميع
    -- IF NOT COALESCE(v_recipient_info.can_receive, true) THEN
    --     RETURN QUERY SELECT FALSE, 'المستلم لا يمكنه استقبال التحويلات حالياً', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
    --     RETURN;
    -- END IF;
    
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

-- =============================================================================
-- انتهاء تعديل سياسات RLS للسماح بالتحويل بين جميع الحسابات
-- =============================================================================
