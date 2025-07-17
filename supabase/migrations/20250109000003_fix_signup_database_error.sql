-- Fix Database Error During User Signup
-- This migration fixes the "Database error saving new user" issue
-- by improving the handle_new_user trigger function

-- =============================================================================
-- Fix the handle_new_user function to prevent database errors
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_referral_code TEXT;
    new_account_number TEXT;
    referrer_user_id UUID;
    referral_code_to_use TEXT;
BEGIN
    -- Generate unique referral code
    new_referral_code := public.generate_referral_code();
    
    -- Generate unique account number
    new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
    
    -- Ensure account number is unique
    WHILE EXISTS (SELECT 1 FROM public.users WHERE account_number = new_account_number) LOOP
        new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
    END LOOP;
    
    -- Get referral code from metadata if provided
    referral_code_to_use := COALESCE(NEW.raw_user_meta_data->>'used_referral_code', '');
    
    -- Insert user profile with error handling
    BEGIN
        INSERT INTO public.users (
            id, 
            email, 
            full_name, 
            phone, 
            account_number, 
            join_date,
            referral_code,
            used_referral_code,
            language,
            currency,
            is_active,
            referral_earnings
        )
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
            COALESCE(NEW.raw_user_meta_data->>'phone', ''),
            new_account_number,
            timezone('utc'::text, now()),
            new_referral_code,
            referral_code_to_use,
            'ar',
            'dzd',
            true,
            0.00
        );
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error and continue without failing the signup
            RAISE WARNING 'Error inserting user profile: %', SQLERRM;
            -- Insert minimal user record
            INSERT INTO public.users (id, email, full_name, account_number, join_date, referral_code)
            VALUES (
                NEW.id,
                NEW.email,
                COALESCE(NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
                new_account_number,
                timezone('utc'::text, now()),
                new_referral_code
            );
    END;
    
    -- Create initial balance record with error handling
    BEGIN
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
        VALUES (NEW.id, 15000.00, 75.00, 85.00, 65.50);
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error and create minimal balance
            RAISE WARNING 'Error creating initial balance: %', SQLERRM;
            INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
            VALUES (NEW.id, 0.00, 0.00, 0.00, 0.00);
    END;
    
    -- Handle referral reward if user used a referral code
    IF referral_code_to_use IS NOT NULL AND referral_code_to_use != '' THEN
        BEGIN
            -- Find the referrer (only look for existing users)
            SELECT id INTO referrer_user_id 
            FROM public.users 
            WHERE referral_code = referral_code_to_use
            AND id != NEW.id; -- Ensure we don't reference the user being created
            
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
                    referral_code_to_use,
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
        EXCEPTION
            WHEN OTHERS THEN
                -- Log referral error but don't fail the signup
                RAISE WARNING 'Error processing referral: %', SQLERRM;
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- Ensure the trigger is properly set up
-- =============================================================================

-- Drop and recreate the trigger to ensure it's using the updated function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- Add additional safety constraints
-- =============================================================================

-- Ensure referral_code is unique and not null for existing users
UPDATE public.users 
SET referral_code = public.generate_referral_code()
WHERE referral_code IS NULL OR referral_code = '';

-- Add constraint to ensure referral_code is always set
ALTER TABLE public.users 
ALTER COLUMN referral_code SET NOT NULL;

-- =============================================================================
-- Create a function to safely handle user creation errors
-- =============================================================================

CREATE OR REPLACE FUNCTION public.safe_create_user_profile(
    user_id UUID,
    user_email TEXT,
    user_metadata JSONB DEFAULT '{}'
)
RETURNS BOOLEAN AS $$
DECLARE
    success BOOLEAN := false;
BEGIN
    -- Try to create user profile if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = user_id) THEN
        INSERT INTO public.users (
            id,
            email,
            full_name,
            phone,
            account_number,
            join_date,
            referral_code,
            language,
            currency,
            is_active
        )
        VALUES (
            user_id,
            user_email,
            COALESCE(user_metadata->>'full_name', 'مستخدم جديد'),
            COALESCE(user_metadata->>'phone', ''),
            'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0'),
            timezone('utc'::text, now()),
            public.generate_referral_code(),
            'ar',
            'dzd',
            true
        );
        success := true;
    END IF;
    
    -- Try to create balance if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM public.balances WHERE user_id = user_id) THEN
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
        VALUES (user_id, 15000.00, 75.00, 85.00, 65.50);
    END IF;
    
    RETURN success;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in safe_create_user_profile: %', SQLERRM;
        RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
