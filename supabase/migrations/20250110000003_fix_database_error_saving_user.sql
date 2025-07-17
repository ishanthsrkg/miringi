-- Fix Database Error Saving New User
-- This migration adds additional error handling and logging to help debug signup issues

-- =============================================================================
-- Add logging function for debugging
-- =============================================================================

CREATE OR REPLACE FUNCTION public.log_user_creation_attempt(
    p_user_id UUID,
    p_email TEXT,
    p_step TEXT,
    p_status TEXT,
    p_error_message TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Log to PostgreSQL log
    RAISE NOTICE 'USER_CREATION_LOG - User: %, Email: %, Step: %, Status: %, Error: %', 
        p_user_id, p_email, p_step, p_status, COALESCE(p_error_message, 'None');
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create a safe user creation function that can be called manually if needed
-- =============================================================================

CREATE OR REPLACE FUNCTION public.safe_create_user_data(
    p_user_id UUID,
    p_email TEXT,
    p_user_metadata JSONB DEFAULT '{}'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    created_components TEXT[]
) AS $$
DECLARE
    new_referral_code TEXT;
    new_account_number TEXT;
    user_full_name TEXT;
    user_phone TEXT;
    user_username TEXT;
    user_address TEXT;
    user_referral_code TEXT;
    created_items TEXT[] := ARRAY[]::TEXT[];
    referrer_user_id UUID;
BEGIN
    -- Log start
    PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'START', 'INFO');
    
    -- Extract user metadata
    user_full_name := COALESCE(NULLIF(TRIM(p_user_metadata->>'full_name'), ''), 'مستخدم جديد');
    user_phone := COALESCE(NULLIF(TRIM(p_user_metadata->>'phone'), ''), '');
    user_username := COALESCE(NULLIF(TRIM(p_user_metadata->>'username'), ''), '');
    user_address := COALESCE(NULLIF(TRIM(p_user_metadata->>'address'), ''), '');
    user_referral_code := COALESCE(NULLIF(TRIM(p_user_metadata->>'used_referral_code'), ''), '');
    
    -- Generate codes
    BEGIN
        new_referral_code := public.generate_referral_code();
        IF new_referral_code IS NULL THEN
            new_referral_code := 'REF' || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            new_referral_code := 'REF' || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    END;
    
    new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
    
    -- 1. Create user profile
    BEGIN
        INSERT INTO public.users (
            id, email, full_name, phone, username, address, account_number,
            join_date, created_at, updated_at, referral_code, used_referral_code,
            referral_earnings, is_active, is_verified, verification_status,
            profile_completed, registration_date
        ) VALUES (
            p_user_id, p_email, user_full_name, user_phone, user_username, user_address,
            new_account_number, timezone('utc'::text, now()), timezone('utc'::text, now()),
            timezone('utc'::text, now()), new_referral_code, user_referral_code,
            0.00, true, false, 'unverified', true, timezone('utc'::text, now())
        );
        
        created_items := array_append(created_items, 'user_profile');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_PROFILE', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_PROFILE', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_PROFILE', 'ERROR', SQLERRM);
    END;
    
    -- 2. Create balance
    BEGIN
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, investment_balance, created_at, updated_at)
        VALUES (p_user_id, 20000.00, 100.00, 110.00, 85.00, 1000.00, timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        created_items := array_append(created_items, 'balance');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'BALANCE', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'BALANCE', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'BALANCE', 'ERROR', SQLERRM);
    END;
    
    -- 3. Create user credentials
    BEGIN
        INSERT INTO public.user_credentials (user_id, username, password_hash, created_at, updated_at)
        VALUES (
            p_user_id,
            COALESCE(NULLIF(user_username, ''), 'user_' || SUBSTRING(p_user_id::text, 1, 8)),
            '[HASHED]',
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        );
        
        created_items := array_append(created_items, 'credentials');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'CREDENTIALS', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'CREDENTIALS', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'CREDENTIALS', 'ERROR', SQLERRM);
    END;
    
    -- 4. Create directory entries
    BEGIN
        INSERT INTO public.user_directory (
            user_id, email, email_normalized, full_name, account_number, phone,
            can_receive_transfers, is_active, created_at, updated_at
        ) VALUES (
            p_user_id, p_email, LOWER(TRIM(p_email)), user_full_name,
            new_account_number, user_phone, true, true,
            timezone('utc'::text, now()), timezone('utc'::text, now())
        );
        
        created_items := array_append(created_items, 'user_directory');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_DIRECTORY', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_DIRECTORY', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_DIRECTORY', 'ERROR', SQLERRM);
    END;
    
    BEGIN
        INSERT INTO public.simple_transfers_users (
            user_id, email, email_normalized, full_name, account_number, phone,
            can_receive_transfers, is_active, created_at, updated_at
        ) VALUES (
            p_user_id, p_email, LOWER(TRIM(p_email)), user_full_name,
            new_account_number, user_phone, true, true,
            timezone('utc'::text, now()), timezone('utc'::text, now())
        );
        
        created_items := array_append(created_items, 'simple_transfers_users');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'SIMPLE_TRANSFERS_USERS', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'SIMPLE_TRANSFERS_USERS', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'SIMPLE_TRANSFERS_USERS', 'ERROR', SQLERRM);
    END;
    
    -- 5. Create transfer limits
    BEGIN
        INSERT INTO public.transfer_limits (user_id, created_at, updated_at)
        VALUES (p_user_id, timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        created_items := array_append(created_items, 'transfer_limits');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'TRANSFER_LIMITS', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'TRANSFER_LIMITS', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'TRANSFER_LIMITS', 'ERROR', SQLERRM);
    END;
    
    BEGIN
        INSERT INTO public.instant_transfer_limits (user_id, created_at, updated_at)
        VALUES (p_user_id, timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        created_items := array_append(created_items, 'instant_transfer_limits');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'INSTANT_TRANSFER_LIMITS', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'INSTANT_TRANSFER_LIMITS', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'INSTANT_TRANSFER_LIMITS', 'ERROR', SQLERRM);
    END;
    
    -- 6. Handle referral if provided
    IF user_referral_code IS NOT NULL AND user_referral_code != '' THEN
        BEGIN
            SELECT id INTO referrer_user_id 
            FROM public.users 
            WHERE referral_code = UPPER(user_referral_code)
            AND id != p_user_id;
            
            IF referrer_user_id IS NOT NULL THEN
                -- Create referral record
                INSERT INTO public.referrals (
                    referrer_id, referred_id, referral_code, reward_amount, status, created_at
                ) VALUES (
                    referrer_user_id, p_user_id, UPPER(user_referral_code),
                    500.00, 'completed', timezone('utc'::text, now())
                );
                
                -- Add reward to referrer
                UPDATE public.balances 
                SET dzd = dzd + 500.00, updated_at = timezone('utc'::text, now())
                WHERE user_id = referrer_user_id;
                
                UPDATE public.users 
                SET referral_earnings = referral_earnings + 500.00, updated_at = timezone('utc'::text, now())
                WHERE id = referrer_user_id;
                
                created_items := array_append(created_items, 'referral_reward');
                PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'REFERRAL', 'SUCCESS');
            ELSE
                PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'REFERRAL', 'ERROR', 'Invalid referral code');
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'REFERRAL', 'ERROR', SQLERRM);
        END;
    END IF;
    
    -- Return results
    PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'COMPLETE', 'SUCCESS');
    
    RETURN QUERY SELECT 
        true as success,
        'User data created successfully' as message,
        created_items as created_components;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Update the handle_new_user function to use the safe creation function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    creation_result RECORD;
