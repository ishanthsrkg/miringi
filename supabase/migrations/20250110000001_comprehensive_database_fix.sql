-- Comprehensive Database Fix
-- This migration fixes all identified issues in the database schema

-- =============================================================================
-- Fix missing columns in existing tables
-- =============================================================================

-- Add missing columns to users table
DO $users_columns_block$
BEGIN
    -- Add address column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'address') THEN
        ALTER TABLE public.users ADD COLUMN address TEXT DEFAULT '';
    END IF;
    
    -- Add username column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'username') THEN
        ALTER TABLE public.users ADD COLUMN username TEXT DEFAULT '';
    END IF;
    
    -- Add profile_completed column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'profile_completed') THEN
        ALTER TABLE public.users ADD COLUMN profile_completed BOOLEAN DEFAULT false;
    END IF;
    
    -- Add registration_date column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'registration_date') THEN
        ALTER TABLE public.users ADD COLUMN registration_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());
    END IF;
    
    -- Add verification columns if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'is_verified') THEN
        ALTER TABLE public.users ADD COLUMN is_verified BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'verification_status') THEN
        ALTER TABLE public.users ADD COLUMN verification_status TEXT DEFAULT 'unverified' CHECK (verification_status IN ('unverified', 'pending', 'approved', 'rejected'));
    END IF;
END $users_columns_block$;

-- Add investment_balance to balances table if missing
DO $balances_columns_block$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'balances' AND column_name = 'investment_balance') THEN
        ALTER TABLE public.balances ADD COLUMN investment_balance NUMERIC(15,2) DEFAULT 0.00;
    END IF;
END $balances_columns_block$;

-- Add missing columns to cards table
DO $cards_columns_block$
BEGIN
    -- Add balance column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cards' AND column_name = 'balance') THEN
        ALTER TABLE public.cards ADD COLUMN balance NUMERIC(15,2) DEFAULT 0.00;
    END IF;
    
    -- Add currency column if missing
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cards' AND column_name = 'currency') THEN
        ALTER TABLE public.cards ADD COLUMN currency TEXT DEFAULT 'dzd' CHECK (currency IN ('dzd', 'eur', 'usd', 'gbp'));
    END IF;
END $cards_columns_block$;

-- =============================================================================
-- Create missing tables
-- =============================================================================

