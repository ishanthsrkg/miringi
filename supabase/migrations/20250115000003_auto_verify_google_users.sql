-- =============================================================================
-- AUTO-VERIFY GOOGLE USERS MIGRATION
-- =============================================================================
-- This migration automatically verifies users who sign up with Google OAuth
-- by creating a trigger that detects Google provider signups and sets
-- verification status to 'verified' and is_verified to true
-- =============================================================================

-- Create function to auto-verify Google users
CREATE OR REPLACE FUNCTION public.auto_verify_google_users()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if this is a Google OAuth user by looking at the raw_app_meta_data
    IF NEW.raw_app_meta_data IS NOT NULL AND 
       NEW.raw_app_meta_data->>'provider' = 'google' THEN
        
        -- Log the Google user detection
        RAISE LOG 'Auto-verifying Google user: %', NEW.id;
        
        -- Update the user record to be verified if users table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
            -- First check if user already exists in users table
            IF EXISTS (SELECT 1 FROM public.users WHERE id = NEW.id) THEN
                -- Update existing user
                UPDATE public.users 
                SET 
                    is_verified = true,
                    verification_status = 'verified',
                    updated_at = NOW()
                WHERE id = NEW.id;
                
                RAISE LOG 'Updated existing Google user verification status: %', NEW.id;
            ELSE
                -- Insert new user record with verification
                INSERT INTO public.users (
                    id,
                    email,
                    full_name,
                    is_verified,
                    verification_status,
                    is_active,
                    created_at,
                    updated_at
                ) VALUES (
                    NEW.id,
                    NEW.email,
                    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'مستخدم جوجل'),
                    true,
                    'verified',
                    true,
                    NOW(),
                    NOW()
                ) ON CONFLICT (id) DO UPDATE SET
                    is_verified = true,
                    verification_status = 'verified',
                    updated_at = NOW();
                
                RAISE LOG 'Created new verified Google user: %', NEW.id;
            END IF;
        END IF;
        
        -- Also create/update balance record if balances table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'balances') THEN
            INSERT INTO public.balances (
                user_id,
                dzd,
                eur,
                usd,
                gbp,
                investment_balance,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,
                1000.00, -- Welcome bonus for Google users
                0.00,
                0.00,
                0.00,
                0.00,
                NOW(),
                NOW()
            ) ON CONFLICT (user_id) DO NOTHING;
            
            RAISE LOG 'Created balance record for Google user: %', NEW.id;
        END IF;
        
        -- Create user credentials if table exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_credentials') THEN
            INSERT INTO public.user_credentials (
                user_id,
                username,
                password_hash,
                created_at,
                updated_at
            ) VALUES (
                NEW.id,
                LOWER(REPLACE(COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'google_user'), ' ', '_')) || '_' || SUBSTRING(NEW.id::text, 1, 8),
                'google_oauth_user', -- Placeholder since Google users don't have passwords
                NOW(),
                NOW()
            ) ON CONFLICT (user_id) DO NOTHING;
            
            RAISE LOG 'Created credentials for Google user: %', NEW.id;
        END IF;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS auto_verify_google_users_trigger ON auth.users;

-- Create trigger on auth.users table to auto-verify Google users
CREATE TRIGGER auto_verify_google_users_trigger
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.auto_verify_google_users();

-- Also create a trigger for updates in case user data changes
DROP TRIGGER IF EXISTS auto_verify_google_users_update_trigger ON auth.users;

CREATE TRIGGER auto_verify_google_users_update_trigger
    AFTER UPDATE ON auth.users
    FOR EACH ROW
    WHEN (OLD.raw_app_meta_data IS DISTINCT FROM NEW.raw_app_meta_data)
    EXECUTE FUNCTION public.auto_verify_google_users();

-- Update existing Google users to be verified (if any exist)
DO $$
DECLARE
    google_user RECORD;
BEGIN
    -- Find all existing Google users who are not verified
    FOR google_user IN 
        SELECT au.id, au.email, au.raw_user_meta_data
        FROM auth.users au
        WHERE au.raw_app_meta_data->>'provider' = 'google'
        AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
        AND EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = au.id 
            AND (u.is_verified = false OR u.verification_status != 'verified')
        )
    LOOP
        -- Update the user to be verified
        UPDATE public.users 
        SET 
            is_verified = true,
            verification_status = 'verified',
            updated_at = NOW()
        WHERE id = google_user.id;
        
        RAISE LOG 'Auto-verified existing Google user: %', google_user.id;
    END LOOP;
    
    -- Also handle Google users who don't have records in public.users table
    FOR google_user IN 
        SELECT au.id, au.email, au.raw_user_meta_data
        FROM auth.users au
        WHERE au.raw_app_meta_data->>'provider' = 'google'
        AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
        AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = au.id)
    LOOP
        -- Create user record with verification
        INSERT INTO public.users (
            id,
            email,
            full_name,
            is_verified,
            verification_status,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            google_user.id,
            google_user.email,
            COALESCE(google_user.raw_user_meta_data->>'full_name', google_user.raw_user_meta_data->>'name', 'مستخدم جوجل'),
            true,
            'verified',
            true,
            NOW(),
            NOW()
        ) ON CONFLICT (id) DO UPDATE SET
            is_verified = true,
            verification_status = 'verified',
            updated_at = NOW();
        
        RAISE LOG 'Created verified record for existing Google user: %', google_user.id;
    END LOOP;
END
$$;

-- Create function to manually verify Google users (for admin use)
CREATE OR REPLACE FUNCTION public.verify_google_user(
    p_user_id UUID
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    user_provider TEXT;
BEGIN
    -- Check if user exists and is a Google user
    SELECT au.raw_app_meta_data->>'provider' INTO user_provider
    FROM auth.users au
    WHERE au.id = p_user_id;
    
    IF user_provider IS NULL THEN
        RETURN QUERY SELECT false, 'المستخدم غير موجود'::TEXT;
        RETURN;
    END IF;
    
    IF user_provider != 'google' THEN
        RETURN QUERY SELECT false, 'هذا المستخدم لم يسجل بجوجل'::TEXT;
        RETURN;
    END IF;
    
    -- Update user verification status
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
        UPDATE public.users 
        SET 
            is_verified = true,
            verification_status = 'verified',
            updated_at = NOW()
        WHERE id = p_user_id;
        
        IF FOUND THEN
            RETURN QUERY SELECT true, 'تم تفعيل المستخدم بنجاح'::TEXT;
        ELSE
            RETURN QUERY SELECT false, 'فشل في تحديث بيانات المستخدم'::TEXT;
        END IF;
    ELSE
        RETURN QUERY SELECT false, 'جدول المستخدمين غير موجود'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.auto_verify_google_users() TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_google_user(UUID) TO authenticated;

-- =============================================================================
-- MIGRATION COMPLETED
-- =============================================================================
-- Google users will now be automatically verified when they sign up:
-- 1. Trigger detects Google OAuth provider
-- 2. Sets is_verified = true and verification_status = 'verified'
-- 3. Creates necessary user records (users, balances, credentials)
-- 4. Existing Google users are also updated to be verified
-- 5. Manual verification function available for admin use
-- =============================================================================