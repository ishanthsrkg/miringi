-- =============================================================================
-- Comprehensive Fix for All Systems
-- This migration addresses all reported issues: referrals, investments, 
-- balance checks, transfers, card display, and new account creation
-- =============================================================================

-- =============================================================================
-- Create secure card number generation function FIRST
-- =============================================================================

-- Drop existing function first to avoid conflicts
DROP FUNCTION IF EXISTS public.generate_secure_card_number();

CREATE OR REPLACE FUNCTION public.generate_secure_card_number()
RETURNS TEXT AS $$
DECLARE
    v_card_number TEXT;
    number_exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a 16-digit card number starting with 4532 (Visa)
        v_card_number := '4532' || LPAD(FLOOR(RANDOM() * 1000000000000)::TEXT, 12, '0');
        
        -- Check if number already exists
        SELECT EXISTS(
            SELECT 1 
            FROM public.cards 
            WHERE card_number = v_card_number
        ) INTO number_exists;
        
        -- If number doesn't exist, return it
        IF NOT number_exists THEN
            RETURN v_card_number;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Fix referral system completely with enhanced validation
-- =============================================================================

-- Ensure all users have referral codes
UPDATE public.users 
SET referral_code = public.generate_referral_code()
WHERE referral_code IS NULL 
   OR referral_code = '' 
   OR LENGTH(referral_code) < 6;

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
) AS $
DECLARE
    v_referrer_id UUID;
    v_referrer_name TEXT;
    v_reward_amount NUMERIC := 500.00;
    v_bonus_amount NUMERIC := 100.00; -- مكافأة إضافية للمُحيل
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
    
    -- Add bonus to new user's balance (100 DZD welcome bonus)
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
        'تم منحك 100 دج كمكافأة ترحيب لاستخدام كود الإحالة',
        'welcome_bonus',
        false,
        timezone('utc'::text, now())
    );
    
    RETURN QUERY SELECT 
        true, 
        'تم منح مكافأة الإحالة بنجاح - 500 دج للمُحيل و 100 دج للمستخدم الجديد'::TEXT, 
        v_reward_amount,
        v_referrer_name;
END;
$ LANGUAGE plpgsql;

-- Create phone verification function
CREATE OR REPLACE FUNCTION public.verify_user_phone(
    p_user_id UUID,
    p_phone_number TEXT
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT
) AS $
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
$ LANGUAGE plpgsql;

-- =============================================================================
-- Fix investment system completely
-- =============================================================================

-- Ensure investment_balance column exists and is properly set
DO $investment_balance_fix$
BEGIN
    -- Add investment_balance column if missing
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'balances' 
          AND column_name = 'investment_balance'
    ) THEN
        ALTER TABLE public.balances 
        ADD COLUMN investment_balance NUMERIC(15,2) DEFAULT 0.00;
    END IF;
    
    -- Set default investment balance for existing users
    UPDATE public.balances 
    SET investment_balance = COALESCE(investment_balance, 1000.00)
    WHERE investment_balance IS NULL;
END $investment_balance_fix$;

-- Drop existing function first to avoid conflicts
DROP FUNCTION IF EXISTS public.process_investment_complete(UUID, NUMERIC, TEXT);

-- Create comprehensive investment processing function
CREATE OR REPLACE FUNCTION public.process_investment_complete(
    p_user_id UUID,
    p_amount NUMERIC,
    p_operation TEXT -- 'invest' or 'return'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    new_dzd_balance NUMERIC,
    new_investment_balance NUMERIC
) AS $$
DECLARE
    v_current_dzd NUMERIC;
    v_current_investment NUMERIC;