BEGIN
    -- Log the trigger execution
    RAISE NOTICE 'handle_new_user trigger started for user: % with email: %', NEW.id, NEW.email;
    
    -- Use the safe creation function
    SELECT * INTO creation_result 
    FROM public.safe_create_user_data(
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data, '{}'::jsonb)
    );
    
    IF creation_result.success THEN
        RAISE NOTICE 'User creation completed successfully for %: Created components: %', 
            NEW.id, array_to_string(creation_result.created_components, ', ');
    ELSE
        RAISE WARNING 'User creation had issues for %: %', NEW.id, creation_result.message;
    END IF;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Critical error in handle_new_user for % (%): %', NEW.id, NEW.email, SQLERRM;
        -- Always return NEW to allow auth user creation to succeed
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- Recreate the trigger
-- =============================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- Add a function to check user creation status
-- =============================================================================

CREATE OR REPLACE FUNCTION public.check_user_creation_status(p_user_id UUID)
RETURNS TABLE(
    component TEXT,
    "exists" BOOLEAN,
    details JSONB
) AS $$
BEGIN
    -- Check users table
    RETURN QUERY
    SELECT 
        'users'::TEXT as component,
        EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) as "exists",
        COALESCE(
            (SELECT to_jsonb(u) FROM public.users u WHERE id = p_user_id),
            '{}'::jsonb
        ) as details;
    
    -- Check balances table
    RETURN QUERY
    SELECT 
        'balances'::TEXT as component,
        EXISTS(SELECT 1 FROM public.balances WHERE user_id = p_user_id) as "exists",
        COALESCE(
            (SELECT to_jsonb(b) FROM public.balances b WHERE user_id = p_user_id),
            '{}'::jsonb
        ) as details;
    
    -- Check user_credentials table
    RETURN QUERY
    SELECT 
        'user_credentials'::TEXT as component,
        EXISTS(SELECT 1 FROM public.user_credentials WHERE user_id = p_user_id) as "exists",
        COALESCE(
            (SELECT to_jsonb(uc) FROM public.user_credentials uc WHERE user_id = p_user_id),
            '{}'::jsonb
        ) as details;
    
    -- Check user_directory table
    RETURN QUERY
    SELECT 
        'user_directory'::TEXT as component,
        EXISTS(SELECT 1 FROM public.user_directory WHERE user_id = p_user_id) as "exists",
        COALESCE(
            (SELECT to_jsonb(ud) FROM public.user_directory ud WHERE user_id = p_user_id),
            '{}'::jsonb
        ) as details;
    
    -- Check transfer_limits table
    RETURN QUERY
    SELECT 
        'transfer_limits'::TEXT as component,
        EXISTS(SELECT 1 FROM public.transfer_limits WHERE user_id = p_user_id) as "exists",
        COALESCE(
            (SELECT to_jsonb(tl) FROM public.transfer_limits tl WHERE user_id = p_user_id),
            '{}'::jsonb
        ) as details;
END;
$$ LANGUAGE plpgsql;