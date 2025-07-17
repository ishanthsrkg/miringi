-- =============================================================================
-- FIX REFERRAL SYSTEM MIGRATION
-- =============================================================================
-- This migration specifically fixes the referral system issues
-- =============================================================================

-- =============================================================================
-- Ensure referral columns exist in users table
-- =============================================================================

DO $referral_columns_block$
BEGIN
    -- Add referral_code column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'referral_code') THEN
        ALTER TABLE public.users ADD COLUMN referral_code TEXT UNIQUE;
    END IF;
    
    -- Add used_referral_code column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'used_referral_code') THEN
        ALTER TABLE public.users ADD COLUMN used_referral_code TEXT;
    END IF;
    
    -- Add referral_earnings column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'referral_earnings') THEN
        ALTER TABLE public.users ADD COLUMN referral_earnings DECIMAL(15,2) DEFAULT 0.00 NOT NULL;
    END IF;
END $referral_columns_block$;

-- =============================================================================
-- Create referrals table if it doesn't exist
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    referred_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    referral_code TEXT NOT NULL,
    reward_amount DECIMAL(15,2) DEFAULT 500.00 NOT NULL CHECK (reward_amount >= 0),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT no_self_referral CHECK (referrer_id != referred_id),
    CONSTRAINT unique_referral UNIQUE (referrer_id, referred_id)
);

-- =============================================================================
-- Create indexes for referral system
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_used_referral_code ON public.users(used_referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON public.referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);

-- =============================================================================
-- Create improved referral code generation function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT AS $referral_code_func$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result TEXT := '';
    i INTEGER;
    code_exists BOOLEAN;
BEGIN
    LOOP
        result := '';
        -- Generate a 6-character code
        FOR i IN 1..6 LOOP
            result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
        END LOOP;
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM public.users WHERE referral_code = result) INTO code_exists;
        
        -- If code doesn't exist, return it
        IF NOT code_exists THEN
            RETURN result;
        END IF;
    END LOOP;
END;
$referral_code_func$ LANGUAGE plpgsql;

-- =============================================================================
-- Update existing users to have referral codes
-- =============================================================================

UPDATE public.users 
SET referral_code = public.generate_referral_code()
WHERE referral_code IS NULL OR referral_code = '';

-- =============================================================================
-- Create improved handle_new_user function with better referral logic
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $handle_new_user_func$
DECLARE
    new_referral_code TEXT;
    referrer_user_id UUID;
    used_ref_code TEXT;
