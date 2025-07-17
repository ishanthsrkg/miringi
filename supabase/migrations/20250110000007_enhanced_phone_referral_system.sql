-- =============================================================================
-- Enhanced Phone and Referral System
-- This migration adds phone verification and improves the referral system
-- =============================================================================

-- Add phone verification columns if missing
DO $phone_verification_block$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'users' 
          AND column_name = 'phone_verified'
    ) THEN
        ALTER TABLE public.users 
        ADD COLUMN phone_verified BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'users' 
          AND column_name = 'phone_verified_at'
    ) THEN
        ALTER TABLE public.users 
        ADD COLUMN phone_verified_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
    END IF;
END $phone_verification_block$;

-- Fix referral earnings column if missing
DO $referral_earnings_block$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'users' 
          AND column_name = 'referral_earnings'
    ) THEN
        ALTER TABLE public.users 
        ADD COLUMN referral_earnings NUMERIC(15,2) DEFAULT 0.00;
    END IF;
END $referral_earnings_block$;

-- Fix used_referral_code column if missing
DO $used_referral_code_block$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'users' 
          AND column_name = 'used_referral_code'
    ) THEN
        ALTER TABLE public.users 
        ADD COLUMN used_referral_code TEXT DEFAULT '';
    END IF;
END $used_referral_code_block$;

-- Drop existing function first to avoid conflicts
DROP FUNCTION IF EXISTS public.process_referral_reward(UUID, TEXT);

-- Create enhanced referral processing function with better validation
CREATE OR REPLACE FUNCTION public.process_referral_reward(
    p_new_user_id UUID,
    p_referral_code TEXT
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    reward_amount NUMERIC,
    referrer_name TEXT
) AS $$
DECLARE
    v_referrer_id UUID;
    v_referrer_name TEXT;
    v_reward_amount NUMERIC := 500.00;
    v_bonus_amount NUMERIC := 500.00; -- مكافأة للمستخدم الجديد أيضاً
BEGIN
    -- Validate referral code format
    IF p_referral_code IS NULL OR LENGTH(TRIM(p_referral_code)) < 6 THEN
        RETURN QUERY SELECT 
            false, 
            'كود الإحالة يجب أن يكون 6 أحرف على الأقل'::TEXT, 
            0::NUMERIC,
            ''::TEXT;
        RETURN;
    END IF;
    
    -- Find referrer by code
    SELECT id, full_name INTO v_referrer_id, v_referrer_name
    FROM public.users 
    WHERE referral_code = UPPER(TRIM(p_referral_code))
      AND id != p_new_user_id
      AND is_active = true;
    
    IF v_referrer_id IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            'كود الإحالة غير صحيح أو غير موجود'::TEXT, 
            0::NUMERIC,
            ''::TEXT;
        RETURN;
    END IF;
    
    -- Check if referral already processed
    IF EXISTS (
        SELECT 1 
        FROM public.referrals 
        WHERE referred_id = p_new_user_id
    ) THEN
        RETURN QUERY SELECT 
            false, 
            'تم معالجة الإحالة مسبقاً'::TEXT, 
            0::NUMERIC,
            v_referrer_name;
        RETURN;
    END IF;
    
    -- Create referral record
    INSERT INTO public.referrals (
        referrer_id,
        referred_id,
        referral_code,
        reward_amount,
        status,
        created_at
    ) VALUES (
        v_referrer_id,
        p_new_user_id,
        UPPER(TRIM(p_referral_code)),
        v_reward_amount,
        'completed',
        timezone('utc'::text, now())
    );
    
    -- Add reward to referrer's balance (500 DZD)
    UPDATE public.balances 
    SET dzd = dzd + v_reward_amount,
        updated_at = timezone('utc'::text, now())
    WHERE user_id = v_referrer_id;
    
    -- Add bonus to new user's balance (500 DZD welcome bonus)
    UPDATE public.balances 
    SET dzd = dzd + v_bonus_amount,
        updated_at = timezone('utc'::text, now())
    WHERE user_id = p_new_user_id;
    
    -- Update referrer's earnings
    UPDATE public.users 
    SET referral_earnings = COALESCE(referral_earnings, 0) + v_reward_amount,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_referrer_id;
    
    -- Update new user's used referral code
    UPDATE public.users 
    SET used_referral_code = UPPER(TRIM(p_referral_code)),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_new_user_id;
    
    -- Create notification for referrer
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        is_read,
        created_at
    ) VALUES (
        v_referrer_id,
        'مكافأة إحالة جديدة!',
        'تم منحك 500 دج لإحالة مستخدم جديد',
        'referral_reward',
        false,
        timezone('utc'::text, now())
    );
    
    -- Create notification for new user
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        is_read,
        created_at
    ) VALUES (
        p_new_user_id,
        'مرحباً بك! مكافأة ترحيب',
        'تم منحك 500 دج كمكافأة ترحيب لاستخدام كود الإحالة',
        'welcome_bonus',
        false,
        timezone('utc'::text, now())
    );
    
    RETURN QUERY SELECT 
        true, 
        'تم منح مكافأة الإحالة بنجاح - 500 دج للمُحيل و 500 دج للمستخدم الجديد'::TEXT, 
        v_reward_amount,
        v_referrer_name;
END;
$$ LANGUAGE plpgsql;

-- Create phone verification function
CREATE OR REPLACE FUNCTION public.verify_user_phone(
    p_user_id UUID,
    p_phone_number TEXT
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT
) AS $$
BEGIN
    -- Update user phone verification status
    UPDATE public.users 
    SET phone_verified = true,
        phone_verified_at = timezone('utc'::text, now()),
        phone = p_phone_number,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_user_id;
    
    -- Check if update was successful
    IF FOUND THEN
        RETURN QUERY SELECT 
            true, 
            'تم تأكيد رقم الهاتف بنجاح'::TEXT;
    ELSE
        RETURN QUERY SELECT 
            false, 
            'فشل في تأكيد رقم الهاتف'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.process_referral_reward(UUID, TEXT) 
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_user_phone(UUID, TEXT) 
    TO authenticated;

COMMIT;
