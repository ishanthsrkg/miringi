-- =============================================================================
-- OTP SYSTEM MIGRATION
-- =============================================================================
-- This migration creates the complete OTP system for phone verification
-- =============================================================================

-- OTPs table - stores one-time passwords for phone and email verification
CREATE TABLE IF NOT EXISTS public.otps (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID,
    phone_number TEXT,
    email TEXT,
    otp_code TEXT NOT NULL,
    otp_type TEXT NOT NULL CHECK (otp_type IN ('phone_verification', 'email_verification', 'login', 'password_reset', 'transaction')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    attempts INTEGER DEFAULT 0 NOT NULL CHECK (attempts >= 0 AND attempts <= 5),
    is_verified BOOLEAN DEFAULT false NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT check_phone_or_email CHECK (phone_number IS NOT NULL OR email IS NOT NULL)
);

-- OTP logs table - tracks all OTP activities
CREATE TABLE IF NOT EXISTS public.otp_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    otp_id UUID,
    user_id UUID,
    phone_number TEXT,
    email TEXT,
    action TEXT NOT NULL CHECK (action IN ('sent', 'verified', 'expired', 'failed', 'resent', 'blocked')),
    otp_type TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    error_message TEXT,
    metadata JSON,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT check_log_phone_or_email CHECK (phone_number IS NOT NULL OR email IS NOT NULL)
);

-- Add foreign key constraints after table creation (with existence checks)
DO $$
BEGIN
    -- Add foreign key constraint for otps.user_id only if users table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                      WHERE constraint_name = 'fk_otps_user_id' AND table_name = 'otps') THEN
            ALTER TABLE public.otps ADD CONSTRAINT fk_otps_user_id 
                FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
        END IF;
    END IF;
    
    -- Add foreign key constraint for otp_logs.otp_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                  WHERE constraint_name = 'fk_otp_logs_otp_id' AND table_name = 'otp_logs') THEN
        ALTER TABLE public.otp_logs ADD CONSTRAINT fk_otp_logs_otp_id 
            FOREIGN KEY (otp_id) REFERENCES public.otps(id) ON DELETE SET NULL;
    END IF;
    
    -- Add foreign key constraint for otp_logs.user_id only if users table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                      WHERE constraint_name = 'fk_otp_logs_user_id' AND table_name = 'otp_logs') THEN
            ALTER TABLE public.otp_logs ADD CONSTRAINT fk_otp_logs_user_id 
                FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

-- =============================================================================
-- OTP INDEXES FOR PERFORMANCE
-- =============================================================================

-- OTP table indexes
CREATE INDEX IF NOT EXISTS idx_otps_user_id ON public.otps(user_id);
CREATE INDEX IF NOT EXISTS idx_otps_phone_number ON public.otps(phone_number);
CREATE INDEX IF NOT EXISTS idx_otps_email ON public.otps(email);
CREATE INDEX IF NOT EXISTS idx_otps_otp_code ON public.otps(otp_code);
CREATE INDEX IF NOT EXISTS idx_otps_expires_at ON public.otps(expires_at);
CREATE INDEX IF NOT EXISTS idx_otps_type_status ON public.otps(otp_type, used_at);
CREATE INDEX IF NOT EXISTS idx_otps_active_phone ON public.otps(phone_number, otp_type) WHERE used_at IS NULL AND expires_at > NOW();
CREATE INDEX IF NOT EXISTS idx_otps_active_email ON public.otps(email, otp_type) WHERE used_at IS NULL AND expires_at > NOW();
CREATE INDEX IF NOT EXISTS idx_otps_verification_status ON public.otps(is_verified, created_at DESC);

-- OTP logs indexes
CREATE INDEX IF NOT EXISTS idx_otp_logs_otp_id ON public.otp_logs(otp_id);
CREATE INDEX IF NOT EXISTS idx_otp_logs_user_id ON public.otp_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_otp_logs_phone_number ON public.otp_logs(phone_number);
CREATE INDEX IF NOT EXISTS idx_otp_logs_email ON public.otp_logs(email);
CREATE INDEX IF NOT EXISTS idx_otp_logs_action ON public.otp_logs(action);
CREATE INDEX IF NOT EXISTS idx_otp_logs_created_at ON public.otp_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_otp_logs_user_action ON public.otp_logs(user_id, action, created_at DESC);

-- =============================================================================
-- OTP FUNCTIONS
-- =============================================================================

