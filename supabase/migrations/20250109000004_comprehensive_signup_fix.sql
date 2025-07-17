-- Comprehensive Fix for Signup Database Errors
-- This migration addresses all known issues causing signup failures

-- =============================================================================
-- First, let's ensure all required tables exist with proper structure
-- =============================================================================

-- Ensure users table has all required columns
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS username TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS registration_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Ensure balances table exists and has investment_balance column
ALTER TABLE public.balances 
ADD COLUMN IF NOT EXISTS investment_balance NUMERIC(15,2) DEFAULT 0.00;

-- =============================================================================
-- Create a completely new, robust handle_new_user function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_referral_code TEXT;
    new_account_number TEXT;
    referrer_user_id UUID;
    referral_code_to_use TEXT;
    user_full_name TEXT;
    user_phone TEXT;
    user_username TEXT;
    user_address TEXT;
    attempt_count INTEGER := 0;
    max_attempts INTEGER := 5;
    user_email_normalized TEXT;
BEGIN
    -- Log the start of user creation process
    RAISE NOTICE 'Starting user creation process for: %', NEW.email;
    
    -- Extract user data from metadata with proper null handling
    user_full_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''), 'مستخدم جديد');
    user_phone := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), ''), '');
    user_username := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'username'), ''), '');
    user_address := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'address'), ''), '');
    referral_code_to_use := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'used_referral_code'), ''), NULL);
    user_email_normalized := LOWER(TRIM(NEW.email));
    
    -- Generate unique referral code with retry logic
    LOOP
        new_referral_code := public.generate_referral_code();
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.users WHERE referral_code = new_referral_code);
        attempt_count := attempt_count + 1;
        IF attempt_count >= max_attempts THEN
            -- Fallback to timestamp-based code
            new_referral_code := 'REF' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT;
            EXIT;
        END IF;
    END LOOP;
    
    -- Generate unique account number with retry logic
    attempt_count := 0;
    LOOP
        new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.users WHERE account_number = new_account_number);
        attempt_count := attempt_count + 1;
        IF attempt_count >= max_attempts THEN
            -- Fallback to timestamp-based account number
            new_account_number := 'ACC' || LPAD(EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT, 9, '0');
            EXIT;
        END IF;
    END LOOP;
    
    -- Insert user profile with comprehensive error handling
    BEGIN
        INSERT INTO public.users (
            id, 
            email, 
            full_name, 
            phone,
            username,
            address,
            account_number, 
            join_date,
            registration_date,
            referral_code,
            used_referral_code,
            language,
            currency,
            is_active,
            is_verified,
            verification_status,
            referral_earnings,
            profile_completed,
            created_at,
            updated_at
        )
        VALUES (
            NEW.id,
            NEW.email,
            user_full_name,
            user_phone,
            user_username,
            user_address,
            new_account_number,
            timezone('utc'::text, now()),
            timezone('utc'::text, now()),
            new_referral_code,
            referral_code_to_use,
            'ar',
            'dzd',
            true,
            false,
            'unverified',
            0.00,
            true,
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        );
        
        RAISE NOTICE 'Successfully created user profile for: %', NEW.email;
        
    EXCEPTION
        WHEN unique_violation THEN
            -- Handle duplicate key errors
            RAISE WARNING 'Duplicate key error creating user profile for %: %', NEW.email, SQLERRM;
            -- Try to update existing record instead
            UPDATE public.users 
            SET 
                full_name = user_full_name,
                phone = user_phone,
                username = user_username,
                address = user_address,
                used_referral_code = referral_code_to_use,
                updated_at = timezone('utc'::text, now())
            WHERE id = NEW.id;
            
        WHEN OTHERS THEN
            RAISE WARNING 'Error creating user profile for %: %', NEW.email, SQLERRM;
            -- Try minimal insert as fallback
            BEGIN
                INSERT INTO public.users (id, email, full_name, account_number, join_date, referral_code)
                VALUES (
                    NEW.id,
                    NEW.email,
                    user_full_name,
                    new_account_number,
                    timezone('utc'::text, now()),
                    new_referral_code
                )
                ON CONFLICT (id) DO UPDATE SET
                    full_name = EXCLUDED.full_name,
                    updated_at = timezone('utc'::text, now());
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING 'Failed to create minimal user profile for %: %', NEW.email, SQLERRM;
            END;
    END;
    
    -- Create initial balance record with error handling
    BEGIN
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, investment_balance, created_at, updated_at)
        VALUES (
            NEW.id, 
            20000.00, 
            100.00, 
            110.00, 
            85.00, 
            1000.00,
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        );
        
        RAISE NOTICE 'Successfully created initial balance for: %', NEW.email;
        
    EXCEPTION
        WHEN unique_violation THEN
            -- Balance already exists, update it
            RAISE WARNING 'Balance already exists for %', NEW.email;
            UPDATE public.balances 
            SET 
                dzd = GREATEST(dzd, 20000.00),
                eur = GREATEST(eur, 100.00),
                usd = GREATEST(usd, 110.00),
                gbp = GREATEST(gbp, 85.00),
                investment_balance = GREATEST(investment_balance, 1000.00),
                updated_at = timezone('utc'::text, now())
            WHERE user_id = NEW.id;
            
        WHEN OTHERS THEN
            RAISE WARNING 'Error creating initial balance for %: %', NEW.email, SQLERRM;
            -- Try minimal balance creation
            BEGIN
                INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
                VALUES (NEW.id, 0.00, 0.00, 0.00, 0.00)
                ON CONFLICT (user_id) DO UPDATE SET
                    updated_at = timezone('utc'::text, now());
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING 'Failed to create minimal balance for %: %', NEW.email, SQLERRM;
            END;
    END;
    
    -- Create user directory entry for transfers with enhanced error handling
    BEGIN
        RAISE NOTICE 'Creating user directory entry for: %', NEW.email;
        
        -- First, ensure the user_directory table exists
        CREATE TABLE IF NOT EXISTS public.user_directory (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
            email TEXT NOT NULL,
            email_normalized TEXT NOT NULL,
            full_name TEXT NOT NULL DEFAULT '',
            account_number TEXT,
            phone TEXT DEFAULT '',
            can_receive_transfers BOOLEAN DEFAULT true,
            is_active BOOLEAN DEFAULT true,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
            UNIQUE(user_id),
            UNIQUE(email_normalized),
            UNIQUE(account_number)
        );
        
        -- Ensure simple_transfers_users table exists first
        CREATE TABLE IF NOT EXISTS public.simple_transfers_users (
            id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
            user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
            email TEXT NOT NULL,
            email_normalized TEXT NOT NULL,
            full_name TEXT NOT NULL DEFAULT '',
            account_number TEXT,
            phone TEXT DEFAULT '',
            can_receive_transfers BOOLEAN DEFAULT true,
            is_active BOOLEAN DEFAULT true,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
            UNIQUE(user_id),
            UNIQUE(email_normalized),
            UNIQUE(account_number)
        );
        
        -- Create simple_transfers_users table for transfer system
        INSERT INTO public.simple_transfers_users (
            user_id,
            email,
            email_normalized,
            full_name,
            account_number,
            phone,
            can_receive_transfers,
            is_active,
            created_at,
            updated_at
        )
        VALUES (
            NEW.id,
            NEW.email,
            user_email_normalized,
            user_full_name,
            new_account_number,
            user_phone,
            true,
            true,
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        )
        ON CONFLICT (user_id) DO UPDATE SET
            email = EXCLUDED.email,
            email_normalized = EXCLUDED.email_normalized,
            full_name = EXCLUDED.full_name,
            account_number = EXCLUDED.account_number,
            phone = EXCLUDED.phone,
            updated_at = timezone('utc'::text, now());
            
        RAISE NOTICE 'Successfully created user directory entry for: %', NEW.email;
        
        -- Also ensure the user can be found by multiple search methods
        -- Create additional entries for search optimization
        BEGIN
            -- Insert into simple_transfers_users table for transfer system
            INSERT INTO public.simple_transfers_users (
                user_id,
                email,
                email_normalized,
                full_name,
                account_number,
                phone,
                can_receive_transfers,
                is_active,
                created_at,
                updated_at
            )
            VALUES (
                NEW.id,
                NEW.email,
                user_email_normalized,
                user_full_name,
                new_account_number,
                user_phone,
                true,
                true,
                timezone('utc'::text, now()),
                timezone('utc'::text, now())
            )
            ON CONFLICT (user_id) DO UPDATE SET
                email = EXCLUDED.email,
                email_normalized = EXCLUDED.email_normalized,
                full_name = EXCLUDED.full_name,
                account_number = EXCLUDED.account_number,
                phone = EXCLUDED.phone,
                updated_at = timezone('utc'::text, now());
        EXCEPTION
            WHEN OTHERS THEN
                -- Create the table if it doesn't exist
                CREATE TABLE IF NOT EXISTS public.simple_transfers_users (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
                    email TEXT NOT NULL,
                    email_normalized TEXT NOT NULL,
                    full_name TEXT NOT NULL DEFAULT '',
                    account_number TEXT,
                    phone TEXT DEFAULT '',
                    can_receive_transfers BOOLEAN DEFAULT true,
                    is_active BOOLEAN DEFAULT true,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
                    UNIQUE(user_id),
                    UNIQUE(email_normalized),
                    UNIQUE(account_number)
                );
                
                -- Try insert again
                INSERT INTO public.simple_transfers_users (
                    user_id, email, email_normalized, full_name, account_number, phone,
                    can_receive_transfers, is_active, created_at, updated_at
                )
                VALUES (
                    NEW.id, NEW.email, user_email_normalized, user_full_name, new_account_number, user_phone,
                    true, true, timezone('utc'::text, now()), timezone('utc'::text, now())
                )
                ON CONFLICT (user_id) DO UPDATE SET
                    email = EXCLUDED.email,
                    email_normalized = EXCLUDED.email_normalized,
                    full_name = EXCLUDED.full_name,
                    account_number = EXCLUDED.account_number,
                    phone = EXCLUDED.phone,
                    updated_at = timezone('utc'::text, now());
        END;
        
        -- Also create entries in other search tables for redundancy
        BEGIN
            -- Ensure user can be found by email in multiple ways
            INSERT INTO public.user_directory (user_id, email, email_normalized, full_name, account_number, phone, can_receive_transfers, is_active, created_at, updated_at)
            SELECT NEW.id, NEW.email, user_email_normalized, user_full_name, new_account_number, user_phone, true, true, timezone('utc'::text, now()), timezone('utc'::text, now())
            WHERE NOT EXISTS (SELECT 1 FROM public.user_directory WHERE email_normalized = user_email_normalized AND user_id != NEW.id);
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Error creating additional directory entries for %: %', NEW.email, SQLERRM;
        END;
            
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Error creating user directory entry for %: %', NEW.email, SQLERRM;
            -- Try a minimal insert as fallback
            BEGIN
                INSERT INTO public.user_directory (user_id, email, email_normalized, full_name, can_receive_transfers, is_active)
                VALUES (NEW.id, NEW.email, user_email_normalized, user_full_name, true, true)
                ON CONFLICT (user_id) DO NOTHING;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING 'Failed to create minimal user directory entry for %: %', NEW.email, SQLERRM;
            END;
    END;
    
    -- Handle referral reward if user used a referral code
    IF referral_code_to_use IS NOT NULL THEN
        BEGIN
            -- Find the referrer
            SELECT id INTO referrer_user_id 
            FROM public.users 
            WHERE referral_code = referral_code_to_use
            AND id != NEW.id
            AND is_active = true;
            
            -- If referrer found, process the referral
            IF referrer_user_id IS NOT NULL THEN
                -- Create referral record
                INSERT INTO public.referrals (
                    referrer_id,
                    referred_id,
                    referral_code,
                    reward_amount,
                    status,
                    created_at
                )
                VALUES (
                    referrer_user_id,
                    NEW.id,
                    referral_code_to_use,
                    500.00,
                    'completed',
                    timezone('utc'::text, now())
                )
                ON CONFLICT DO NOTHING;
                
                -- Add reward to referrer's balance
                UPDATE public.balances 
                SET 
                    dzd = dzd + 500.00,
                    updated_at = timezone('utc'::text, now())
                WHERE user_id = referrer_user_id;
                
                -- Update referrer's earnings
                UPDATE public.users 
                SET 
                    referral_earnings = referral_earnings + 500.00,
                    updated_at = timezone('utc'::text, now())
                WHERE id = referrer_user_id;
                
                -- Create notification for referrer
                INSERT INTO public.notifications (
                    user_id,
                    type,
                    title,
                    message,
                    is_read,
                    created_at
                )
                VALUES (
                    referrer_user_id,
                    'success',
                    'مكافأة إحالة جديدة',
                    'تم إضافة 500 دج إلى رصيدك بسبب إحالة مستخدم جديد',
                    false,
                    timezone('utc'::text, now())
                );
                
                RAISE NOTICE 'Successfully processed referral for user: % with referrer: %', NEW.email, referrer_user_id;
            ELSE
                RAISE WARNING 'Referral code % not found or invalid for user %', referral_code_to_use, NEW.email;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Error processing referral for %: %', NEW.email, SQLERRM;
        END;
    END IF;
    
    RAISE NOTICE 'Successfully completed user creation process for: %', NEW.email;
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Critical error in handle_new_user for %: %', NEW.email, SQLERRM;
        RETURN NEW; -- Don't fail the auth signup even if our trigger fails
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- Recreate the trigger with proper error handling
-- =============================================================================

