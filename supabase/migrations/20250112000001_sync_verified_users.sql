-- =============================================================================
-- SYNC VERIFIED USERS TO ALL TABLES
-- =============================================================================
-- This migration creates a function to sync users who have verified their email
-- to ensure their information appears in all relevant tables, especially public.users
-- =============================================================================

-- Create a function to sync verified users from auth.users to public.users
CREATE OR REPLACE FUNCTION public.sync_verified_user_to_tables()
RETURNS TRIGGER AS $$
DECLARE
    new_referral_code TEXT;
    referrer_user_id UUID;
BEGIN
    -- Only proceed if email is being confirmed (email_confirmed_at is being set)
    IF OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL THEN
        
        -- Check if user already exists in public.users
        IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = NEW.id) THEN
            
            -- Generate unique referral code
            new_referral_code := public.generate_referral_code();
            
            -- Insert user profile into public.users
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
            VALUES (
                NEW.id,
                NEW.email,
                COALESCE(NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
                COALESCE(NEW.raw_user_meta_data->>'phone', ''),
                'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0'),
                new_referral_code,
                COALESCE(NEW.raw_user_meta_data->>'used_referral_code', ''),
                TRUE,  -- Set as verified since email is confirmed
                'approved',  -- Set verification status as approved
                NEW.created_at,
                NOW()
            );
            
            -- Create initial balance record if it doesn't exist
            IF NOT EXISTS (SELECT 1 FROM public.balances WHERE user_id = NEW.id) THEN
                INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, created_at, updated_at)
                VALUES (NEW.id, 15000.00, 75.00, 85.00, 65.50, NOW(), NOW());
            END IF;
            
            -- Create user credentials record if it doesn't exist
            IF NOT EXISTS (SELECT 1 FROM public.user_credentials WHERE user_id = NEW.id) THEN
                INSERT INTO public.user_credentials (user_id, username, password_hash, created_at, updated_at)
                VALUES (
                    NEW.id, 
                    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1)),
                    'hashed_password_placeholder',
                    NOW(),
                    NOW()
                );
            END IF;
            
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
                        status,
                        created_at,
                        updated_at
                    )
                    VALUES (
                        referrer_user_id,
                        NEW.id,
                        NEW.raw_user_meta_data->>'used_referral_code',
                        500.00,
                        'completed',
                        NOW(),
                        NOW()
                    );
                    
                    -- Add reward to referrer's balance
                    UPDATE public.balances 
                    SET dzd = dzd + 500.00,
                        updated_at = NOW()
                    WHERE user_id = referrer_user_id;
                    
                    -- Update referrer's earnings
                    UPDATE public.users 
                    SET referral_earnings = COALESCE(referral_earnings, 0) + 500.00,
                        updated_at = NOW()
                    WHERE id = referrer_user_id;
                    
                    -- Create notification for referrer
                    INSERT INTO public.notifications (
                        user_id,
                        type,
                        title,
                        message,
                        created_at,
                        updated_at
                    )
                    VALUES (
                        referrer_user_id,
                        'success',
                        'مكافأة إحالة جديدة',
                        'تم إضافة 500 دج إلى رصيدك بسبب إحالة مستخدم جديد',
                        NOW(),
                        NOW()
                    );
                END IF;
            END IF;
            
            -- Create welcome notification for the new verified user
            INSERT INTO public.notifications (
                user_id,
                type,
                title,
                message,
                created_at,
                updated_at
            )
            VALUES (
                NEW.id,
                'success',
                'مرحباً بك!',
                'تم تأكيد بريدك الإلكتروني بنجاح. يمكنك الآن استخدام جميع خدمات التطبيق.',
                NOW(),
                NOW()
            );
            
        ELSE
            -- User exists but email was just confirmed, update verification status
            UPDATE public.users 
            SET 
                is_verified = TRUE,
                verification_status = 'approved',
                updated_at = NOW()
            WHERE id = NEW.id AND (is_verified = FALSE OR verification_status != 'approved');
        END IF;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to sync verified users automatically
DROP TRIGGER IF EXISTS sync_verified_user_trigger ON auth.users;
CREATE TRIGGER sync_verified_user_trigger
    AFTER UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_verified_user_to_tables();

-- Create a manual function to sync all existing verified users
CREATE OR REPLACE FUNCTION public.sync_all_verified_users()
RETURNS TABLE(synced_count INTEGER, message TEXT) AS $$
DECLARE
    user_record RECORD;
    sync_count INTEGER := 0;
    new_referral_code TEXT;
