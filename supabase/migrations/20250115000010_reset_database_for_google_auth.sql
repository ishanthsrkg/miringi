-- =============================================================================
-- SIMPLE DATABASE SCHEMA FOR GOOGLE AUTHENTICATION
-- =============================================================================
-- This script creates a minimal, simple database schema for Google OAuth
-- with automatic user creation and basic balance management
-- =============================================================================

-- =============================================================================
-- DROP ALL EXISTING OBJECTS
-- =============================================================================

-- Drop all existing tables
DROP TABLE IF EXISTS public.email_verification_logs CASCADE;
DROP TABLE IF EXISTS public.email_verification_tokens CASCADE;
DROP TABLE IF EXISTS public.otp_logs CASCADE;
DROP TABLE IF EXISTS public.otps CASCADE;
DROP TABLE IF EXISTS public.account_verifications CASCADE;
DROP TABLE IF EXISTS public.support_messages CASCADE;
DROP TABLE IF EXISTS public.referrals CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.cards CASCADE;
DROP TABLE IF EXISTS public.savings_goals CASCADE;
DROP TABLE IF EXISTS public.investments CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.balances CASCADE;
DROP TABLE IF EXISTS public.user_credentials CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Drop all existing functions
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS public.generate_referral_code() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.handle_google_user() CASCADE;
DROP FUNCTION IF EXISTS public.update_user_last_login() CASCADE;
DROP FUNCTION IF EXISTS public.get_user_profile_with_balance(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_balance_safe(UUID, DECIMAL, DECIMAL, DECIMAL, DECIMAL) CASCADE;

-- Drop all existing triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP TRIGGER IF EXISTS on_google_user_created ON auth.users CASCADE;
DROP TRIGGER IF EXISTS on_user_login_update ON auth.users CASCADE;
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users CASCADE;
DROP TRIGGER IF EXISTS update_balances_updated_at ON public.balances CASCADE;

-- =============================================================================
-- CREATE SIMPLE TABLES
-- =============================================================================

-- Users table - simple profile for Google users
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT NOT NULL,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Balances table - simple multi-currency balance
CREATE TABLE public.balances (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    dzd DECIMAL(15,2) DEFAULT 15000.00,
    eur DECIMAL(15,2) DEFAULT 75.00,
    usd DECIMAL(15,2) DEFAULT 85.00,
    gbp DECIMAL(15,2) DEFAULT 65.50,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Transactions table - simple transaction history
CREATE TABLE public.transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('transfer', 'payment', 'recharge', 'exchange')),
    amount DECIMAL(15,2) NOT NULL,
    currency TEXT NOT NULL CHECK (currency IN ('DZD', 'EUR', 'USD', 'GBP')),
    description TEXT,
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- User settings table - simple user preferences
CREATE TABLE public.user_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    preferred_currency TEXT DEFAULT 'DZD' CHECK (preferred_currency IN ('DZD', 'EUR', 'USD', 'GBP')),
    notifications_enabled BOOLEAN DEFAULT true,
    language TEXT DEFAULT 'ar' CHECK (language IN ('ar', 'en', 'fr')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- =============================================================================
-- SIMPLE FUNCTIONS
-- =============================================================================

-- Function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle new Google users
CREATE OR REPLACE FUNCTION public.handle_new_google_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process Google OAuth users
    IF NEW.app_metadata->>'provider' = 'google' THEN
        -- Insert user profile
        INSERT INTO public.users (id, email, full_name, avatar_url)
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Google User'),
            NEW.raw_user_meta_data->>'avatar_url'
        )
        ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            full_name = EXCLUDED.full_name,
            avatar_url = EXCLUDED.avatar_url,
            updated_at = now();
        
        -- Create balance record
        INSERT INTO public.balances (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
        
        -- Create user settings record
        INSERT INTO public.user_settings (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SIMPLE TRIGGERS
-- =============================================================================

-- Trigger for updating timestamps
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_balances_updated_at
    BEFORE UPDATE ON public.balances
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_settings_updated_at
    BEFORE UPDATE ON public.user_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger for new Google users
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_google_user();

-- =============================================================================
-- SIMPLE RLS POLICIES
-- =============================================================================

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- Simple policies for users table
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Simple policies for balances table
CREATE POLICY "Users can view own balance" ON public.balances
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own balance" ON public.balances
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own balance" ON public.balances
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Simple policies for transactions table
CREATE POLICY "Users can view own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions" ON public.transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Simple policies for user_settings table
CREATE POLICY "Users can view own settings" ON public.user_settings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own settings" ON public.user_settings
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings" ON public.user_settings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- ENABLE REALTIME
-- =============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.balances;
ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_settings;

-- =============================================================================
-- SIMPLE HELPER FUNCTIONS
-- =============================================================================

-- Function to get user with balance
CREATE OR REPLACE FUNCTION public.get_user_with_balance(p_user_id UUID)
RETURNS TABLE(
    id UUID,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    dzd DECIMAL(15,2),
    eur DECIMAL(15,2),
    usd DECIMAL(15,2),
    gbp DECIMAL(15,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.full_name,
        u.avatar_url,
        COALESCE(b.dzd, 15000.00) as dzd,
        COALESCE(b.eur, 75.00) as eur,
        COALESCE(b.usd, 85.00) as usd,
        COALESCE(b.gbp, 65.50) as gbp
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE u.id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update balance
CREATE OR REPLACE FUNCTION public.update_balance(
    p_user_id UUID,
    p_dzd DECIMAL(15,2) DEFAULT NULL,
    p_eur DECIMAL(15,2) DEFAULT NULL,
    p_usd DECIMAL(15,2) DEFAULT NULL,
    p_gbp DECIMAL(15,2) DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    dzd DECIMAL(15,2),
    eur DECIMAL(15,2),
    usd DECIMAL(15,2),
    gbp DECIMAL(15,2)
) AS $$
DECLARE
    current_balance RECORD;
BEGIN
    -- Get or create balance record
    INSERT INTO public.balances (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Update balance
    UPDATE public.balances 
    SET 
        dzd = COALESCE(p_dzd, dzd),
        eur = COALESCE(p_eur, eur),
        usd = COALESCE(p_usd, usd),
        gbp = COALESCE(p_gbp, gbp),
        updated_at = now()
    WHERE user_id = p_user_id;
    
    -- Return updated balance
    SELECT * INTO current_balance FROM public.balances WHERE user_id = p_user_id;
    
    RETURN QUERY SELECT 
        true as success,
        current_balance.dzd,
        current_balance.eur,
        current_balance.usd,
        current_balance.gbp;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create transaction
CREATE OR REPLACE FUNCTION public.create_transaction(
    p_user_id UUID,
    p_type TEXT,
    p_amount DECIMAL(15,2),
    p_currency TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS UUID AS $
DECLARE
    transaction_id UUID;
BEGIN
    INSERT INTO public.transactions (user_id, type, amount, currency, description)
    VALUES (p_user_id, p_type, p_amount, p_currency, p_description)
    RETURNING id INTO transaction_id;
    
    RETURN transaction_id;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user settings
CREATE OR REPLACE FUNCTION public.get_user_settings(p_user_id UUID)
RETURNS TABLE(
    preferred_currency TEXT,
    notifications_enabled BOOLEAN,
    language TEXT
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(s.preferred_currency, 'DZD') as preferred_currency,
        COALESCE(s.notifications_enabled, true) as notifications_enabled,
        COALESCE(s.language, 'ar') as language
    FROM public.user_settings s
    WHERE s.user_id = p_user_id;
    
    -- If no settings found, return defaults
    IF NOT FOUND THEN
        RETURN QUERY SELECT 'DZD'::TEXT, true::BOOLEAN, 'ar'::TEXT;
    END IF;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SCRIPT COMPLETION
-- =============================================================================
-- Simple database schema created successfully!
-- Google OAuth users will be automatically created with default balances.
-- Users can view and update their own data only.
-- =============================================================================