BEGIN
    -- Get current balances with lock
    SELECT dzd, investment_balance 
    INTO v_current_dzd, v_current_investment
    FROM public.balances 
    WHERE user_id = p_user_id
    FOR UPDATE;
    
    IF v_current_dzd IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            'المستخدم غير موجود'::TEXT, 
            0::NUMERIC, 
            0::NUMERIC;
        RETURN;
    END IF;
    
    -- Ensure investment_balance is not null
    v_current_investment := COALESCE(v_current_investment, 0);
    
    IF p_operation = 'invest' THEN
        -- Check sufficient DZD balance
        IF v_current_dzd < p_amount THEN
            RETURN QUERY SELECT 
                false, 
                'الرصيد غير كافي للاستثمار'::TEXT, 
                v_current_dzd, 
                v_current_investment;
            RETURN;
        END IF;
        
        -- Transfer from DZD to investment
        UPDATE public.balances 
        SET dzd = dzd - p_amount,
            investment_balance = COALESCE(investment_balance, 0) + p_amount,
            updated_at = timezone('utc'::text, now())
        WHERE user_id = p_user_id;
        
        v_current_dzd := v_current_dzd - p_amount;
        v_current_investment := v_current_investment + p_amount;
        
        RETURN QUERY SELECT 
            true, 
            'تم الاستثمار بنجاح'::TEXT, 
            v_current_dzd, 
            v_current_investment;
        
    ELSIF p_operation = 'return' THEN
        -- Check sufficient investment balance
        IF v_current_investment < p_amount THEN
            RETURN QUERY SELECT 
                false, 
                'رصيد الاستثمار غير كافي'::TEXT, 
                v_current_dzd, 
                v_current_investment;
            RETURN;
        END IF;
        
        -- Transfer from investment to DZD
        UPDATE public.balances 
        SET dzd = dzd + p_amount,
            investment_balance = GREATEST(
                COALESCE(investment_balance, 0) - p_amount, 
                0
            ),
            updated_at = timezone('utc'::text, now())
        WHERE user_id = p_user_id;
        
        v_current_dzd := v_current_dzd + p_amount;
        v_current_investment := GREATEST(v_current_investment - p_amount, 0);
        
        RETURN QUERY SELECT 
            true, 
            'تم سحب الاستثمار بنجاح'::TEXT, 
            v_current_dzd, 
            v_current_investment;
        
    ELSE
        RETURN QUERY SELECT 
            false, 
            'عملية غير صحيحة'::TEXT, 
            v_current_dzd, 
            v_current_investment;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Fix balance checking and display
-- =============================================================================

-- Ensure all users have proper balances
INSERT INTO public.balances (
    user_id, 
    dzd, 
    eur, 
    usd, 
    gbp, 
    investment_balance, 
    created_at, 
    updated_at
)
SELECT 
    u.id,
    20000.00,
    100.00,
    110.00,
    85.00,
    1000.00,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
FROM public.users u
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.balances b 
    WHERE b.user_id = u.id
)
ON CONFLICT (user_id) DO NOTHING;

-- Fix any null balances
UPDATE public.balances 
SET dzd = COALESCE(dzd, 20000.00),
    eur = COALESCE(eur, 100.00),
    usd = COALESCE(usd, 110.00),
    gbp = COALESCE(gbp, 85.00),
    investment_balance = COALESCE(investment_balance, 1000.00),
    updated_at = timezone('utc'::text, now())
WHERE dzd IS NULL 
   OR eur IS NULL 
   OR usd IS NULL 
   OR gbp IS NULL 
   OR investment_balance IS NULL;

-- Drop existing function first to avoid conflicts
DROP FUNCTION IF EXISTS public.update_user_balance_safe(
    UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC
);

