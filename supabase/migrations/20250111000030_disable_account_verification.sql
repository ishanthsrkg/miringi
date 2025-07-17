-- =============================================================================
-- DISABLE ACCOUNT VERIFICATION SYSTEM
-- =============================================================================
-- This migration disables the account verification system by:
-- 1. Setting all existing users as verified
-- 2. Modifying the default values for new users to be verified
-- 3. Updating the user creation trigger to set users as verified by default
-- =============================================================================

-- First, ensure all auth users exist in public.users table
INSERT INTO public.users (
    id, 
    email, 
    full_name, 
    phone, 
    account_number, 
    referral_code,
    used_referral_code,
    is_verified,
    verification_status,
    created_at,
    updated_at
)
SELECT 
    au.id,
    au.email,
    COALESCE(au.raw_user_meta_data->>'full_name', 'User') as full_name,
    COALESCE(au.raw_user_meta_data->>'phone', '') as phone,
    'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0') as account_number,
    public.generate_referral_code() as referral_code,
    COALESCE(au.raw_user_meta_data->>'used_referral_code', '') as used_referral_code,
    TRUE as is_verified,
    'approved' as verification_status,
    au.created_at,
    NOW() as updated_at
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL;

-- Create balances for users who don't have them
INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, created_at, updated_at)
SELECT 
    u.id,
    15000.00 as dzd,
    75.00 as eur,
    85.00 as usd,
    65.50 as gbp,
    NOW() as created_at,
    NOW() as updated_at
FROM public.users u
LEFT JOIN public.balances b ON u.id = b.user_id
WHERE b.user_id IS NULL;

-- Update all existing users to be verified
UPDATE users 
SET 
  is_verified = TRUE,
  verification_status = 'approved',
  updated_at = NOW()
WHERE is_verified = FALSE OR verification_status != 'approved';

-- Modify the users table to have verified defaults
ALTER TABLE users 
ALTER COLUMN is_verified SET DEFAULT TRUE,
ALTER COLUMN verification_status SET DEFAULT 'approved';

-- Update the handle_new_user function to set users as verified by default
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_referral_code TEXT;
    referrer_user_id UUID;
BEGIN
    -- Generate unique referral code
    new_referral_code := public.generate_referral_code();
    
    -- Insert user profile with verification enabled by default
    INSERT INTO public.users (
        id, 
        email, 
        full_name, 
        phone, 
        account_number, 
        referral_code,
        used_referral_code,
        is_verified,
        verification_status
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0'),
        new_referral_code,
        COALESCE(NEW.raw_user_meta_data->>'used_referral_code', ''),
        TRUE,  -- Set as verified by default
        'approved'  -- Set verification status as approved by default
    );
    
    -- Create initial balance record with demo amounts
    INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
    VALUES (NEW.id, 15000.00, 75.00, 85.00, 65.50);
    
    -- Handle referral reward if user used a referral code
    IF NEW.raw_user_meta_data->>'used_referral_code' IS NOT NULL AND NEW.raw_user_meta_data->>'used_referral_code' != '' THEN
        -- Find the referrer
        SELECT id INTO referrer_user_id 
        FROM public.users 
        WHERE referral_code = NEW.raw_user_meta_data->>'used_referral_code';
        
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
                NEW.raw_user_meta_data->>'used_referral_code',
                500.00,
                'completed'
            );
            
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
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to check if user is verified (always returns true now)
CREATE OR REPLACE FUNCTION public.is_user_verified(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Always return true since verification is disabled
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Update the checkAccountVerification function in the application layer
-- This will be handled by updating the supabase.ts file

-- Log the completion of verification disabling
INSERT INTO public.notifications (
    user_id,
    type,
    title,
    message
)
SELECT 
    id,
    'info',
    'تم تفعيل التوثيق التلقائي',
    'تم تفعيل حسابك تلقائياً. جميع المستخدمين الآن موثقون بشكل افتراضي.'
FROM users 
WHERE is_verified = TRUE
LIMIT 100;  -- Limit to avoid too many notifications

-- =============================================================================
-- VERIFICATION SYSTEM DISABLED SUCCESSFULLY
-- =============================================================================
-- All users are now verified by default
-- New users will be automatically verified upon registration
-- The account verification process is effectively bypassed
-- =============================================================================