-- Function to generate secure 6-digit OTP
CREATE OR REPLACE FUNCTION public.generate_otp_code()
RETURNS TEXT AS $$
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a 6-digit code
        code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        
        -- Check if code already exists and is not expired
        SELECT EXISTS(
            SELECT 1 FROM public.otps 
            WHERE otp_code = code 
            AND expires_at > NOW() 
            AND used_at IS NULL
        ) INTO exists;
        
        -- If code doesn't exist or is expired, return it
        IF NOT exists THEN
            RETURN code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create OTP (supports both phone and email)
CREATE OR REPLACE FUNCTION public.create_otp(
    p_user_id UUID DEFAULT NULL,
    p_phone_number TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_otp_type TEXT DEFAULT 'phone_verification',
    p_expires_in_minutes INTEGER DEFAULT 5,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    otp_id UUID,
    otp_code TEXT,
    expires_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    new_otp_code TEXT;
    new_otp_id UUID;
    otp_expires_at TIMESTAMP WITH TIME ZONE;
    rate_limit_check INTEGER;
    contact_field TEXT;
BEGIN
    -- Validate that either phone number or email is provided
    IF (p_phone_number IS NULL OR LENGTH(TRIM(p_phone_number)) = 0) AND 
       (p_email IS NULL OR LENGTH(TRIM(p_email)) = 0) THEN
        RETURN QUERY SELECT false, 'يجب توفير رقم الهاتف أو البريد الإلكتروني'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Set contact field for rate limiting
    contact_field := COALESCE(p_phone_number, p_email);
    
    -- Validate OTP type
    IF p_otp_type NOT IN ('phone_verification', 'email_verification', 'login', 'password_reset', 'transaction') THEN
        RETURN QUERY SELECT false, 'نوع OTP غير صحيح'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Rate limiting: Check if too many OTPs sent in last 5 minutes
    SELECT COUNT(*) INTO rate_limit_check
    FROM public.otp_logs 
    WHERE (phone_number = p_phone_number OR email = p_email)
      AND action = 'sent'
      AND created_at > NOW() - INTERVAL '5 minutes';
      
    IF rate_limit_check >= 3 THEN
        RETURN QUERY SELECT false, 'تم تجاوز الحد المسموح لإرسال OTP. يرجى الانتظار 5 دقائق'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Clean up expired OTPs for this contact
    DELETE FROM public.otps 
    WHERE (phone_number = p_phone_number OR email = p_email)
      AND otp_type = p_otp_type 
      AND expires_at <= NOW();
    
    -- Check if there's already an active OTP
    IF EXISTS(
        SELECT 1 FROM public.otps 
        WHERE (phone_number = p_phone_number OR email = p_email)
          AND otp_type = p_otp_type 
          AND used_at IS NULL 
          AND expires_at > NOW()
    ) THEN
        RETURN QUERY SELECT false, 'يوجد OTP نشط بالفعل لهذا الحساب'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Generate new OTP code
    new_otp_code := public.generate_otp_code();
    otp_expires_at := NOW() + (p_expires_in_minutes || ' minutes')::INTERVAL;
    
    -- Insert new OTP
    INSERT INTO public.otps (
        user_id, phone_number, email, otp_code, otp_type, expires_at, ip_address, user_agent
    ) VALUES (
        p_user_id, p_phone_number, p_email, new_otp_code, p_otp_type, otp_expires_at, p_ip_address, p_user_agent
    ) RETURNING id INTO new_otp_id;
    
    -- Log the OTP creation
    INSERT INTO public.otp_logs (
        otp_id, user_id, phone_number, email, action, otp_type, ip_address, user_agent
    ) VALUES (
        new_otp_id, p_user_id, p_phone_number, p_email, 'sent', p_otp_type, p_ip_address, p_user_agent
    );
    
    RETURN QUERY SELECT true, 'تم إنشاء OTP بنجاح'::TEXT, new_otp_id, new_otp_code, otp_expires_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify OTP (supports both phone and email)
CREATE OR REPLACE FUNCTION public.verify_otp(
    p_phone_number TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_otp_code TEXT,
    p_otp_type TEXT DEFAULT 'phone_verification',
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    user_id UUID,
    phone_number TEXT,
    email TEXT,
    otp_type TEXT
) AS $$
DECLARE
    otp_record RECORD;
    log_action TEXT;
BEGIN
    -- Validate that either phone number or email is provided
    IF (p_phone_number IS NULL OR LENGTH(TRIM(p_phone_number)) = 0) AND 
       (p_email IS NULL OR LENGTH(TRIM(p_email)) = 0) THEN
        RETURN QUERY SELECT false, 'يجب توفير رقم الهاتف أو البريد الإلكتروني'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Find the OTP
    SELECT o.*
    INTO otp_record
    FROM public.otps o
    WHERE (o.phone_number = p_phone_number OR o.email = p_email)
      AND o.otp_code = p_otp_code 
      AND o.otp_type = p_otp_type;
    
    -- Check if OTP exists
    IF otp_record IS NULL THEN
        INSERT INTO public.otp_logs (
            user_id, phone_number, email, action, otp_type, ip_address, user_agent, error_message
        ) VALUES (
            NULL, p_phone_number, p_email, 'failed', p_otp_type, p_ip_address, p_user_agent, 'OTP غير موجود'
        );
        RETURN QUERY SELECT false, 'رمز OTP غير صحيح أو غير موجود'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check if OTP is already used
    IF otp_record.used_at IS NOT NULL THEN
        log_action := 'failed';
        INSERT INTO public.otp_logs (
            otp_id, user_id, phone_number, email, action, otp_type, ip_address, user_agent, error_message
        ) VALUES (
            otp_record.id, otp_record.user_id, p_phone_number, p_email, log_action, p_otp_type, 
            p_ip_address, p_user_agent, 'OTP مستخدم مسبقاً'
        );
        RETURN QUERY SELECT false, 'رمز OTP مستخدم مسبقاً'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check if OTP is expired
    IF otp_record.expires_at <= NOW() THEN
        log_action := 'expired';
        INSERT INTO public.otp_logs (
            otp_id, user_id, phone_number, email, action, otp_type, ip_address, user_agent, error_message
        ) VALUES (
            otp_record.id, otp_record.user_id, p_phone_number, p_email, log_action, p_otp_type, 
            p_ip_address, p_user_agent, 'انتهت صلاحية OTP'
        );
        RETURN QUERY SELECT false, 'انتهت صلاحية رمز OTP'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check attempts limit
    IF otp_record.attempts >= 5 THEN
        log_action := 'blocked';
        INSERT INTO public.otp_logs (
            otp_id, user_id, phone_number, email, action, otp_type, ip_address, user_agent, error_message
        ) VALUES (
            otp_record.id, otp_record.user_id, p_phone_number, p_email, log_action, p_otp_type, 
            p_ip_address, p_user_agent, 'تم تجاوز عدد المحاولات المسموح'
        );
        RETURN QUERY SELECT false, 'تم تجاوز عدد المحاولات المسموح'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Mark OTP as used and verified
    UPDATE public.otps 
    SET used_at = NOW(), 
        is_verified = true,
        updated_at = NOW()
    WHERE id = otp_record.id;
    
    -- Update user verification status based on OTP type (only if users table exists)
    IF otp_record.user_id IS NOT NULL AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
        IF p_otp_type = 'phone_verification' AND p_phone_number IS NOT NULL THEN
            UPDATE public.users 
            SET phone = p_phone_number,
                is_verified = true,
                verification_status = 'verified',
                updated_at = NOW()
            WHERE id = otp_record.user_id;
        ELSIF p_otp_type = 'email_verification' AND p_email IS NOT NULL THEN
            UPDATE public.users 
            SET email = p_email,
                is_verified = true,
                verification_status = 'verified',
                updated_at = NOW()
            WHERE id = otp_record.user_id;
        END IF;
    END IF;
    
    -- Log successful verification
    INSERT INTO public.otp_logs (
        otp_id, user_id, phone_number, email, action, otp_type, ip_address, user_agent
    ) VALUES (
        otp_record.id, otp_record.user_id, p_phone_number, p_email, 'verified', p_otp_type, 
        p_ip_address, p_user_agent
    );
    
    RETURN QUERY SELECT true, 'تم تأكيد OTP بنجاح'::TEXT, 
                        otp_record.user_id, p_phone_number, p_email, p_otp_type;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment OTP attempts
CREATE OR REPLACE FUNCTION public.increment_otp_attempts(
    p_phone_number TEXT,
    p_otp_code TEXT,
    p_otp_type TEXT DEFAULT 'phone_verification',
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    attempts_remaining INTEGER
) AS $$
DECLARE
    otp_record RECORD;
    new_attempts INTEGER;
BEGIN
    -- Find and update the OTP
    UPDATE public.otps 
    SET attempts = attempts + 1,
        updated_at = NOW()
    WHERE phone_number = p_phone_number 
      AND otp_code = p_otp_code
      AND otp_type = p_otp_type
      AND used_at IS NULL 
      AND expires_at > NOW()
    RETURNING * INTO otp_record;
    
    IF otp_record IS NULL THEN
        RETURN QUERY SELECT false, 'رمز OTP غير صحيح أو منتهي الصلاحية'::TEXT, 0;
        RETURN;
    END IF;
    
    new_attempts := otp_record.attempts;
    
    -- Log the failed attempt
    INSERT INTO public.otp_logs (
        otp_id, user_id, phone_number, action, otp_type, ip_address, user_agent, error_message
    ) VALUES (
        otp_record.id, otp_record.user_id, p_phone_number, 'failed', p_otp_type, 
        p_ip_address, p_user_agent, 'محاولة تأكيد فاشلة'
    );
    
    RETURN QUERY SELECT true, 'تم تسجيل المحاولة'::TEXT, (5 - new_attempts);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up expired OTPs
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS TABLE(
    cleaned_otps INTEGER,
    cleaned_logs INTEGER
) AS $$
DECLARE
    otps_count INTEGER;
    logs_count INTEGER;
BEGIN
    -- Delete expired OTPs
    DELETE FROM public.otps 
    WHERE expires_at <= NOW() - INTERVAL '1 day';
    GET DIAGNOSTICS otps_count = ROW_COUNT;
    
    -- Delete old logs (keep last 30 days)
    DELETE FROM public.otp_logs 
    WHERE created_at <= NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS logs_count = ROW_COUNT;
    
    RETURN QUERY SELECT otps_count, logs_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get OTP status (supports both phone and email)
CREATE OR REPLACE FUNCTION public.get_otp_status(
    p_phone_number TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL,
    p_otp_type TEXT DEFAULT 'phone_verification'
)
RETURNS TABLE(
    has_active_otp BOOLEAN,
    expires_at TIMESTAMP WITH TIME ZONE,
    attempts_used INTEGER,
    can_resend BOOLEAN,
    next_resend_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    active_otp RECORD;
    last_sent TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Validate that either phone number or email is provided
    IF (p_phone_number IS NULL OR LENGTH(TRIM(p_phone_number)) = 0) AND 
       (p_email IS NULL OR LENGTH(TRIM(p_email)) = 0) THEN
        RETURN QUERY SELECT false, NULL::TIMESTAMP WITH TIME ZONE, 0, false, NOW();
        RETURN;
    END IF;
    
    -- Get active OTP
    SELECT * INTO active_otp
    FROM public.otps 
    WHERE (phone_number = p_phone_number OR email = p_email)
      AND otp_type = p_otp_type 
      AND used_at IS NULL 
      AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Get last sent time
    SELECT MAX(created_at) INTO last_sent
    FROM public.otp_logs 
    WHERE (phone_number = p_phone_number OR email = p_email)
      AND action = 'sent'
      AND created_at > NOW() - INTERVAL '5 minutes';
    
    IF active_otp IS NOT NULL THEN
        RETURN QUERY SELECT 
            true,
            active_otp.expires_at,
            active_otp.attempts,
            (last_sent IS NULL OR last_sent < NOW() - INTERVAL '1 minute'),
            CASE 
                WHEN last_sent IS NOT NULL THEN last_sent + INTERVAL '1 minute'
                ELSE NOW()
            END;
    ELSE
        RETURN QUERY SELECT 
            false,
            NULL::TIMESTAMP WITH TIME ZONE,
            0,
            (last_sent IS NULL OR last_sent < NOW() - INTERVAL '1 minute'),
            CASE 
                WHEN last_sent IS NOT NULL THEN last_sent + INTERVAL '1 minute'
                ELSE NOW()
            END;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- OTP TRIGGERS
-- =============================================================================

-- Trigger to update OTP timestamps (only if the function exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'update_updated_at_column') THEN
        CREATE TRIGGER update_otps_updated_at 
            BEFORE UPDATE ON public.otps
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;
END $$;

-- =============================================================================
-- OTP RLS POLICIES
-- =============================================================================

-- Enable RLS on OTP tables
ALTER TABLE public.otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_logs ENABLE ROW LEVEL SECURITY;

-- OTP table policies
DROP POLICY IF EXISTS "Users can view own OTPs" ON public.otps;
CREATE POLICY "Users can view own OTPs" ON public.otps
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can insert own OTPs" ON public.otps;
CREATE POLICY "Users can insert own OTPs" ON public.otps
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can update own OTPs" ON public.otps;
CREATE POLICY "Users can update own OTPs" ON public.otps
    FOR UPDATE USING (auth.uid() = user_id OR user_id IS NULL);

-- OTP logs policies
DROP POLICY IF EXISTS "Users can view own OTP logs" ON public.otp_logs;
CREATE POLICY "Users can view own OTP logs" ON public.otp_logs
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can insert own OTP logs" ON public.otp_logs;
CREATE POLICY "Users can insert own OTP logs" ON public.otp_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- =============================================================================
-- ENABLE REALTIME FOR OTP TABLES
-- =============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.otps;
ALTER PUBLICATION supabase_realtime ADD TABLE public.otp_logs;