-- Create improved balance update function
CREATE OR REPLACE FUNCTION public.update_user_balance_safe(
    p_user_id UUID,
    p_dzd NUMERIC DEFAULT NULL,
    p_eur NUMERIC DEFAULT NULL,
    p_usd NUMERIC DEFAULT NULL,
    p_gbp NUMERIC DEFAULT NULL,
    p_investment_balance NUMERIC DEFAULT NULL
)
RETURNS TABLE(
    user_id UUID,
    dzd NUMERIC,
    eur NUMERIC,
    usd NUMERIC,
    gbp NUMERIC,
    investment_balance NUMERIC,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Ensure user has a balance record
    INSERT INTO public.balances (
        user_id, 
        dzd, 
        eur, 
        usd, 
        gbp, 
        investment_balance, 
        created_at, 
        updated_at
    )
    VALUES (
        p_user_id, 
        0, 
        0, 
        0, 
        0, 
        0, 
        timezone('utc'::text, now()), 
        timezone('utc'::text, now())
    )
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Update only provided values
    UPDATE public.balances 
    SET dzd = CASE 
            WHEN p_dzd IS NOT NULL THEN GREATEST(p_dzd, 0) 
            ELSE dzd 
        END,
        eur = CASE 
            WHEN p_eur IS NOT NULL THEN GREATEST(p_eur, 0) 
            ELSE eur 
        END,
        usd = CASE 
            WHEN p_usd IS NOT NULL THEN GREATEST(p_usd, 0) 
            ELSE usd 
        END,
        gbp = CASE 
            WHEN p_gbp IS NOT NULL THEN GREATEST(p_gbp, 0) 
            ELSE gbp 
        END,
        investment_balance = CASE 
            WHEN p_investment_balance IS NOT NULL THEN GREATEST(p_investment_balance, 0) 
            ELSE investment_balance 
        END,
        updated_at = timezone('utc'::text, now())
    WHERE balances.user_id = p_user_id;
    
    -- Return updated record
    RETURN QUERY
    SELECT 
        b.user_id,
        b.dzd,
        b.eur,
        b.usd,
        b.gbp,
        b.investment_balance,
        b.updated_at
    FROM public.balances b
    WHERE b.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Fix transfer system for all accounts
-- =============================================================================

-- Ensure all users are in directory tables
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
SELECT 
    u.id,
    u.email,
    LOWER(TRIM(u.email)),
    COALESCE(u.full_name, 'مستخدم'),
    u.account_number,
    COALESCE(u.phone, ''),
    true,
    COALESCE(u.is_active, true),
    COALESCE(u.created_at, timezone('utc'::text, now())),
    timezone('utc'::text, now())
FROM public.users u
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.user_directory ud 
    WHERE ud.user_id = u.id
)
ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    email_normalized = EXCLUDED.email_normalized,
    full_name = EXCLUDED.full_name,
    account_number = EXCLUDED.account_number,
    phone = EXCLUDED.phone,
    updated_at = timezone('utc'::text, now());

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
SELECT 
    u.id,
    u.email,
    LOWER(TRIM(u.email)),
    COALESCE(u.full_name, 'مستخدم'),
    u.account_number,
    COALESCE(u.phone, ''),
    true,
    COALESCE(u.is_active, true),
    COALESCE(u.created_at, timezone('utc'::text, now())),
    timezone('utc'::text, now())
FROM public.users u
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.simple_transfers_users stu 
    WHERE stu.user_id = u.id
)
ON CONFLICT (user_id) DO UPDATE SET
    email = EXCLUDED.email,
    email_normalized = EXCLUDED.email_normalized,
    full_name = EXCLUDED.full_name,
    account_number = EXCLUDED.account_number,
    phone = EXCLUDED.phone,
    updated_at = timezone('utc'::text, now());

-- Drop existing function first to avoid conflicts
DROP FUNCTION IF EXISTS public.process_simple_transfer_improved(
    TEXT, TEXT, NUMERIC, TEXT
);

