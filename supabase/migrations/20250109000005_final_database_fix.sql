-- Final Database Fix and Validation
-- This migration ensures all database objects are properly created and configured

-- =============================================================================
-- Ensure all required functions exist
-- =============================================================================

-- Create generate_referral_code function if it doesn't exist
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..6 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Create normalize_email function if it doesn't exist
CREATE OR REPLACE FUNCTION public.normalize_email(email_input TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN LOWER(TRIM(email_input));
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Ensure all required tables exist with proper structure
-- =============================================================================

-- Ensure users table has all required columns
DO $$
BEGIN
    -- Add missing columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'address') THEN
        ALTER TABLE public.users ADD COLUMN address TEXT DEFAULT '';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'username') THEN
        ALTER TABLE public.users ADD COLUMN username TEXT DEFAULT '';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'profile_completed') THEN
        ALTER TABLE public.users ADD COLUMN profile_completed BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'registration_date') THEN
        ALTER TABLE public.users ADD COLUMN registration_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'used_referral_code') THEN
        ALTER TABLE public.users ADD COLUMN used_referral_code TEXT;
    END IF;
END $$;

-- Ensure balances table has investment_balance column
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'balances' AND column_name = 'investment_balance') THEN
        ALTER TABLE public.balances ADD COLUMN investment_balance NUMERIC(15,2) DEFAULT 0.00;
    END IF;
END $$;

-- Create user_directory table if it doesn't exist
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

-- Create simple_transfers_users table if it doesn't exist
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

-- =============================================================================
-- Create all required indexes
-- =============================================================================

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
CREATE INDEX IF NOT EXISTS idx_simple_transfers_sender_email ON public.simple_transfers(sender_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_recipient_email ON public.simple_transfers(recipient_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_reference ON public.simple_transfers(reference_number);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_created_at ON public.simple_transfers(created_at);

-- =============================================================================
-- Sync existing users to directory tables
-- =============================================================================

-- Sync all existing users to user_directory
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
    SELECT 1 FROM public.user_directory ud WHERE ud.user_id = u.id
);

-- Sync all existing users to simple_transfers_users
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
    SELECT 1 FROM public.simple_transfers_users stu WHERE stu.user_id = u.id
);

-- =============================================================================
-- Ensure all existing users have referral codes
-- =============================================================================

UPDATE public.users 
SET referral_code = public.generate_referral_code()
WHERE referral_code IS NULL OR referral_code = '';

-- =============================================================================
-- Verify database integrity
-- =============================================================================

-- Check that all users have balances
INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, investment_balance, created_at, updated_at)
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
    SELECT 1 FROM public.balances b WHERE b.user_id = u.id
);

-- Final validation
DO $$
DECLARE
    user_count INTEGER;
    balance_count INTEGER;
    directory_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM public.users;
    SELECT COUNT(*) INTO balance_count FROM public.balances;
    SELECT COUNT(*) INTO directory_count FROM public.user_directory;
    
    RAISE NOTICE 'Database validation complete:';
    RAISE NOTICE '- Users: %', user_count;
    RAISE NOTICE '- Balances: %', balance_count;
    RAISE NOTICE '- Directory entries: %', directory_count;
    
    IF user_count != balance_count THEN
        RAISE WARNING 'Mismatch between users and balances!';
    END IF;
END $$;