-- Create user_credentials table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_credentials (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

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
    last_activity TIMESTAMP WITH TIME ZONE,
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
    sender_email TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    sender_name TEXT,
    recipient_name TEXT,
    sender_account_number TEXT,
    recipient_account_number TEXT,
    amount NUMERIC(15,2) NOT NULL,
    description TEXT,
    reference_number TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'completed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Create support_messages table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    category TEXT DEFAULT 'general',
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    admin_response TEXT,
    admin_id UUID,
    responded_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Create account_verifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.account_verifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    country TEXT NOT NULL,
    date_of_birth DATE NOT NULL,
    full_address TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    document_type TEXT NOT NULL CHECK (document_type IN ('passport', 'national_id', 'driving_license')),
    document_number TEXT NOT NULL,
    documents JSONB,
    additional_notes TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewed_by UUID,
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Create transfer_limits table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.transfer_limits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    daily_limit NUMERIC(15,2) DEFAULT 50000.00,
    daily_used NUMERIC(15,2) DEFAULT 0.00,
    monthly_limit NUMERIC(15,2) DEFAULT 1000000.00,
    monthly_used NUMERIC(15,2) DEFAULT 0.00,
    single_transfer_limit NUMERIC(15,2) DEFAULT 25000.00,
    last_reset_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Create instant_transfer_limits table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.instant_transfer_limits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    daily_limit NUMERIC(15,2) DEFAULT 100000.00,
    daily_used NUMERIC(15,2) DEFAULT 0.00,
    monthly_limit NUMERIC(15,2) DEFAULT 2000000.00,
    monthly_used NUMERIC(15,2) DEFAULT 0.00,
    single_transfer_limit NUMERIC(15,2) DEFAULT 50000.00,
    is_verified_user BOOLEAN DEFAULT false,
    verification_level INTEGER DEFAULT 1,
    last_daily_reset DATE DEFAULT CURRENT_DATE,
    last_monthly_reset DATE DEFAULT DATE_TRUNC('month', CURRENT_DATE),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Create referrals table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    referred_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    referral_code TEXT NOT NULL,
    reward_amount NUMERIC(15,2) DEFAULT 0.00,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- =============================================================================
-- Create all required indexes
-- =============================================================================

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_account_number ON public.users(account_number);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON public.users(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users(username);
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON public.users(verification_status);

-- Balances table indexes
CREATE INDEX IF NOT EXISTS idx_balances_user_id ON public.balances(user_id);

-- User credentials indexes
CREATE INDEX IF NOT EXISTS idx_user_credentials_user_id ON public.user_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_user_credentials_username ON public.user_credentials(username);

-- User directory indexes
CREATE INDEX IF NOT EXISTS idx_user_directory_email_normalized ON public.user_directory(email_normalized);
CREATE INDEX IF NOT EXISTS idx_user_directory_email ON public.user_directory(email);
CREATE INDEX IF NOT EXISTS idx_user_directory_account_number ON public.user_directory(account_number);
CREATE INDEX IF NOT EXISTS idx_user_directory_user_id ON public.user_directory(user_id);

-- Simple transfers users indexes
CREATE INDEX IF NOT EXISTS idx_simple_transfers_users_email_normalized ON public.simple_transfers_users(email_normalized);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_users_email ON public.simple_transfers_users(email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_users_account_number ON public.simple_transfers_users(account_number);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_users_user_id ON public.simple_transfers_users(user_id);

-- Simple transfers indexes
CREATE INDEX IF NOT EXISTS idx_simple_transfers_sender_email ON public.simple_transfers(sender_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_recipient_email ON public.simple_transfers(recipient_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_reference ON public.simple_transfers(reference_number);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_created_at ON public.simple_transfers(created_at);

-- Support messages indexes
CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON public.support_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_status ON public.support_messages(status);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON public.support_messages(created_at);

-- Account verifications indexes
CREATE INDEX IF NOT EXISTS idx_account_verifications_user_id ON public.account_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_account_verifications_status ON public.account_verifications(status);
CREATE INDEX IF NOT EXISTS idx_account_verifications_submitted_at ON public.account_verifications(submitted_at);

-- Transfer limits indexes
CREATE INDEX IF NOT EXISTS idx_transfer_limits_user_id ON public.transfer_limits(user_id);
CREATE INDEX IF NOT EXISTS idx_instant_transfer_limits_user_id ON public.instant_transfer_limits(user_id);

-- =============================================================================
-- Fix generate_referral_code function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result TEXT := '';
    i INTEGER;
    code_exists BOOLEAN;
BEGIN
    LOOP
        result := '';
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
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create normalize_email function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.normalize_email(email_input TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN LOWER(TRIM(email_input));
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create generate_simple_reference function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_simple_reference()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result TEXT := 'TXN';
    i INTEGER;
    ref_exists BOOLEAN;
BEGIN
    LOOP
        result := 'TXN';
        FOR i IN 1..8 LOOP
            result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
        END LOOP;
        
        -- Check if reference already exists
        SELECT EXISTS(SELECT 1 FROM public.simple_transfers WHERE reference_number = result) INTO ref_exists;
        
        -- If reference doesn't exist, return it
        IF NOT ref_exists THEN
            RETURN result;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create find_user_simple function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.find_user_simple(p_identifier TEXT)
RETURNS TABLE(
    user_email TEXT,
    user_name TEXT,
    account_number TEXT,
    balance NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.email::TEXT,
        u.full_name::TEXT,
        u.account_number::TEXT,
        COALESCE(b.dzd, 0)::NUMERIC
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE 
        u.email = p_identifier 
        OR u.account_number = p_identifier
        OR LOWER(u.email) = LOWER(p_identifier)
    AND u.is_active = true
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create process_simple_transfer function
-- =============================================================================

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
    v_sender_id UUID;
    v_recipient_id UUID;
    v_sender_balance NUMERIC;
    v_recipient_info RECORD;
    v_reference TEXT;
BEGIN
    -- Find sender
    SELECT id, full_name INTO v_sender_id FROM public.users 
    WHERE email = p_sender_email AND is_active = true;
    
    IF v_sender_id IS NULL THEN
        RETURN QUERY SELECT false, 'المرسل غير موجود'::TEXT, ''::TEXT, 0::NUMERIC;
        RETURN;
    END IF;
    
    -- Get sender balance
    SELECT dzd INTO v_sender_balance FROM public.balances WHERE user_id = v_sender_id;
    
    IF v_sender_balance IS NULL OR v_sender_balance < p_amount THEN
        RETURN QUERY SELECT false, 'الرصيد غير كافي'::TEXT, ''::TEXT, COALESCE(v_sender_balance, 0)::NUMERIC;
        RETURN;
    END IF;
    
    -- Find recipient
    SELECT u.id, u.full_name, u.email, u.account_number 
    INTO v_recipient_info
    FROM public.users u
    WHERE (u.email = p_recipient_identifier OR u.account_number = p_recipient_identifier)
    AND u.is_active = true
    AND u.id != v_sender_id;
    
    IF v_recipient_info.id IS NULL THEN
        RETURN QUERY SELECT false, 'المستلم غير موجود'::TEXT, ''::TEXT, v_sender_balance::NUMERIC;
        RETURN;
    END IF;
    
    -- Generate reference
    v_reference := public.generate_simple_reference();
    
    -- Update sender balance
    UPDATE public.balances 
    SET dzd = dzd - p_amount, updated_at = timezone('utc'::text, now())
    WHERE user_id = v_sender_id;
    
    -- Update recipient balance
    UPDATE public.balances 
    SET dzd = dzd + p_amount, updated_at = timezone('utc'::text, now())
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
    SELECT dzd INTO v_sender_balance FROM public.balances WHERE user_id = v_sender_id;
    
    RETURN QUERY SELECT true, 'تم التحويل بنجاح'::TEXT, v_reference, v_sender_balance;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create update_user_balance function
-- =============================================================================

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
DECLARE
    v_update_query TEXT := 'UPDATE public.balances SET updated_at = timezone(''utc''::text, now())';
    v_where_clause TEXT := ' WHERE user_id = $1';
BEGIN
    -- Build dynamic update query
    IF p_dzd IS NOT NULL THEN
        v_update_query := v_update_query || ', dzd = ' || p_dzd;
    END IF;
    
    IF p_eur IS NOT NULL THEN
        v_update_query := v_update_query || ', eur = ' || p_eur;
    END IF;
    
    IF p_usd IS NOT NULL THEN
        v_update_query := v_update_query || ', usd = ' || p_usd;
    END IF;
    
    IF p_gbp IS NOT NULL THEN
        v_update_query := v_update_query || ', gbp = ' || p_gbp;
    END IF;
    
    IF p_investment_balance IS NOT NULL THEN
        v_update_query := v_update_query || ', investment_balance = ' || p_investment_balance;
    END IF;
    
    -- Execute the update
    EXECUTE v_update_query || v_where_clause USING p_user_id;
    
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
-- Create process_investment function
-- =============================================================================

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
DECLARE
    v_current_dzd NUMERIC;
    v_current_investment NUMERIC;
BEGIN
    -- Get current balances
    SELECT dzd, investment_balance 
    INTO v_current_dzd, v_current_investment
    FROM public.balances 
    WHERE user_id = p_user_id;
    
    IF v_current_dzd IS NULL THEN
        RETURN QUERY SELECT false, 'المستخدم غير موجود'::TEXT, 0::NUMERIC, 0::NUMERIC;
        RETURN;
    END IF;
    
    -- Process investment operation
    IF p_operation = 'invest' THEN
        -- Check if user has enough DZD balance
        IF v_current_dzd < p_amount THEN
            RETURN QUERY SELECT false, 'الرصيد غير كافي للاستثمار'::TEXT, v_current_dzd, v_current_investment;
            RETURN;
        END IF;
        
        -- Transfer from DZD to investment
        UPDATE public.balances 
        SET 
            dzd = dzd - p_amount,
            investment_balance = investment_balance + p_amount,
            updated_at = timezone('utc'::text, now())
        WHERE user_id = p_user_id;
        
        v_current_dzd := v_current_dzd - p_amount;
        v_current_investment := v_current_investment + p_amount;
        
        RETURN QUERY SELECT true, 'تم الاستثمار بنجاح'::TEXT, v_current_dzd, v_current_investment;
        
    ELSIF p_operation = 'return' THEN
        -- Check if user has enough investment balance
        IF v_current_investment < p_amount THEN
            RETURN QUERY SELECT false, 'رصيد الاستثمار غير كافي'::TEXT, v_current_dzd, v_current_investment;
            RETURN;
        END IF;
        
        -- Transfer from investment to DZD
        UPDATE public.balances 
        SET 
            dzd = dzd + p_amount,
            investment_balance = investment_balance - p_amount,
            updated_at = timezone('utc'::text, now())
        WHERE user_id = p_user_id;
        
        v_current_dzd := v_current_dzd + p_amount;
        v_current_investment := v_current_investment - p_amount;
        
        RETURN QUERY SELECT true, 'تم سحب الاستثمار بنجاح'::TEXT, v_current_dzd, v_current_investment;
        
    ELSE
        RETURN QUERY SELECT false, 'عملية غير صحيحة'::TEXT, v_current_dzd, v_current_investment;
    END IF;
END;
$$ LANGUAGE plpgsql;

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
)
ON CONFLICT (user_id) DO NOTHING;

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
)
ON CONFLICT (user_id) DO NOTHING;

-- =============================================================================
-- Ensure all existing users have referral codes
-- =============================================================================

UPDATE public.users 
SET referral_code = public.generate_referral_code()
WHERE referral_code IS NULL OR referral_code = '';

-- =============================================================================
-- Ensure all users have balances
-- =============================================================================

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

-- =============================================================================
-- Enable RLS on new tables
-- =============================================================================

ALTER TABLE public.user_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_directory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.simple_transfers_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.simple_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfer_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instant_transfer_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- Create RLS policies for new tables
-- =============================================================================

-- User credentials policies
DROP POLICY IF EXISTS "Users can view own credentials" ON public.user_credentials;
CREATE POLICY "Users can view own credentials" ON public.user_credentials
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own credentials" ON public.user_credentials;
CREATE POLICY "Users can update own credentials" ON public.user_credentials
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own credentials" ON public.user_credentials;
CREATE POLICY "Users can insert own credentials" ON public.user_credentials
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Support messages policies
DROP POLICY IF EXISTS "Users can view own support messages" ON public.support_messages;
CREATE POLICY "Users can view own support messages" ON public.support_messages
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own support messages" ON public.support_messages;
CREATE POLICY "Users can insert own support messages" ON public.support_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Account verifications policies
DROP POLICY IF EXISTS "Users can view own verifications" ON public.account_verifications;
CREATE POLICY "Users can view own verifications" ON public.account_verifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own verifications" ON public.account_verifications;
CREATE POLICY "Users can insert own verifications" ON public.account_verifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Transfer limits policies
DROP POLICY IF EXISTS "Users can view own transfer limits" ON public.transfer_limits;
CREATE POLICY "Users can view own transfer limits" ON public.transfer_limits
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own instant transfer limits" ON public.instant_transfer_limits;
CREATE POLICY "Users can view own instant transfer limits" ON public.instant_transfer_limits
    FOR SELECT USING (auth.uid() = user_id);

-- Public read access for directory tables (needed for transfers)
DROP POLICY IF EXISTS "Public read access for user directory" ON public.user_directory;
CREATE POLICY "Public read access for user directory" ON public.user_directory
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public read access for simple transfers users" ON public.simple_transfers_users;
CREATE POLICY "Public read access for simple transfers users" ON public.simple_transfers_users
    FOR SELECT USING (true);

-- Simple transfers policies
DROP POLICY IF EXISTS "Users can view related transfers" ON public.simple_transfers;
CREATE POLICY "Users can view related transfers" ON public.simple_transfers
    FOR SELECT USING (
        sender_email = (SELECT email FROM public.users WHERE id = auth.uid()) OR
        recipient_email = (SELECT email FROM public.users WHERE id = auth.uid())
    );

-- =============================================================================
-- Enable realtime for new tables
-- =============================================================================

-- Add tables to realtime publication only if not already added
DO $realtime_block$
BEGIN
    -- Check and add user_credentials
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'user_credentials'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_credentials;
    END IF;
    
    -- Check and add user_directory
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'user_directory'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_directory;
    END IF;
    
    -- Check and add simple_transfers_users
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'simple_transfers_users'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.simple_transfers_users;
    END IF;
    
    -- Check and add simple_transfers
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'simple_transfers'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.simple_transfers;
    END IF;
    
    -- Check and add support_messages
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'support_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
    END IF;
    
    -- Check and add account_verifications
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'account_verifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.account_verifications;
    END IF;
    
    -- Check and add transfer_limits
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'transfer_limits'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.transfer_limits;
    END IF;
    
    -- Check and add instant_transfer_limits
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'instant_transfer_limits'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.instant_transfer_limits;
    END IF;
    
    -- Check and add referrals
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'referrals'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.referrals;
    END IF;
END $realtime_block$;

-- =============================================================================
-- Create or replace the handle_new_user function with comprehensive error handling
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $
DECLARE
    new_referral_code TEXT;
    referrer_user_id UUID;
    new_account_number TEXT;
    user_full_name TEXT;
    user_phone TEXT;
    user_username TEXT;
    user_address TEXT;
    user_referral_code TEXT;
BEGIN
    -- Log the trigger execution
    RAISE NOTICE 'handle_new_user trigger started for user: %', NEW.id;
    
    -- Extract and validate user metadata with safe defaults
    user_full_name := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''), 'مستخدم جديد');
    user_phone := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), ''), '');
    user_username := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'username'), ''), '');
    user_address := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'address'), ''), '');
    user_referral_code := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'used_referral_code'), ''), '');
    
    -- Generate unique referral code with retry logic
    BEGIN
        new_referral_code := public.generate_referral_code();
        IF new_referral_code IS NULL OR LENGTH(new_referral_code) < 6 THEN
            new_referral_code := 'REF' || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Fallback referral code generation
        new_referral_code := 'REF' || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        RAISE WARNING 'Failed to generate referral code, using fallback: %', new_referral_code;
    END;
    
    -- Generate unique account number with retry logic
    BEGIN
        new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
        -- Ensure uniqueness
        WHILE EXISTS (SELECT 1 FROM public.users WHERE account_number = new_account_number) LOOP
            new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
        RAISE WARNING 'Failed to generate unique account number, using: %', new_account_number;
    END;
    
    -- Insert user profile with comprehensive data and error handling
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
        
        RAISE NOTICE 'User profile created successfully for: %', NEW.id;
    EXCEPTION WHEN unique_violation THEN
        RAISE WARNING 'User profile already exists for: %', NEW.id;
        -- Continue with other operations
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create user profile for %: %', NEW.id, SQLERRM;
        -- Don't fail the entire process, continue with other operations
    END;
    
    -- Create initial balance record
    BEGIN
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, investment_balance, created_at, updated_at)
        VALUES (NEW.id, 20000.00, 100.00, 110.00, 85.00, 1000.00, timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        RAISE NOTICE 'Balance created successfully for user: %', NEW.id;
    EXCEPTION WHEN unique_violation THEN
        RAISE WARNING 'Balance already exists for user: %', NEW.id;
        -- Continue with other operations
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create user balance for %: %', NEW.id, SQLERRM;
        -- Don't fail the entire process, continue with other operations
    END;
    
    -- Create user credentials entry
    BEGIN
        INSERT INTO public.user_credentials (user_id, username, password_hash, created_at, updated_at)
        VALUES (
            NEW.id, 
            COALESCE(NULLIF(user_username, ''), 'user_' || SUBSTRING(NEW.id::text, 1, 8)),
            '[HASHED]',
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        );
        
        RAISE NOTICE 'User credentials created successfully for: %', NEW.id;
    EXCEPTION WHEN unique_violation THEN
        RAISE WARNING 'User credentials already exist for: %', NEW.id;
    EXCEPTION WHEN OTHERS THEN
        -- Log error but don't fail the entire process
        RAISE WARNING 'Failed to create user credentials for %: %', NEW.id, SQLERRM;
    END;
    
    -- Sync to directory tables
    BEGIN
        -- Insert into user_directory
        INSERT INTO public.user_directory (
            user_id, email, email_normalized, full_name, account_number, phone, 
            can_receive_transfers, is_active, created_at, updated_at
        )
        VALUES (
            NEW.id, NEW.email, LOWER(TRIM(NEW.email)), 
            user_full_name,
            new_account_number, user_phone,
            true, true, timezone('utc'::text, now()), timezone('utc'::text, now())
        );
        
        RAISE NOTICE 'User directory entry created for: %', NEW.id;
    EXCEPTION WHEN unique_violation THEN
        RAISE WARNING 'User directory entry already exists for: %', NEW.id;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create user directory entry for %: %', NEW.id, SQLERRM;
    END;
    
    BEGIN
        -- Insert into simple_transfers_users
        INSERT INTO public.simple_transfers_users (
            user_id, email, email_normalized, full_name, account_number, phone,
            can_receive_transfers, is_active, created_at, updated_at
        )
        VALUES (
            NEW.id, NEW.email, LOWER(TRIM(NEW.email)),
            user_full_name,
            new_account_number, user_phone,
            true, true, timezone('utc'::text, now()), timezone('utc'::text, now())
        );
        
        RAISE NOTICE 'Simple transfers user entry created for: %', NEW.id;
    EXCEPTION WHEN unique_violation THEN
        RAISE WARNING 'Simple transfers user entry already exists for: %', NEW.id;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create simple transfers user entry for %: %', NEW.id, SQLERRM;
    END;
    
    -- Create transfer limits
    BEGIN
        INSERT INTO public.transfer_limits (user_id, created_at, updated_at)
        VALUES (NEW.id, timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        RAISE NOTICE 'Transfer limits created for: %', NEW.id;
    EXCEPTION WHEN unique_violation THEN
        RAISE WARNING 'Transfer limits already exist for: %', NEW.id;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create transfer limits for %: %', NEW.id, SQLERRM;
    END;
    
    BEGIN
        INSERT INTO public.instant_transfer_limits (user_id, created_at, updated_at)
        VALUES (NEW.id, timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        RAISE NOTICE 'Instant transfer limits created for: %', NEW.id;
    EXCEPTION WHEN unique_violation THEN
        RAISE WARNING 'Instant transfer limits already exist for: %', NEW.id;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Failed to create instant transfer limits for %: %', NEW.id, SQLERRM;
    END;
    
    -- Handle referral reward if user used a referral code
    IF user_referral_code IS NOT NULL AND user_referral_code != '' THEN
        BEGIN
            -- Find the referrer
            SELECT id INTO referrer_user_id 
            FROM public.users 
            WHERE referral_code = UPPER(user_referral_code)
            AND id != NEW.id; -- Ensure user can't refer themselves
            
            -- If referrer found, create referral record and add reward
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
                    UPPER(user_referral_code),
                    500.00,
                    'completed',
                    timezone('utc'::text, now())
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
                
                RAISE NOTICE 'Referral reward processed for referrer: % by new user: %', referrer_user_id, NEW.id;
                
                -- Create notification for referrer (if notifications table exists)
                BEGIN
                    INSERT INTO public.notifications (
                        user_id,
                        type,
                        title,
                        message,
                        created_at
                    )
                    VALUES (
                        referrer_user_id,
                        'success',
                        'مكافأة إحالة جديدة',
                        'تم إضافة 500 دج إلى رصيدك بسبب إحالة مستخدم جديد',
                        timezone('utc'::text, now())
                    );
                EXCEPTION WHEN OTHERS THEN
                    -- Notifications table might not exist, continue without error
                    RAISE WARNING 'Failed to create referral notification: %', SQLERRM;
                END;
            ELSE
                RAISE WARNING 'Invalid referral code used: %', user_referral_code;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to process referral reward for %: %', NEW.id, SQLERRM;
        END;
    END IF;
    
    RAISE NOTICE 'handle_new_user trigger completed successfully for user: %', NEW.id;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Critical error in handle_new_user for %: %', NEW.id, SQLERRM;
    -- Return NEW to allow the auth user creation to succeed even if some operations fail
    RETURN NEW;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger for new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- Final validation
-- =============================================================================

DO $validation_block$
DECLARE
    user_count INTEGER;
    balance_count INTEGER;
    directory_count INTEGER;
    transfers_users_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM public.users;
    SELECT COUNT(*) INTO balance_count FROM public.balances;
    SELECT COUNT(*) INTO directory_count FROM public.user_directory;
    SELECT COUNT(*) INTO transfers_users_count FROM public.simple_transfers_users;
    
    RAISE NOTICE 'Database comprehensive fix completed:';
    RAISE NOTICE '- Users: %', user_count;
    RAISE NOTICE '- Balances: %', balance_count;
    RAISE NOTICE '- Directory entries: %', directory_count;
    RAISE NOTICE '- Transfer users: %', transfers_users_count;
    
    IF user_count != balance_count THEN
        RAISE WARNING 'Mismatch between users and balances!';
    END IF;
    
    IF user_count != directory_count THEN
        RAISE WARNING 'Mismatch between users and directory entries!';
    END IF;
END $validation_block$;