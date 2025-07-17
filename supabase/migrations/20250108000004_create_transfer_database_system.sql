-- =============================================================================
-- نظام قاعدة البيانات المخصص للإرسال والاستقبال
-- تاريخ الإنشاء: 2025-01-08
-- الهدف: إنشاء نظام شامل ومتكامل لتحويل الأموال
-- =============================================================================

-- =============================================================================
-- إنشاء جداول النظام الجديد
-- =============================================================================

-- جدول طلبات التحويل
CREATE TABLE IF NOT EXISTS public.transfer_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    recipient_email TEXT NOT NULL,
    recipient_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    currency TEXT DEFAULT 'dzd' CHECK (currency IN ('dzd', 'eur', 'usd', 'gbp')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    transfer_type TEXT DEFAULT 'instant' CHECK (transfer_type IN ('instant', 'scheduled')),
    reference_number TEXT UNIQUE NOT NULL,
    description TEXT,
    fees DECIMAL(15,2) DEFAULT 0.00,
    exchange_rate DECIMAL(10,6) DEFAULT 1.000000,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- جدول سجل التحويلات المكتملة
CREATE TABLE IF NOT EXISTS public.completed_transfers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    transfer_request_id UUID REFERENCES public.transfer_requests(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    recipient_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    currency TEXT NOT NULL,
    fees DECIMAL(15,2) DEFAULT 0.00,
    reference_number TEXT NOT NULL,
    sender_balance_before DECIMAL(15,2) NOT NULL,
    sender_balance_after DECIMAL(15,2) NOT NULL,
    recipient_balance_before DECIMAL(15,2) NOT NULL,
    recipient_balance_after DECIMAL(15,2) NOT NULL,
    exchange_rate DECIMAL(10,6) DEFAULT 1.000000,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- جدول دليل المستخدمين للبحث السريع
CREATE TABLE IF NOT EXISTS public.user_directory (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    email TEXT NOT NULL,
    email_normalized TEXT NOT NULL, -- البريد الإلكتروني بعد التطبيع
    full_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    phone TEXT,
    is_active BOOLEAN DEFAULT true,
    can_receive_transfers BOOLEAN DEFAULT true,
    last_activity TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- جدول حدود التحويل
CREATE TABLE IF NOT EXISTS public.transfer_limits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    daily_limit DECIMAL(15,2) DEFAULT 50000.00,
    monthly_limit DECIMAL(15,2) DEFAULT 500000.00,
    single_transfer_limit DECIMAL(15,2) DEFAULT 100000.00,
    daily_used DECIMAL(15,2) DEFAULT 0.00,
    monthly_used DECIMAL(15,2) DEFAULT 0.00,
    last_reset_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- إنشاء الفهارس للأداء
-- =============================================================================

-- فهارس جدول طلبات التحويل
CREATE INDEX IF NOT EXISTS idx_transfer_requests_sender ON public.transfer_requests(sender_id);
CREATE INDEX IF NOT EXISTS idx_transfer_requests_recipient_email ON public.transfer_requests(recipient_email);
CREATE INDEX IF NOT EXISTS idx_transfer_requests_recipient_id ON public.transfer_requests(recipient_id);
CREATE INDEX IF NOT EXISTS idx_transfer_requests_status ON public.transfer_requests(status);
CREATE INDEX IF NOT EXISTS idx_transfer_requests_reference ON public.transfer_requests(reference_number);
CREATE INDEX IF NOT EXISTS idx_transfer_requests_created_at ON public.transfer_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transfer_requests_scheduled_at ON public.transfer_requests(scheduled_at);

-- فهارس جدول التحويلات المكتملة
CREATE INDEX IF NOT EXISTS idx_completed_transfers_sender ON public.completed_transfers(sender_id);
CREATE INDEX IF NOT EXISTS idx_completed_transfers_recipient ON public.completed_transfers(recipient_id);
CREATE INDEX IF NOT EXISTS idx_completed_transfers_reference ON public.completed_transfers(reference_number);
CREATE INDEX IF NOT EXISTS idx_completed_transfers_completed_at ON public.completed_transfers(completed_at DESC);

-- فهارس دليل المستخدمين
CREATE INDEX IF NOT EXISTS idx_user_directory_email ON public.user_directory(email);
CREATE INDEX IF NOT EXISTS idx_user_directory_email_normalized ON public.user_directory(email_normalized);
CREATE INDEX IF NOT EXISTS idx_user_directory_account_number ON public.user_directory(account_number);
CREATE INDEX IF NOT EXISTS idx_user_directory_phone ON public.user_directory(phone);
CREATE INDEX IF NOT EXISTS idx_user_directory_active ON public.user_directory(is_active, can_receive_transfers);

-- فهارس حدود التحويل
CREATE INDEX IF NOT EXISTS idx_transfer_limits_user ON public.transfer_limits(user_id);
CREATE INDEX IF NOT EXISTS idx_transfer_limits_reset_date ON public.transfer_limits(last_reset_date);

-- =============================================================================
-- دوال مساعدة للنظام
-- =============================================================================

-- دالة تطبيع البريد الإلكتروني
CREATE OR REPLACE FUNCTION public.normalize_email(email_input TEXT)
RETURNS TEXT AS $
BEGIN
    RETURN LOWER(TRIM(REPLACE(email_input, ' ', '')));
END;
$ LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER SET search_path = public;

-- دالة إنشاء رقم مرجعي فريد
CREATE OR REPLACE FUNCTION public.generate_transfer_reference()
RETURNS TEXT AS $
DECLARE
    reference_number TEXT;
    exists_check BOOLEAN;
BEGIN
    LOOP
        reference_number := 'TRF' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        
        SELECT EXISTS(
            SELECT 1 FROM public.transfer_requests WHERE reference_number = reference_number
            UNION
            SELECT 1 FROM public.completed_transfers WHERE reference_number = reference_number
        ) INTO exists_check;
        
        IF NOT exists_check THEN
            RETURN reference_number;
        END IF;
    END LOOP;
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- دالة البحث عن المستخدم بطرق متعددة
CREATE OR REPLACE FUNCTION public.find_user_by_identifier(identifier TEXT)
RETURNS TABLE(
    user_id UUID,
    email TEXT,
    full_name TEXT,
    account_number TEXT,
    can_receive BOOLEAN,
    match_type TEXT
) AS $
DECLARE
    normalized_identifier TEXT;
BEGIN
    normalized_identifier := public.normalize_email(identifier);
    
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
      AND ud.is_active = true
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
          AND ud.is_active = true
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
          AND ud.is_active = true
        LIMIT 1;
    END IF;
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- دالة التحقق من حدود التحويل
CREATE OR REPLACE FUNCTION public.check_transfer_limits(
    p_user_id UUID,
    p_amount DECIMAL
)
RETURNS TABLE(
    can_transfer BOOLEAN,
    error_message TEXT,
    daily_remaining DECIMAL,
    monthly_remaining DECIMAL
) AS $
DECLARE
    v_limits RECORD;
    v_daily_remaining DECIMAL;
    v_monthly_remaining DECIMAL;
BEGIN
    -- جلب حدود المستخدم
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
    v_daily_remaining := v_limits.daily_limit - v_limits.daily_used;
    v_monthly_remaining := v_limits.monthly_limit - v_limits.monthly_used;
    
    -- التحقق من الحدود
    IF p_amount > v_limits.single_transfer_limit THEN
        RETURN QUERY SELECT FALSE, 'المبلغ يتجاوز الحد الأقصى للتحويل الواحد (' || v_limits.single_transfer_limit || ' دج)', v_daily_remaining, v_monthly_remaining;
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
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- الدالة الرئيسية لمعالجة التحويلات
-- =============================================================================

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
) AS $$
DECLARE
    v_sender_balance DECIMAL;
    v_recipient_info RECORD;
    v_limits_check RECORD;
    v_transfer_request_id UUID;
    v_reference_number TEXT;
    v_sender_new_balance DECIMAL;
    v_recipient_new_balance DECIMAL;
    v_recipient_balance DECIMAL;
BEGIN
    -- التحقق من صحة المدخلات
    IF p_amount <= 0 THEN
        RETURN QUERY SELECT FALSE, 'مبلغ التحويل يجب أن يكون أكبر من صفر', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    IF p_amount < 100 THEN
        RETURN QUERY SELECT FALSE, 'الحد الأدنى للتحويل هو 100 دج', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    -- التحقق من رصيد المرسل
    SELECT dzd INTO v_sender_balance
    FROM public.balances
    WHERE user_id = p_sender_id;
    
    IF v_sender_balance IS NULL THEN
        RETURN QUERY SELECT FALSE, 'لم يتم العثور على رصيد المرسل', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
        RETURN;
    END IF;
    
    IF v_sender_balance < p_amount THEN
        RETURN QUERY SELECT FALSE, 'الرصيد غير كافي لإجراء هذا التحويل', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
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
    SELECT * INTO v_recipient_info
    FROM public.find_user_by_identifier(p_recipient_identifier)
    LIMIT 1;
    
    IF v_recipient_info IS NULL THEN
        -- إنشاء رسالة خطأ مفصلة مع اقتراحات
        DECLARE
            v_suggestions TEXT;
        BEGIN
            SELECT string_agg(email || ' (' || full_name || ')', '\n') INTO v_suggestions
            FROM (
                SELECT email, full_name
                FROM public.user_directory
                WHERE is_active = true
                  AND can_receive_transfers = true
                  AND (
                    email_normalized LIKE '%' || public.normalize_email(p_recipient_identifier) || '%'
                    OR full_name ILIKE '%' || TRIM(p_recipient_identifier) || '%'
                  )
                ORDER BY 
                    CASE WHEN email_normalized LIKE public.normalize_email(p_recipient_identifier) || '%' THEN 1 ELSE 2 END,
                    email
                LIMIT 5
            ) suggestions;
            
            IF v_suggestions IS NOT NULL THEN
                RETURN QUERY SELECT FALSE, 
                    'لم يتم العثور على المستلم "' || p_recipient_identifier || '"\n\nاقتراحات مشابهة:\n' || v_suggestions,
                    NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
            ELSE
                RETURN QUERY SELECT FALSE, 
                    'لم يتم العثور على المستلم "' || p_recipient_identifier || '"\n\nتأكد من صحة البريد الإلكتروني أو رقم الحساب',
                    NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
            END IF;
            RETURN;
        END;
    END IF;
    
    -- التحقق من أن المستلم يمكنه استقبال التحويلات
    IF NOT v_recipient_info.can_receive THEN
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
    
    -- جلب رصيد المستلم
    SELECT dzd INTO v_recipient_balance
    FROM public.balances
    WHERE user_id = v_recipient_info.user_id;
    
    IF v_recipient_balance IS NULL THEN
        -- إنشاء رصيد للمستلم إذا لم يكن موجوداً
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
        VALUES (v_recipient_info.user_id, 0, 0, 0, 0);
        v_recipient_balance := 0;
    END IF;
    
    -- حساب الأرصدة الجديدة
    v_sender_new_balance := v_sender_balance - p_amount;
    v_recipient_new_balance := v_recipient_balance + p_amount;
    
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
            p_currency,
            'processing',
            v_reference_number,
            COALESCE(p_description, 'تحويل أموال إلى ' || v_recipient_info.full_name)
        )
        RETURNING id INTO v_transfer_request_id;
        
        -- تحديث أرصدة المرسل والمستلم
        UPDATE public.balances
        SET dzd = v_sender_new_balance,
            updated_at = NOW()
        WHERE user_id = p_sender_id;
        
        UPDATE public.balances
        SET dzd = v_recipient_new_balance,
            updated_at = NOW()
        WHERE user_id = v_recipient_info.user_id;
        
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
            p_currency,
            v_reference_number,
            v_sender_balance,
            v_sender_new_balance,
            v_recipient_balance,
            v_recipient_new_balance
        );
        
        -- تحديث حالة طلب التحويل
        UPDATE public.transfer_requests
        SET status = 'completed',
            processed_at = NOW(),
            updated_at = NOW()
        WHERE id = v_transfer_request_id;
        
        -- إنشاء سجلات المعاملات
        INSERT INTO public.transactions (user_id, type, amount, currency, description, recipient, reference, status)
        VALUES 
            (p_sender_id, 'transfer', p_amount, p_currency, 'تحويل صادر إلى ' || v_recipient_info.full_name, v_recipient_info.email, v_reference_number, 'completed'),
            (v_recipient_info.user_id, 'transfer', p_amount, p_currency, 'تحويل وارد من ' || (SELECT full_name FROM public.users WHERE id = p_sender_id), (SELECT email FROM public.users WHERE id = p_sender_id), v_reference_number, 'completed');
        
        -- إنشاء إشعارات
        INSERT INTO public.notifications (user_id, type, title, message)
        VALUES 
            (p_sender_id, 'success', 'تم إرسال التحويل', 'تم إرسال ' || p_amount || ' دج إلى ' || v_recipient_info.full_name || ' بنجاح'),
            (v_recipient_info.user_id, 'success', 'تم استلام تحويل', 'تم استلام ' || p_amount || ' دج من ' || (SELECT full_name FROM public.users WHERE id = p_sender_id));
        
        -- إرجاع النتيجة الناجحة
        RETURN QUERY SELECT TRUE, 'تم التحويل بنجاح', v_reference_number, v_sender_new_balance, v_recipient_new_balance, v_transfer_request_id;
        
    EXCEPTION WHEN OTHERS THEN
        -- في حالة حدوث خطأ، تحديث حالة طلب التحويل
        UPDATE public.transfer_requests
        SET status = 'failed',
            error_message = SQLERRM,
            updated_at = NOW()
        WHERE id = v_transfer_request_id;
        
        RETURN QUERY SELECT FALSE, 'خطأ في معالجة التحويل: ' || SQLERRM, NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL, NULL::UUID;
    END;
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- محفزات تحديث دليل المستخدمين
-- =============================================================================