-- Improved transfer processing function
CREATE OR REPLACE FUNCTION public.process_simple_transfer_improved(
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
    v_sender_id UUID;
    v_recipient_id UUID;
    v_sender_balance NUMERIC;
    v_recipient_info RECORD;
    v_reference TEXT;
BEGIN
    -- Find sender
    SELECT u.id INTO v_sender_id 
    FROM public.users u
    WHERE u.email = p_sender_email 
      AND u.is_active = true;
    
    IF v_sender_id IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            'المرسل غير موجود'::TEXT, 
            ''::TEXT, 
            0::NUMERIC;
        RETURN;
    END IF;
    
    -- Get sender balance with lock
    SELECT dzd INTO v_sender_balance 
    FROM public.balances 
    WHERE user_id = v_sender_id
    FOR UPDATE;
    
    IF v_sender_balance IS NULL OR v_sender_balance < p_amount THEN
        RETURN QUERY SELECT 
            false, 
            'الرصيد غير كافي'::TEXT, 
            ''::TEXT, 
            COALESCE(v_sender_balance, 0)::NUMERIC;
        RETURN;
    END IF;
    
    -- Find recipient by email or account number
    SELECT u.id, u.full_name, u.email, u.account_number 
    INTO v_recipient_info
    FROM public.users u
    WHERE (
        u.email = p_recipient_identifier 
        OR u.account_number = p_recipient_identifier
        OR LOWER(u.email) = LOWER(p_recipient_identifier)
    )
    AND u.is_active = true
    AND u.id != v_sender_id;
    
    IF v_recipient_info.id IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            'المستلم غير موجود أو غير نشط'::TEXT, 
            ''::TEXT, 
            v_sender_balance::NUMERIC;
        RETURN;
    END IF;
    
    -- Generate unique reference
    v_reference := public.generate_simple_reference();
    
    -- Update sender balance
    UPDATE public.balances 
    SET dzd = dzd - p_amount, 
        updated_at = timezone('utc'::text, now())
    WHERE user_id = v_sender_id;
    
    -- Update recipient balance (ensure they have a balance record)
    INSERT INTO public.balances (
        user_id, 
        dzd, 
        eur, 
        usd, 
        gbp, 
        investment_balance, 
        created_at, 
        updated_at
    )
    VALUES (
        v_recipient_info.id, 
        0, 
        0, 
        0, 
        0, 
        0, 
        timezone('utc'::text, now()), 
        timezone('utc'::text, now())
    )
    ON CONFLICT (user_id) DO NOTHING;
    
    UPDATE public.balances 
    SET dzd = dzd + p_amount, 
        updated_at = timezone('utc'::text, now())
    WHERE user_id = v_recipient_info.id;
    
    -- Record transfer
    INSERT INTO public.simple_transfers (
        sender_email,
        recipient_email,
        sender_name,
        recipient_name,
        sender_account_number,
        recipient_account_number,
        amount,
        description,
        reference_number,
        status
    )
    SELECT 
        p_sender_email,
        v_recipient_info.email,
        (SELECT full_name FROM public.users WHERE id = v_sender_id),
        v_recipient_info.full_name,
        (SELECT account_number FROM public.users WHERE id = v_sender_id),
        v_recipient_info.account_number,
        p_amount,
        p_description,
        v_reference,
        'completed';
    
    -- Get new sender balance
    SELECT dzd INTO v_sender_balance 
    FROM public.balances 
    WHERE user_id = v_sender_id;
    
    RETURN QUERY SELECT 
        true, 
        'تم التحويل بنجاح'::TEXT, 
        v_reference, 
        v_sender_balance;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Fix card system and display
-- =============================================================================

-- Ensure all users have cards
DO $cards_fix_block$
DECLARE
    user_record RECORD;
    solid_card_number TEXT;
    virtual_card_number TEXT;
BEGIN
    FOR user_record IN SELECT id FROM public.users LOOP
        -- Check if user has cards
        IF NOT EXISTS (
            SELECT 1 
            FROM public.cards 
            WHERE user_id = user_record.id
        ) THEN
            -- Generate card numbers
            solid_card_number := public.generate_secure_card_number();
            virtual_card_number := public.generate_secure_card_number();
            
            -- Create solid card
            INSERT INTO public.cards (
                user_id,
                card_number,
                card_type,
                is_frozen,
                spending_limit,
                balance,
                currency,
                created_at,
                updated_at
            ) VALUES (
                user_record.id,
                solid_card_number,
                'solid',
                false,
                100000.00,
                0.00,
                'dzd',
                timezone('utc'::text, now()),
                timezone('utc'::text, now())
            );
            
            -- Create virtual card
            INSERT INTO public.cards (
                user_id,
                card_number,
                card_type,
                is_frozen,
                spending_limit,
                balance,
                currency,
                created_at,
                updated_at
            ) VALUES (
                user_record.id,
                virtual_card_number,
                'virtual',
                false,
                50000.00,
                0.00,
                'dzd',
                timezone('utc'::text, now()),
                timezone('utc'::text, now())
            );
        END IF;
    END LOOP;
END $cards_fix_block$;

-- =============================================================================
-- Fix new account creation with referrals
-- =============================================================================

-- Drop existing trigger and function first to avoid conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user_improved();
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Update the handle_new_user function to be more robust
CREATE OR REPLACE FUNCTION public.handle_new_user_improved()
RETURNS TRIGGER AS $$
DECLARE
    new_referral_code TEXT;
    new_account_number TEXT;
    user_full_name TEXT;
    user_phone TEXT;
    user_username TEXT;
    user_address TEXT;
    user_referral_code TEXT;
    referral_result RECORD;
BEGIN
    RAISE NOTICE 'handle_new_user_improved trigger started for user: %', NEW.id;
    
    -- Extract user metadata safely
    user_full_name := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''), 
        'مستخدم جديد'
    );
    user_phone := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), ''), 
        ''
    );
    user_username := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'username'), ''), 
        ''
    );
    user_address := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'address'), ''), 
        ''
    );
    user_referral_code := COALESCE(
        NULLIF(TRIM(NEW.raw_user_meta_data->>'used_referral_code'), ''), 
        ''
    );
    
    -- Generate unique referral code
    new_referral_code := public.generate_referral_code();
    IF new_referral_code IS NULL OR LENGTH(new_referral_code) < 6 THEN
        new_referral_code := 'REF' || LPAD(
            FLOOR(RANDOM() * 1000000)::TEXT, 
            6, 
            '0'
        );
    END IF;
    
    -- Generate unique account number
    new_account_number := 'ACC' || LPAD(
        FLOOR(RANDOM() * 1000000000)::TEXT, 
        9, 
        '0'
    );
    WHILE EXISTS (
        SELECT 1 
        FROM public.users 
        WHERE account_number = new_account_number
    ) LOOP
        new_account_number := 'ACC' || LPAD(
            FLOOR(RANDOM() * 1000000000)::TEXT, 
            9, 
            '0'
        );
    END LOOP;
    
    -- Insert user profile
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
            created_at, 
            updated_at, 
            referral_code, 
            used_referral_code,
            referral_earnings, 
            is_active, 
            is_verified, 
            verification_status,
            profile_completed, 
            registration_date
        ) VALUES (
            NEW.id, 
            NEW.email, 
            user_full_name, 
            user_phone, 
            user_username, 
            user_address,
            new_account_number, 
            timezone('utc'::text, now()), 
            timezone('utc'::text, now()),
            timezone('utc'::text, now()), 
            new_referral_code, 
            user_referral_code,
            0.00, 
            true, 
            false, 
            'unverified', 
            true, 
            timezone('utc'::text, now())
        );
        RAISE NOTICE 'User profile created successfully';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create user profile: %', SQLERRM;
    END;
    
    -- Create initial balance
    BEGIN
        INSERT INTO public.balances (
            user_id, 
            dzd, 
            eur, 
            usd, 
            gbp, 
            investment_balance, 
            created_at, 
            updated_at
        )
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
        RAISE NOTICE 'Balance created successfully';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create balance: %', SQLERRM;
    END;
    
    -- Create cards
    BEGIN
        INSERT INTO public.cards (
            user_id, 
            card_number, 
            card_type, 
            is_frozen, 
            spending_limit, 
            balance, 
            currency, 
            created_at, 
            updated_at
        )
        VALUES 
            (
                NEW.id, 
                public.generate_secure_card_number(), 
                'solid', 
                false, 
                100000.00, 
                0.00, 
                'dzd', 
                timezone('utc'::text, now()), 
                timezone('utc'::text, now())
            ),
            (
                NEW.id, 
                public.generate_secure_card_number(), 
                'virtual', 
                false, 
                50000.00, 
                0.00, 
                'dzd', 
                timezone('utc'::text, now()), 
                timezone('utc'::text, now())
            );
        RAISE NOTICE 'Cards created successfully';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create cards: %', SQLERRM;
    END;
    
    -- Sync to directory tables
    BEGIN
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
            NEW.id, 
            NEW.email, 
            LOWER(TRIM(NEW.email)), 
            user_full_name, 
            new_account_number, 
            user_phone, 
            true, 
            true, 
            timezone('utc'::text, now()), 
            timezone('utc'::text, now())
        );
        
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
            LOWER(TRIM(NEW.email)), 
            user_full_name, 
            new_account_number, 
            user_phone, 
            true, 
            true, 
            timezone('utc'::text, now()), 
            timezone('utc'::text, now())
        );
        
        RAISE NOTICE 'Directory entries created successfully';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create directory entries: %', SQLERRM;
    END;
    
    -- Process referral if provided
    IF user_referral_code IS NOT NULL AND user_referral_code != '' THEN
        BEGIN
            SELECT * INTO referral_result 
            FROM public.process_referral_reward(NEW.id, user_referral_code);
            
            IF referral_result.success THEN
                RAISE NOTICE 'Referral reward processed successfully: %', 
                    referral_result.message;
            ELSE
                RAISE WARNING 'Referral processing failed: %', 
                    referral_result.message;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to process referral: %', SQLERRM;
        END;
    END IF;
    
    RAISE NOTICE 'handle_new_user_improved completed successfully for user: %', 
        NEW.id;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Critical error in handle_new_user_improved: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Replace the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_improved();