BEGIN
    -- Loop through all verified auth users who don't exist in public.users
    FOR user_record IN 
        SELECT au.* 
        FROM auth.users au
        LEFT JOIN public.users pu ON au.id = pu.id
        WHERE au.email_confirmed_at IS NOT NULL 
        AND pu.id IS NULL
    LOOP
        -- Generate unique referral code
        new_referral_code := public.generate_referral_code();
        
        -- Insert user profile into public.users
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
        VALUES (
            user_record.id,
            user_record.email,
            COALESCE(user_record.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
            COALESCE(user_record.raw_user_meta_data->>'phone', ''),
            'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0'),
            new_referral_code,
            COALESCE(user_record.raw_user_meta_data->>'used_referral_code', ''),
            TRUE,
            'approved',
            user_record.created_at,
            NOW()
        );
        
        -- Create initial balance record if it doesn't exist
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, created_at, updated_at)
        VALUES (user_record.id, 15000.00, 75.00, 85.00, 65.50, NOW(), NOW())
        ON CONFLICT (user_id) DO NOTHING;
        
        -- Create user credentials record if it doesn't exist
        INSERT INTO public.user_credentials (user_id, username, password_hash, created_at, updated_at)
        VALUES (
            user_record.id, 
            COALESCE(user_record.raw_user_meta_data->>'username', SPLIT_PART(user_record.email, '@', 1)),
            'hashed_password_placeholder',
            NOW(),
            NOW()
        )
        ON CONFLICT (user_id) DO NOTHING;
        
        sync_count := sync_count + 1;
    END LOOP;
    
    -- Return results
    RETURN QUERY SELECT sync_count, CASE 
        WHEN sync_count = 0 THEN 'لا توجد مستخدمين جدد للمزامنة'
        WHEN sync_count = 1 THEN 'تم مزامنة مستخدم واحد بنجاح'
        ELSE 'تم مزامنة ' || sync_count || ' مستخدمين بنجاح'
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Run the sync function to sync all existing verified users
SELECT * FROM public.sync_all_verified_users();

-- Create a function to check and ensure user data consistency
CREATE OR REPLACE FUNCTION public.ensure_user_data_consistency(p_user_id UUID)
RETURNS TABLE(status TEXT, message TEXT) AS $$
DECLARE
    auth_user_exists BOOLEAN := FALSE;
    public_user_exists BOOLEAN := FALSE;
    balance_exists BOOLEAN := FALSE;
    credentials_exist BOOLEAN := FALSE;
    new_referral_code TEXT;
BEGIN
    -- Check if user exists in auth.users and is verified
    SELECT EXISTS(
        SELECT 1 FROM auth.users 
        WHERE id = p_user_id AND email_confirmed_at IS NOT NULL
    ) INTO auth_user_exists;
    
    -- Check if user exists in public.users
    SELECT EXISTS(
        SELECT 1 FROM public.users WHERE id = p_user_id
    ) INTO public_user_exists;
    
    -- Check if balance exists
    SELECT EXISTS(
        SELECT 1 FROM public.balances WHERE user_id = p_user_id
    ) INTO balance_exists;
    
    -- Check if credentials exist
    SELECT EXISTS(
        SELECT 1 FROM public.user_credentials WHERE user_id = p_user_id
    ) INTO credentials_exist;
    
    -- If auth user exists and is verified but public user doesn't exist, create it
    IF auth_user_exists AND NOT public_user_exists THEN
        new_referral_code := public.generate_referral_code();
        
        INSERT INTO public.users (
            id, email, full_name, phone, account_number, referral_code,
            used_referral_code, is_verified, verification_status, created_at, updated_at
        )
        SELECT 
            au.id, au.email,
            COALESCE(au.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
            COALESCE(au.raw_user_meta_data->>'phone', ''),
            'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0'),
            new_referral_code,
            COALESCE(au.raw_user_meta_data->>'used_referral_code', ''),
            TRUE, 'approved', au.created_at, NOW()
        FROM auth.users au WHERE au.id = p_user_id;
    END IF;
    
    -- Create balance if missing
    IF auth_user_exists AND NOT balance_exists THEN
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, created_at, updated_at)
        VALUES (p_user_id, 15000.00, 75.00, 85.00, 65.50, NOW(), NOW());
    END IF;
    
    -- Create credentials if missing
    IF auth_user_exists AND NOT credentials_exist THEN
        INSERT INTO public.user_credentials (user_id, username, password_hash, created_at, updated_at)
        SELECT 
            p_user_id,
            COALESCE(au.raw_user_meta_data->>'username', SPLIT_PART(au.email, '@', 1)),
            'hashed_password_placeholder',
            NOW(), NOW()
        FROM auth.users au WHERE au.id = p_user_id;
    END IF;
    
    -- Return status
    IF NOT auth_user_exists THEN
        RETURN QUERY SELECT 'error'::TEXT, 'المستخدم غير موجود أو غير مؤكد البريد الإلكتروني'::TEXT;
    ELSE
        RETURN QUERY SELECT 'success'::TEXT, 'تم التأكد من اتساق بيانات المستخدم بنجاح'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- VERIFICATION SYNC SYSTEM CREATED SUCCESSFULLY
-- =============================================================================
-- Functions created:
-- 1. sync_verified_user_to_tables() - Automatically syncs users when email is verified
-- 2. sync_all_verified_users() - Manually sync all existing verified users
-- 3. ensure_user_data_consistency() - Check and fix user data consistency
-- 
-- Trigger created:
-- - sync_verified_user_trigger - Automatically runs when auth.users is updated
-- =============================================================================