-- دالة تحديث دليل المستخدمين
CREATE OR REPLACE FUNCTION public.sync_user_directory()
RETURNS TRIGGER AS $
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.user_directory (
            user_id,
            email,
            email_normalized,
            full_name,
            account_number,
            phone,
            is_active
        )
        VALUES (
            NEW.id,
            NEW.email,
            public.normalize_email(NEW.email),
            NEW.full_name,
            NEW.account_number,
            NEW.phone,
            COALESCE(NEW.is_active, true)
        );
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'UPDATE' THEN
        UPDATE public.user_directory
        SET email = NEW.email,
            email_normalized = public.normalize_email(NEW.email),
            full_name = NEW.full_name,
            account_number = NEW.account_number,
            phone = NEW.phone,
            is_active = COALESCE(NEW.is_active, true),
            updated_at = NOW()
        WHERE user_id = NEW.id;
        RETURN NEW;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        DELETE FROM public.user_directory WHERE user_id = OLD.id;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- إنشاء المحفز
DROP TRIGGER IF EXISTS trigger_sync_user_directory ON public.users;
CREATE TRIGGER trigger_sync_user_directory
    AFTER INSERT OR UPDATE OR DELETE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_user_directory();

-- =============================================================================
-- ملء دليل المستخدمين بالبيانات الموجودة
-- =============================================================================