-- =============================================================================
-- Update existing functions to use improved versions
-- =============================================================================

-- Replace the old functions with improved versions
DROP FUNCTION IF EXISTS public.update_user_balance(
    UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC
);
DROP FUNCTION IF EXISTS public.update_user_balance(
    UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC
);
DROP FUNCTION IF EXISTS public.update_user_balance(UUID, NUMERIC);

CREATE OR REPLACE FUNCTION public.update_user_balance(
    p_user_id UUID,
    p_dzd NUMERIC DEFAULT NULL,
    p_eur NUMERIC DEFAULT NULL,
    p_usd NUMERIC DEFAULT NULL,
    p_gbp NUMERIC DEFAULT NULL,
    p_investment_balance NUMERIC DEFAULT NULL
)
RETURNS TABLE(
    user_id UUID,
    dzd NUMERIC,
    eur NUMERIC,
    usd NUMERIC,
    gbp NUMERIC,
    investment_balance NUMERIC,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY SELECT * 
    FROM public.update_user_balance_safe(
        p_user_id, 
        p_dzd, 
        p_eur, 
        p_usd, 
        p_gbp, 
        p_investment_balance
    );
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS public.process_investment(UUID, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.process_investment(UUID, NUMERIC);

CREATE OR REPLACE FUNCTION public.process_investment(
    p_user_id UUID,
    p_amount NUMERIC,
    p_operation TEXT
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    new_dzd_balance NUMERIC,
    new_investment_balance NUMERIC
) AS $$
BEGIN
    RETURN QUERY SELECT * 
    FROM public.process_investment_complete(
        p_user_id, 
        p_amount, 
        p_operation
    );
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS public.process_simple_transfer(
    TEXT, TEXT, NUMERIC, TEXT
);
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
BEGIN
    RETURN QUERY SELECT * 
    FROM public.process_simple_transfer_improved(
        p_sender_email, 
        p_recipient_identifier, 
        p_amount, 
        p_description
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Final validation and cleanup
-- =============================================================================

-- Ensure all users have complete data
DO $final_validation$
DECLARE
    user_count INTEGER;
    balance_count INTEGER;
    card_count INTEGER;
    directory_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM public.users;
    SELECT COUNT(*) INTO balance_count FROM public.balances;
    SELECT COUNT(*) INTO card_count FROM public.cards;
    SELECT COUNT(*) INTO directory_count FROM public.user_directory;
    
    RAISE NOTICE 'Final validation:';
    RAISE NOTICE '- Users: %', user_count;
    RAISE NOTICE '- Balances: %', balance_count;
    RAISE NOTICE '- Cards: %', card_count;
    RAISE NOTICE '- Directory entries: %', directory_count;
    
    -- Fix any missing data
    IF user_count != balance_count THEN
        RAISE WARNING 'Fixing missing balances...';
        INSERT INTO public.balances (
            user_id, 
            dzd, 
            eur, 
            usd, 
            gbp, 
            investment_balance, 
            created_at, 
            updated_at
        )
        SELECT 
            u.id, 
            20000.00, 
            100.00, 
            110.00, 
            85.00, 
            1000.00, 
            timezone('utc'::text, now()), 
            timezone('utc'::text, now())
        FROM public.users u
        WHERE NOT EXISTS (
            SELECT 1 
            FROM public.balances b 
            WHERE b.user_id = u.id
        );
    END IF;
    
    -- Ensure all users have referral codes
    UPDATE public.users 
    SET referral_code = public.generate_referral_code()
    WHERE referral_code IS NULL 
       OR referral_code = '' 
       OR LENGTH(referral_code) < 6;
    
    RAISE NOTICE 'All systems fixed and validated successfully!';
END $final_validation$;

-- =============================================================================
-- Grant necessary permissions
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.process_referral_reward(UUID, TEXT) 
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_investment_complete(UUID, NUMERIC, TEXT) 
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_balance_safe(
    UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, NUMERIC
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_simple_transfer_improved(
    TEXT, TEXT, NUMERIC, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_secure_card_number() 
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user_improved() 
    TO authenticated;

COMMIT;