BEGIN
    -- Generate unique referral code
    new_referral_code := public.generate_referral_code();
    
    -- Get the referral code from metadata
    used_ref_code := COALESCE(NEW.raw_user_meta_data->>'used_referral_code', '');
    
    -- Clean up the referral code (remove spaces, convert to uppercase)
    IF used_ref_code IS NOT NULL AND used_ref_code != '' THEN
        used_ref_code := UPPER(TRIM(used_ref_code));
    END IF;
    
    -- Insert user profile
    INSERT INTO public.users (
        id, 
        email, 
        full_name, 
        phone, 
        account_number, 
        join_date,
        referral_code,
        used_referral_code,
        address,
        username
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0'),
        timezone('utc'::text, now()),
        new_referral_code,
        used_ref_code,
        COALESCE(NEW.raw_user_meta_data->>'address', ''),
        COALESCE(NEW.raw_user_meta_data->>'username', '')
    );
    
    -- Create initial balance record with demo amounts
    INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, investment_balance)
    VALUES (NEW.id, 15000.00, 75.00, 85.00, 65.50, 0.00);
    
    -- Handle referral reward if user used a referral code
    IF used_ref_code IS NOT NULL AND used_ref_code != '' AND LENGTH(used_ref_code) >= 6 THEN
        -- Find the referrer
        SELECT id INTO referrer_user_id 
        FROM public.users 
        WHERE referral_code = used_ref_code
        AND id != NEW.id; -- Prevent self-referral
        
        -- If referrer found, create referral record and add reward
        IF referrer_user_id IS NOT NULL THEN
            -- Create referral record
            INSERT INTO public.referrals (
                referrer_id,
                referred_id,
                referral_code,
                reward_amount,
                status
            )
            VALUES (
                referrer_user_id,
                NEW.id,
                used_ref_code,
                500.00,
                'completed'
            )
            ON CONFLICT (referrer_id, referred_id) DO NOTHING;
            
            -- Add reward to referrer's balance
            UPDATE public.balances 
            SET dzd = dzd + 500.00,
                updated_at = timezone('utc'::text, now())
            WHERE user_id = referrer_user_id;
            
            -- Update referrer's earnings
            UPDATE public.users 
            SET referral_earnings = referral_earnings + 500.00,
                updated_at = timezone('utc'::text, now())
            WHERE id = referrer_user_id;
            
            -- Create notification for referrer
            INSERT INTO public.notifications (
                user_id,
                type,
                title,
                message
            )
            VALUES (
                referrer_user_id,
                'success',
                'مكافأة إحالة جديدة',
                'تم إضافة 500 دج إلى رصيدك بسبب إحالة مستخدم جديد'
            );
            
            -- Create notification for new user
            INSERT INTO public.notifications (
                user_id,
                type,
                title,
                message
            )
            VALUES (
                NEW.id,
                'success',
                'مرحباً بك!',
                'تم تفعيل حسابك بنجاح باستخدام كود الإحالة'
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$handle_new_user_func$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- Recreate the trigger
-- =============================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- Enable RLS on referrals table
-- =============================================================================

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- Create RLS policies for referrals table
-- =============================================================================

DROP POLICY IF EXISTS "Users can view own referrals" ON public.referrals;
CREATE POLICY "Users can view own referrals" ON public.referrals
    FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

DROP POLICY IF EXISTS "Users can insert referrals" ON public.referrals;
CREATE POLICY "Users can insert referrals" ON public.referrals
    FOR INSERT WITH CHECK (auth.uid() = referrer_id);

DROP POLICY IF EXISTS "Users can update own referrals" ON public.referrals;
CREATE POLICY "Users can update own referrals" ON public.referrals
    FOR UPDATE USING (auth.uid() = referrer_id);

-- =============================================================================
-- Enable realtime for referrals table
-- =============================================================================

DO $referral_realtime_block$
BEGIN
    -- Check if referrals table is already in realtime publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'referrals'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.referrals;
    END IF;
END $referral_realtime_block$;

-- =============================================================================
-- Create referral validation function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code TEXT)
RETURNS TABLE(
    is_valid BOOLEAN,
    referrer_name TEXT,
    referrer_id UUID,
    error_message TEXT
) AS $validate_referral_func$
BEGIN
    -- Check if code is provided
    IF p_code IS NULL OR TRIM(p_code) = '' THEN
        RETURN QUERY SELECT false, NULL::TEXT, NULL::UUID, 'كود الإحالة مطلوب'::TEXT;
        RETURN;
    END IF;
    
    -- Clean the code
    p_code := UPPER(TRIM(p_code));
    
    -- Check if code exists
    RETURN QUERY
    SELECT 
        true,
        u.full_name,
        u.id,
        NULL::TEXT
    FROM public.users u
    WHERE u.referral_code = p_code
    AND u.is_active = true
    LIMIT 1;
    
    -- If no results, return invalid
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::TEXT, NULL::UUID, 'كود الإحالة غير صحيح'::TEXT;
    END IF;
END;
$validate_referral_func$ LANGUAGE plpgsql;

-- =============================================================================
-- Create function to get referral statistics
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_referral_stats(p_user_id UUID)
RETURNS TABLE(
    total_referrals INTEGER,
    completed_referrals INTEGER,
    total_earnings DECIMAL,
    this_month_referrals INTEGER,
    pending_referrals INTEGER
) AS $referral_stats_func$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE((SELECT COUNT(*)::INTEGER FROM public.referrals WHERE referrer_id = p_user_id), 0),
        COALESCE((SELECT COUNT(*)::INTEGER FROM public.referrals WHERE referrer_id = p_user_id AND status = 'completed'), 0),
        COALESCE((SELECT referral_earnings FROM public.users WHERE id = p_user_id), 0::DECIMAL),
        COALESCE((SELECT COUNT(*)::INTEGER FROM public.referrals WHERE referrer_id = p_user_id AND created_at >= DATE_TRUNC('month', CURRENT_DATE)), 0),
        COALESCE((SELECT COUNT(*)::INTEGER FROM public.referrals WHERE referrer_id = p_user_id AND status = 'pending'), 0);
END;
$referral_stats_func$ LANGUAGE plpgsql;

-- =============================================================================
-- Final validation and cleanup
-- =============================================================================

DO $final_referral_validation$
DECLARE
    users_without_codes INTEGER;
    total_users INTEGER;
    total_referrals INTEGER;
BEGIN
    -- Count users without referral codes
    SELECT COUNT(*) INTO users_without_codes 
    FROM public.users 
    WHERE referral_code IS NULL OR referral_code = '';
    
    -- Count total users
    SELECT COUNT(*) INTO total_users FROM public.users;
    
    -- Count total referrals
    SELECT COUNT(*) INTO total_referrals FROM public.referrals;
    
    RAISE NOTICE 'Referral system fix completed:';
    RAISE NOTICE '- Total users: %', total_users;
    RAISE NOTICE '- Users without referral codes: %', users_without_codes;
    RAISE NOTICE '- Total referrals: %', total_referrals;
    
    IF users_without_codes > 0 THEN
        RAISE WARNING 'Some users still missing referral codes!';
    ELSE
        RAISE NOTICE 'All users have referral codes ✓';
    END IF;
END $final_referral_validation$;