INSERT INTO public.user_directory (
    user_id,
    email,
    email_normalized,
    full_name,
    account_number,
    phone,
    is_active
)
SELECT 
    id,
    email,
    public.normalize_email(email),
    full_name,
    account_number,
    phone,
    COALESCE(is_active, true)
FROM public.users
ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    email_normalized = EXCLUDED.email_normalized,
    full_name = EXCLUDED.full_name,
    account_number = EXCLUDED.account_number,
    phone = EXCLUDED.phone,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- =============================================================================
-- إنشاء حدود التحويل للمستخدمين الموجودين
-- =============================================================================

INSERT INTO public.transfer_limits (user_id)
SELECT id FROM public.users
ON CONFLICT (user_id) DO NOTHING;

-- =============================================================================
-- تفعيل RLS للجداول الجديدة
-- =============================================================================

ALTER TABLE public.transfer_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.completed_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_directory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfer_limits ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- سياسات RLS
-- =============================================================================

-- سياسات طلبات التحويل
DROP POLICY IF EXISTS "Users can view own transfer requests" ON public.transfer_requests;
CREATE POLICY "Users can view own transfer requests" ON public.transfer_requests
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Users can create transfer requests" ON public.transfer_requests;
CREATE POLICY "Users can create transfer requests" ON public.transfer_requests
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- سياسات التحويلات المكتملة
DROP POLICY IF EXISTS "Users can view own completed transfers" ON public.completed_transfers;
CREATE POLICY "Users can view own completed transfers" ON public.completed_transfers
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- سياسات دليل المستخدمين
DROP POLICY IF EXISTS "Users can search directory" ON public.user_directory;
CREATE POLICY "Users can search directory" ON public.user_directory
    FOR SELECT USING (true);

-- سياسات حدود التحويل
DROP POLICY IF EXISTS "Users can view own transfer limits" ON public.transfer_limits;
CREATE POLICY "Users can view own transfer limits" ON public.transfer_limits
    FOR SELECT USING (auth.uid() = user_id);

-- =============================================================================
-- تفعيل الوقت الفعلي
-- =============================================================================

-- Add tables to realtime publication only if they're not already added
DO $$
BEGIN
    -- Add transfer_requests if not already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'transfer_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.transfer_requests;
    END IF;
    
    -- Add completed_transfers if not already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'completed_transfers'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.completed_transfers;
    END IF;
    
    -- Add user_directory if not already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'user_directory'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_directory;
    END IF;
    
    -- Add transfer_limits if not already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'transfer_limits'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.transfer_limits;
    END IF;
END $$;

-- =============================================================================
-- انتهاء إنشاء نظام قاعدة البيانات للتحويلات
-- =============================================================================