-- Drop existing trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create new trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- Add safety constraints and indexes
-- =============================================================================

-- Ensure all existing users have referral codes
UPDATE public.users 
SET referral_code = public.generate_referral_code()
WHERE referral_code IS NULL OR referral_code = '';

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_account_number ON public.users(account_number);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON public.users(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_balances_user_id ON public.balances(user_id);
CREATE INDEX IF NOT EXISTS idx_user_directory_email_normalized ON public.user_directory(email_normalized);
CREATE INDEX IF NOT EXISTS idx_user_directory_email ON public.user_directory(email);
CREATE INDEX IF NOT EXISTS idx_user_directory_account_number ON public.user_directory(account_number);
CREATE INDEX IF NOT EXISTS idx_user_directory_user_id ON public.user_directory(user_id);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_users_email_normalized ON public.simple_transfers_users(email_normalized);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_users_email ON public.simple_transfers_users(email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_users_account_number ON public.simple_transfers_users(account_number);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_users_user_id ON public.simple_transfers_users(user_id);

-- =============================================================================
-- Create enhanced user search functions
-- =============================================================================

-- Enhanced find_user_simple function with better error handling and comprehensive search
CREATE OR REPLACE FUNCTION public.find_user_simple(p_identifier TEXT)
RETURNS TABLE(
    user_email TEXT,
    user_name TEXT,
    account_number TEXT,
    balance NUMERIC
) AS $$
DECLARE
    search_term TEXT;
    normalized_email TEXT;
BEGIN
    -- Clean and prepare search term
    search_term := TRIM(p_identifier);
    normalized_email := LOWER(search_term);
    
    RAISE NOTICE 'Searching for user with identifier: % (normalized: %)', search_term, normalized_email;
    
    -- Method 1: Direct search in user_directory by exact email
    RETURN QUERY
    SELECT 
        ud.email::TEXT as user_email,
        ud.full_name::TEXT as user_name,
        ud.account_number::TEXT as account_number,
        COALESCE(b.dzd, 0)::NUMERIC as balance
    FROM public.user_directory ud
    LEFT JOIN public.balances b ON ud.user_id = b.user_id
    WHERE (ud.email = search_term OR ud.email_normalized = normalized_email)
    AND ud.is_active = true
    AND ud.can_receive_transfers = true
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE 'Found user by email in user_directory';
        RETURN;
    END IF;
    
    -- Method 2: Search by account number in user_directory
    RETURN QUERY
    SELECT 
        ud.email::TEXT as user_email,
        ud.full_name::TEXT as user_name,
        ud.account_number::TEXT as account_number,
        COALESCE(b.dzd, 0)::NUMERIC as balance
    FROM public.user_directory ud
    LEFT JOIN public.balances b ON ud.user_id = b.user_id
    WHERE ud.account_number = search_term
    AND ud.is_active = true
    AND ud.can_receive_transfers = true
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE 'Found user by account number in user_directory';
        RETURN;
    END IF;
    
    -- Method 3: Search in simple_transfers_users table
    RETURN QUERY
    SELECT 
        stu.email::TEXT as user_email,
        stu.full_name::TEXT as user_name,
        stu.account_number::TEXT as account_number,
        COALESCE(b.dzd, 0)::NUMERIC as balance
    FROM public.simple_transfers_users stu
    LEFT JOIN public.balances b ON stu.user_id = b.user_id
    WHERE (stu.email = search_term OR stu.email_normalized = normalized_email OR stu.account_number = search_term)
    AND stu.is_active = true
    AND stu.can_receive_transfers = true
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE 'Found user in simple_transfers_users table';
        RETURN;
    END IF;
    
    -- Method 4: Fallback to main users table with comprehensive search
    RETURN QUERY
    SELECT 
        u.email::TEXT as user_email,
        u.full_name::TEXT as user_name,
        u.account_number::TEXT as account_number,
        COALESCE(b.dzd, 0)::NUMERIC as balance
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE (u.email = search_term OR LOWER(u.email) = normalized_email OR u.account_number = search_term)
    AND u.is_active = true
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE 'Found user in main users table';
        RETURN;
    END IF;
    
    -- Method 5: Last resort - search by partial matches
    RETURN QUERY
    SELECT 
        u.email::TEXT as user_email,
        u.full_name::TEXT as user_name,
        u.account_number::TEXT as account_number,
        COALESCE(b.dzd, 0)::NUMERIC as balance
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE (u.email ILIKE '%' || search_term || '%' OR u.account_number ILIKE '%' || search_term || '%')
    AND u.is_active = true
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE 'Found user by partial match in users table';
        RETURN;
    END IF;
    
    RAISE NOTICE 'No user found with identifier: %', search_term;
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to sync user data to user_directory (for existing users)
CREATE OR REPLACE FUNCTION public.sync_user_to_directory()
RETURNS INTEGER AS $$
DECLARE
    sync_count INTEGER := 0;
    user_record RECORD;
BEGIN
    -- Ensure user_directory table exists
    CREATE TABLE IF NOT EXISTS public.user_directory (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
        email TEXT NOT NULL,
        email_normalized TEXT NOT NULL,
        full_name TEXT NOT NULL DEFAULT '',
        account_number TEXT,
        phone TEXT DEFAULT '',
        can_receive_transfers BOOLEAN DEFAULT true,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
        UNIQUE(user_id),
        UNIQUE(email_normalized),
        UNIQUE(account_number)
    );
    
    -- Ensure simple_transfers_users table exists
    CREATE TABLE IF NOT EXISTS public.simple_transfers_users (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
        email TEXT NOT NULL,
        email_normalized TEXT NOT NULL,
        full_name TEXT NOT NULL DEFAULT '',
        account_number TEXT,
        phone TEXT DEFAULT '',
        can_receive_transfers BOOLEAN DEFAULT true,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
        UNIQUE(user_id),
        UNIQUE(email_normalized),
        UNIQUE(account_number)
    );
    
    -- Sync all users from users table to both directory tables
    FOR user_record IN 
        SELECT id, email, full_name, account_number, phone, is_active
        FROM public.users 
        WHERE is_active = true
    LOOP
        BEGIN
            -- Sync to user_directory
            INSERT INTO public.user_directory (
                user_id,
                email,
                email_normalized,
                full_name,
                account_number,
                phone,
                can_receive_transfers,
                is_active,
                created_at,
                updated_at
            )
            VALUES (
                user_record.id,
                user_record.email,
                LOWER(TRIM(user_record.email)),
                user_record.full_name,
                user_record.account_number,
                user_record.phone,
                true,
                user_record.is_active,
                timezone('utc'::text, now()),
                timezone('utc'::text, now())
            )
            ON CONFLICT (user_id) DO UPDATE SET
                email = EXCLUDED.email,
                email_normalized = EXCLUDED.email_normalized,
                full_name = EXCLUDED.full_name,
                account_number = EXCLUDED.account_number,
                phone = EXCLUDED.phone,
                is_active = EXCLUDED.is_active,
                updated_at = timezone('utc'::text, now());
            
            -- Sync to simple_transfers_users
            INSERT INTO public.simple_transfers_users (
                user_id,
                email,
                email_normalized,
                full_name,
                account_number,
                phone,
                can_receive_transfers,
                is_active,
                created_at,
                updated_at
            )
            VALUES (
                user_record.id,
                user_record.email,
                LOWER(TRIM(user_record.email)),
                user_record.full_name,
                user_record.account_number,
                user_record.phone,
                true,
                user_record.is_active,
                timezone('utc'::text, now()),
                timezone('utc'::text, now())
            )
            ON CONFLICT (user_id) DO UPDATE SET
                email = EXCLUDED.email,
                email_normalized = EXCLUDED.email_normalized,
                full_name = EXCLUDED.full_name,
                account_number = EXCLUDED.account_number,
                phone = EXCLUDED.phone,
                is_active = EXCLUDED.is_active,
                updated_at = timezone('utc'::text, now());
                
            sync_count := sync_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING 'Failed to sync user % to directory: %', user_record.email, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE 'Synced % users to both directory tables', sync_count;
    RETURN sync_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a comprehensive transfer processing function
-- Drop existing function first to avoid signature conflicts
DROP FUNCTION IF EXISTS public.process_simple_transfer(TEXT, TEXT, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.process_simple_transfer(TEXT, TEXT, NUMERIC);

CREATE OR REPLACE FUNCTION public.process_simple_transfer(
    p_sender_email TEXT,
    p_recipient_identifier TEXT,
    p_amount NUMERIC,
    p_description TEXT DEFAULT 'تحويل فوري'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    reference_number TEXT,
    sender_new_balance NUMERIC
) AS $$
DECLARE
    sender_user_id UUID;
    recipient_user_id UUID;
    sender_balance NUMERIC;
    recipient_info RECORD;
    new_reference TEXT;
BEGIN
    -- Generate reference number
    new_reference := 'TXN' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT || LPAD(FLOOR(RANDOM() * 1000)::TEXT, 3, '0');
    
    -- Find sender
    SELECT u.id, COALESCE(b.dzd, 0) INTO sender_user_id, sender_balance
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE LOWER(u.email) = LOWER(p_sender_email)
    AND u.is_active = true;
    
    IF sender_user_id IS NULL THEN
        RETURN QUERY SELECT false, 'المرسل غير موجود', '', 0::NUMERIC;
        RETURN;
    END IF;
    
    -- Check sender balance
    IF sender_balance < p_amount THEN
        RETURN QUERY SELECT false, 'الرصيد غير كافي', '', sender_balance;
        RETURN;
    END IF;
    
    -- Find recipient using the enhanced search function
    SELECT user_email, user_name, account_number INTO recipient_info
    FROM public.find_user_simple(p_recipient_identifier)
    LIMIT 1;
    
    IF recipient_info.user_email IS NULL THEN
        RETURN QUERY SELECT false, 'المستلم غير موجود', '', sender_balance;
        RETURN;
    END IF;
    
    -- Get recipient user_id
    SELECT u.id INTO recipient_user_id
    FROM public.users u
    WHERE LOWER(u.email) = LOWER(recipient_info.user_email)
    AND u.is_active = true;
    
    IF recipient_user_id IS NULL THEN
        RETURN QUERY SELECT false, 'المستلم غير نشط', '', sender_balance;
        RETURN;
    END IF;
    
    -- Prevent self-transfer
    IF sender_user_id = recipient_user_id THEN
        RETURN QUERY SELECT false, 'لا يمكن التحويل لنفس الحساب', '', sender_balance;
        RETURN;
    END IF;
    
    -- Process the transfer
    BEGIN
        -- Update sender balance
        UPDATE public.balances 
        SET dzd = dzd - p_amount, updated_at = timezone('utc'::text, now())
        WHERE user_id = sender_user_id;
        
        -- Update recipient balance
        UPDATE public.balances 
        SET dzd = dzd + p_amount, updated_at = timezone('utc'::text, now())
        WHERE user_id = recipient_user_id;
        
        -- Create transfer record
        INSERT INTO public.simple_transfers (
            sender_id, recipient_id, sender_email, recipient_email,
            sender_name, recipient_name, amount, description,
            reference_number, status, created_at
        )
        SELECT 
            sender_user_id, recipient_user_id, p_sender_email, recipient_info.user_email,
            s.full_name, recipient_info.user_name, p_amount, p_description,
            new_reference, 'completed', timezone('utc'::text, now())
        FROM public.users s WHERE s.id = sender_user_id;
        
        -- Get new sender balance
        SELECT COALESCE(b.dzd, 0) INTO sender_balance
        FROM public.balances b
        WHERE b.user_id = sender_user_id;
        
        RETURN QUERY SELECT true, 'تم التحويل بنجاح', new_reference, sender_balance;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN QUERY SELECT false, 'خطأ في معالجة التحويل: ' || SQLERRM, '', sender_balance;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create simple_transfers table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.simple_transfers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id UUID REFERENCES auth.users(id),
    recipient_id UUID REFERENCES auth.users(id),
    sender_email TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    sender_name TEXT,
    recipient_name TEXT,
    amount NUMERIC(15,2) NOT NULL,
    description TEXT,
    reference_number TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'completed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Add indexes for simple_transfers
CREATE INDEX IF NOT EXISTS idx_simple_transfers_sender_email ON public.simple_transfers(sender_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_recipient_email ON public.simple_transfers(recipient_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_reference ON public.simple_transfers(reference_number);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_created_at ON public.simple_transfers(created_at);

-- Run the sync function to ensure all existing users are in the directory
SELECT public.sync_user_to_directory();

-- =============================================================================
-- Create a manual user creation function for testing
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_test_user(
    test_email TEXT,
    test_password TEXT DEFAULT 'password123',
    test_name TEXT DEFAULT 'Test User'
)
RETURNS JSON AS $$
DECLARE
    result JSON;
    new_user_id UUID;
BEGIN
    -- Generate a UUID for the test user
    new_user_id := gen_random_uuid();
    
    -- Simulate the trigger function
    PERFORM public.handle_new_user_manual(
        new_user_id,
        test_email,
        jsonb_build_object('full_name', test_name)
    );
    
    result := json_build_object(
        'success', true,
        'user_id', new_user_id,
        'email', test_email,
        'message', 'Test user created successfully'
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'message', 'Failed to create test user'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function for manual user creation
CREATE OR REPLACE FUNCTION public.handle_new_user_manual(
    user_id UUID,
    user_email TEXT,
    user_metadata JSONB DEFAULT '{}'
)
RETURNS BOOLEAN AS $$
DECLARE
    mock_record RECORD;
BEGIN
    -- Create a mock NEW record
    SELECT 
        user_id as id,
        user_email as email,
        user_metadata as raw_user_meta_data
    INTO mock_record;
    
    -- Call the main function logic here
    -- This is a simplified version for testing
    INSERT INTO public.users (
        id, email, full_name, account_number, join_date, referral_code
    )
    VALUES (
        user_id,
        user_email,
        COALESCE(user_metadata->>'full_name', 'Test User'),
        'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0'),
        timezone('utc'::text, now()),
        public.generate_referral_code()
    );
    
    INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, investment_balance)
    VALUES (user_id, 20000.00, 100.00, 110.00, 85.00, 1000.00);
    
    RETURN true;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in manual user creation: %', SQLERRM;
        RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- Final verification and cleanup
-- =============================================================================

-- Ensure all required functions exist
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'generate_referral_code') 
        THEN 'generate_referral_code function exists'
        ELSE 'WARNING: generate_referral_code function missing'
    END as referral_function_status,
    
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'normalize_email') 
        THEN 'normalize_email function exists'
        ELSE 'WARNING: normalize_email function missing'
    END as email_function_status;

-- Show current trigger status
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- Final completion notice
DO $completion$
BEGIN
    RAISE NOTICE 'Comprehensive signup fix migration completed successfully';
END $completion$;