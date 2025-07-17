-- =============================================================================
-- DATABASE SETUP SCRIPT FOR FINANCIAL APPLICATION
-- =============================================================================
-- This script creates all necessary tables, indexes, triggers, and policies
-- for a complete financial management system with Supabase authentication
-- =============================================================================

-- =============================================================================
-- TABLES CREATION
-- =============================================================================

-- Users table - extends auth.users with profile information
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT,
    account_number TEXT UNIQUE NOT NULL,
    join_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    location TEXT,
    language TEXT DEFAULT 'ar',
    currency TEXT DEFAULT 'dzd',
    profile_image TEXT,
    is_active BOOLEAN DEFAULT true,
    referral_code TEXT UNIQUE,
    used_referral_code TEXT,
    referral_earnings DECIMAL(15,2) DEFAULT 0.00 NOT NULL
);

-- Balances table - stores multi-currency balances for each user
CREATE TABLE IF NOT EXISTS public.balances (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    dzd DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    eur DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    usd DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    gbp DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Transactions table - records all financial transactions
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('recharge', 'transfer', 'bill', 'investment', 'conversion', 'withdrawal')),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    currency TEXT DEFAULT 'dzd' CHECK (currency IN ('dzd', 'eur', 'usd', 'gbp')),
    description TEXT NOT NULL,
    reference TEXT,
    recipient TEXT,
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Investments table - tracks investment products
CREATE TABLE IF NOT EXISTS public.investments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('weekly', 'monthly', 'quarterly', 'yearly')),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    profit_rate DECIMAL(5,2) NOT NULL CHECK (profit_rate >= 0 AND profit_rate <= 100),
    profit DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT valid_investment_dates CHECK (end_date > start_date)
);

-- Savings goals table - user-defined savings targets
CREATE TABLE IF NOT EXISTS public.savings_goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    target_amount DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (current_amount >= 0),
    deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    category TEXT NOT NULL,
    icon TEXT NOT NULL,
    color TEXT NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT valid_savings_amounts CHECK (current_amount <= target_amount)
);

-- Cards table - physical and virtual payment cards
CREATE TABLE IF NOT EXISTS public.cards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    card_number TEXT NOT NULL,
    card_type TEXT NOT NULL CHECK (card_type IN ('solid', 'virtual')),
    is_frozen BOOLEAN DEFAULT false NOT NULL,
    spending_limit DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (spending_limit >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Notifications table - system and user notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('success', 'error', 'info', 'warning')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Referrals table - user referral system
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    referred_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    referral_code TEXT NOT NULL UNIQUE,
    reward_amount DECIMAL(15,2) DEFAULT 500.00 NOT NULL CHECK (reward_amount >= 0),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT no_self_referral CHECK (referrer_id != referred_id)
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- =============================================================================

-- User-related indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_account_number ON public.users(account_number);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users(is_active);

-- Balance indexes
CREATE INDEX IF NOT EXISTS idx_balances_user_id ON public.balances(user_id);

-- Transaction indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON public.transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON public.transactions(user_id, created_at DESC);

-- Investment indexes
CREATE INDEX IF NOT EXISTS idx_investments_user_id ON public.investments(user_id);
CREATE INDEX IF NOT EXISTS idx_investments_status ON public.investments(status);
CREATE INDEX IF NOT EXISTS idx_investments_end_date ON public.investments(end_date);

-- Savings goal indexes
CREATE INDEX IF NOT EXISTS idx_savings_goals_user_id ON public.savings_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_savings_goals_status ON public.savings_goals(status);
CREATE INDEX IF NOT EXISTS idx_savings_goals_deadline ON public.savings_goals(deadline);

-- Card indexes
CREATE INDEX IF NOT EXISTS idx_cards_user_id ON public.cards(user_id);
CREATE INDEX IF NOT EXISTS idx_cards_card_number ON public.cards(card_number);

-- Notification indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = false;

-- Referral indexes
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON public.referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);

-- =============================================================================
-- FUNCTIONS AND TRIGGERS
-- =============================================================================

-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic updated_at timestamps
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_balances_updated_at 
    BEFORE UPDATE ON public.balances
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at 
    BEFORE UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_investments_updated_at 
    BEFORE UPDATE ON public.investments
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_savings_goals_updated_at 
    BEFORE UPDATE ON public.savings_goals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_cards_updated_at 
    BEFORE UPDATE ON public.cards
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT AS $
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a random 8-character code with letters and numbers
        code := upper(substring(md5(random()::text) from 1 for 8));
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM public.users WHERE referral_code = code) INTO exists;
        
        -- If code doesn't exist, return it
        IF NOT exists THEN
            RETURN code;
        END IF;
    END LOOP;
END;
$ LANGUAGE plpgsql;

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $
DECLARE
    new_referral_code TEXT;
    referrer_user_id UUID;
BEGIN
    -- Generate unique referral code
    new_referral_code := public.generate_referral_code();
    
    -- Insert user profile
    INSERT INTO public.users (
        id, 
        email, 
        full_name, 
        phone, 
        account_number, 
        join_date,
        referral_code,
        used_referral_code
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0'),
        timezone('utc'::text, now()),
        new_referral_code,
        COALESCE(NEW.raw_user_meta_data->>'used_referral_code', '')
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
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- ROW LEVEL SECURITY (RLS) SETUP
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- RLS POLICIES
-- =============================================================================

-- Users table policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Balances table policies
DROP POLICY IF EXISTS "Users can view own balance" ON public.balances;
CREATE POLICY "Users can view own balance" ON public.balances
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own balance" ON public.balances;
CREATE POLICY "Users can update own balance" ON public.balances
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own balance" ON public.balances;
CREATE POLICY "Users can insert own balance" ON public.balances
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Transactions table policies
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
CREATE POLICY "Users can insert own transactions" ON public.transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own transactions" ON public.transactions;
CREATE POLICY "Users can update own transactions" ON public.transactions
    FOR UPDATE USING (auth.uid() = user_id);

-- Investments table policies
DROP POLICY IF EXISTS "Users can view own investments" ON public.investments;
CREATE POLICY "Users can view own investments" ON public.investments
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own investments" ON public.investments;
CREATE POLICY "Users can insert own investments" ON public.investments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own investments" ON public.investments;
CREATE POLICY "Users can update own investments" ON public.investments
    FOR UPDATE USING (auth.uid() = user_id);

-- Savings goals table policies
DROP POLICY IF EXISTS "Users can view own savings goals" ON public.savings_goals;
CREATE POLICY "Users can view own savings goals" ON public.savings_goals
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own savings goals" ON public.savings_goals;
CREATE POLICY "Users can insert own savings goals" ON public.savings_goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own savings goals" ON public.savings_goals;
CREATE POLICY "Users can update own savings goals" ON public.savings_goals
    FOR UPDATE USING (auth.uid() = user_id);

-- Cards table policies
DROP POLICY IF EXISTS "Users can view own cards" ON public.cards;
CREATE POLICY "Users can view own cards" ON public.cards
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own cards" ON public.cards;
CREATE POLICY "Users can insert own cards" ON public.cards
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own cards" ON public.cards;
CREATE POLICY "Users can update own cards" ON public.cards
    FOR UPDATE USING (auth.uid() = user_id);

-- Notifications table policies
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own notifications" ON public.notifications;
CREATE POLICY "Users can insert own notifications" ON public.notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Referrals table policies
DROP POLICY IF EXISTS "Users can view own referrals" ON public.referrals;
CREATE POLICY "Users can view own referrals" ON public.referrals
    FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

DROP POLICY IF EXISTS "Users can insert referrals" ON public.referrals;
CREATE POLICY "Users can insert referrals" ON public.referrals
    FOR INSERT WITH CHECK (auth.uid() = referrer_id);

DROP POLICY IF EXISTS "Users can update own referrals" ON public.referrals;
CREATE POLICY "Users can update own referrals" ON public.referrals
    FOR UPDATE USING (auth.uid() = referrer_id);

-- =============================================================================
-- ENABLE REALTIME FOR TABLES
-- =============================================================================

-- Enable realtime for all tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.balances;
ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.investments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.savings_goals;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cards;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.referrals;

-- =============================================================================
-- EMAIL VERIFICATION SYSTEM
-- =============================================================================

-- Email verification tokens table
CREATE TABLE IF NOT EXISTS public.email_verification_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    token TEXT NOT NULL UNIQUE,
    verification_code TEXT NOT NULL,
    token_type TEXT NOT NULL CHECK (token_type IN ('signup', 'email_change', 'password_reset')),
    email TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    attempts INTEGER DEFAULT 0 NOT NULL CHECK (attempts >= 0 AND attempts <= 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Email verification logs table for tracking
CREATE TABLE IF NOT EXISTS public.email_verification_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    email TEXT NOT NULL,
    verification_type TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('sent', 'verified', 'expired', 'failed', 'resent')),
    ip_address INET,
    user_agent TEXT,
    token_id UUID REFERENCES public.email_verification_tokens(id) ON DELETE SET NULL,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- EMAIL VERIFICATION INDEXES
-- =============================================================================

-- Email verification tokens indexes
CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_user_id ON public.email_verification_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_token ON public.email_verification_tokens(token);
CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_email ON public.email_verification_tokens(email);
CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_expires_at ON public.email_verification_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_type_status ON public.email_verification_tokens(token_type, used_at);
CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_active ON public.email_verification_tokens(user_id, token_type) WHERE used_at IS NULL AND expires_at > NOW();

-- Email verification logs indexes
CREATE INDEX IF NOT EXISTS idx_email_verification_logs_user_id ON public.email_verification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_email_verification_logs_email ON public.email_verification_logs(email);
CREATE INDEX IF NOT EXISTS idx_email_verification_logs_status ON public.email_verification_logs(status);
CREATE INDEX IF NOT EXISTS idx_email_verification_logs_created_at ON public.email_verification_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_verification_logs_user_status ON public.email_verification_logs(user_id, status, created_at DESC);

-- Performance indexes for existing tables
CREATE INDEX IF NOT EXISTS idx_users_email_verified ON public.users(email, is_verified) WHERE is_verified = true;
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON public.users(verification_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_referral_active ON public.users(referral_code, is_active) WHERE is_active = true;

-- =============================================================================
-- EMAIL VERIFICATION FUNCTIONS
-- =============================================================================

-- Function to generate secure verification token
CREATE OR REPLACE FUNCTION public.generate_verification_token()
RETURNS TEXT AS $
DECLARE
    token TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a secure 32-character token
        token := encode(gen_random_bytes(24), 'base64');
        token := replace(replace(replace(token, '/', '_'), '+', '-'), '=', '');
        
        -- Check if token already exists
        SELECT EXISTS(SELECT 1 FROM public.email_verification_tokens WHERE token = token AND expires_at > NOW()) INTO exists;
        
        -- If token doesn't exist or is expired, return it
        IF NOT exists THEN
            RETURN token;
        END IF;
    END LOOP;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate 6-digit verification code
CREATE OR REPLACE FUNCTION public.generate_verification_code()
RETURNS TEXT AS $
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a 6-digit code
        code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        
        -- Check if code already exists and is not expired
        SELECT EXISTS(
            SELECT 1 FROM public.email_verification_tokens 
            WHERE verification_code = code 
            AND expires_at > NOW() 
            AND used_at IS NULL
        ) INTO exists;
        
        -- If code doesn't exist or is expired, return it
        IF NOT exists THEN
            RETURN code;
        END IF;
    END LOOP;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create email verification token
CREATE OR REPLACE FUNCTION public.create_email_verification_token(
    p_user_id UUID,
    p_email TEXT,
    p_token_type TEXT DEFAULT 'signup',
    p_expires_in_hours INTEGER DEFAULT 24
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    token TEXT,
    expires_at TIMESTAMP WITH TIME ZONE
) AS $
DECLARE
    new_token TEXT;
    token_expires_at TIMESTAMP WITH TIME ZONE;
    user_exists BOOLEAN;
BEGIN
    -- Validate user exists
    SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO user_exists;
    IF NOT user_exists THEN
        RETURN QUERY SELECT false, 'المستخدم غير موجود'::TEXT, ''::TEXT, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;
    
    -- Validate token type
    IF p_token_type NOT IN ('signup', 'email_change', 'password_reset') THEN
        RETURN QUERY SELECT false, 'نوع الرمز غير صحيح'::TEXT, ''::TEXT, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;
    
    -- Clean up expired tokens for this user and type
    DELETE FROM public.email_verification_tokens 
    WHERE user_id = p_user_id 
      AND token_type = p_token_type 
      AND expires_at <= NOW();
    
    -- Check if there's already an active token
    IF EXISTS(
        SELECT 1 FROM public.email_verification_tokens 
        WHERE user_id = p_user_id 
          AND token_type = p_token_type 
          AND used_at IS NULL 
          AND expires_at > NOW()
    ) THEN
        RETURN QUERY SELECT false, 'يوجد رمز تأكيد نشط بالفعل'::TEXT, ''::TEXT, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;
    
    -- Generate new token and verification code
    new_token := public.generate_verification_token();
    token_expires_at := NOW() + (p_expires_in_hours || ' hours')::INTERVAL;
    
    -- Insert new token with verification code
    INSERT INTO public.email_verification_tokens (
        user_id, token, verification_code, token_type, email, expires_at
    ) VALUES (
        p_user_id, new_token, public.generate_verification_code(), p_token_type, p_email, token_expires_at
    );
    
    -- Log the token creation
    INSERT INTO public.email_verification_logs (
        user_id, email, verification_type, status
    ) VALUES (
        p_user_id, p_email, p_token_type, 'sent'
    );
    
    RETURN QUERY SELECT true, 'تم إنشاء رمز التأكيد بنجاح'::TEXT, new_token, token_expires_at;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify email token or code
CREATE OR REPLACE FUNCTION public.verify_email_token(
    p_token TEXT,
    p_verification_code TEXT DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    user_id UUID,
    email TEXT,
    token_type TEXT
) AS $
DECLARE
    token_record RECORD;
    log_status TEXT;
BEGIN
    -- Find the token (by token or verification code)
    SELECT t.*, u.email as user_email
    INTO token_record
    FROM public.email_verification_tokens t
    JOIN public.users u ON t.user_id = u.id
    WHERE (t.token = p_token OR (p_verification_code IS NOT NULL AND t.verification_code = p_verification_code));
    
    -- Check if token exists
    IF token_record IS NULL THEN
        INSERT INTO public.email_verification_logs (
            user_id, email, verification_type, status, ip_address, user_agent, error_message
        ) VALUES (
            NULL, '', 'unknown', 'failed', p_ip_address, p_user_agent, 'رمز التأكيد غير موجود'
        );
        RETURN QUERY SELECT false, 'رمز التأكيد غير صحيح أو غير موجود'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check if token is already used
    IF token_record.used_at IS NOT NULL THEN
        log_status := 'failed';
        INSERT INTO public.email_verification_logs (
            user_id, email, verification_type, status, ip_address, user_agent, token_id, error_message
        ) VALUES (
            token_record.user_id, token_record.email, token_record.token_type, log_status, 
            p_ip_address, p_user_agent, token_record.id, 'رمز التأكيد مستخدم مسبقاً'
        );
        RETURN QUERY SELECT false, 'رمز التأكيد مستخدم مسبقاً'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check if token is expired
    IF token_record.expires_at <= NOW() THEN
        log_status := 'expired';
        INSERT INTO public.email_verification_logs (
            user_id, email, verification_type, status, ip_address, user_agent, token_id, error_message
        ) VALUES (
            token_record.user_id, token_record.email, token_record.token_type, log_status, 
            p_ip_address, p_user_agent, token_record.id, 'انتهت صلاحية رمز التأكيد'
        );
        RETURN QUERY SELECT false, 'انتهت صلاحية رمز التأكيد'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check attempts limit
    IF token_record.attempts >= 5 THEN
        log_status := 'failed';
        INSERT INTO public.email_verification_logs (
            user_id, email, verification_type, status, ip_address, user_agent, token_id, error_message
        ) VALUES (
            token_record.user_id, token_record.email, token_record.token_type, log_status, 
            p_ip_address, p_user_agent, token_record.id, 'تم تجاوز عدد المحاولات المسموح'
        );
        RETURN QUERY SELECT false, 'تم تجاوز عدد المحاولات المسموح'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Mark token as used
    UPDATE public.email_verification_tokens 
    SET used_at = NOW(), 
        updated_at = NOW()
    WHERE id = token_record.id;
    
    -- Update user verification status if it's a signup token
    IF token_record.token_type = 'signup' THEN
        UPDATE public.users 
        SET is_verified = true,
            verification_status = 'verified',
            updated_at = NOW()
        WHERE id = token_record.user_id;
    END IF;
    
    -- Log successful verification
    INSERT INTO public.email_verification_logs (
        user_id, email, verification_type, status, ip_address, user_agent, token_id
    ) VALUES (
        token_record.user_id, token_record.email, token_record.token_type, 'verified', 
        p_ip_address, p_user_agent, token_record.id
    );
    
    RETURN QUERY SELECT true, 'تم تأكيد البريد الإلكتروني بنجاح'::TEXT, 
                        token_record.user_id, token_record.email, token_record.token_type;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment token attempts
CREATE OR REPLACE FUNCTION public.increment_token_attempts(
    p_token TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    attempts_remaining INTEGER
) AS $
DECLARE
    token_record RECORD;
    new_attempts INTEGER;
BEGIN
    -- Find and update the token
    UPDATE public.email_verification_tokens 
    SET attempts = attempts + 1,
        updated_at = NOW()
    WHERE token = p_token 
      AND used_at IS NULL 
      AND expires_at > NOW()
    RETURNING * INTO token_record;
    
    IF token_record IS NULL THEN
        RETURN QUERY SELECT false, 'رمز التأكيد غير صحيح أو منتهي الصلاحية'::TEXT, 0;
        RETURN;
    END IF;
    
    new_attempts := token_record.attempts;
    
    -- Log the failed attempt
    INSERT INTO public.email_verification_logs (
        user_id, email, verification_type, status, ip_address, user_agent, token_id, error_message
    ) VALUES (
        token_record.user_id, token_record.email, token_record.token_type, 'failed', 
        p_ip_address, p_user_agent, token_record.id, 'محاولة تأكيد فاشلة'
    );
    
    RETURN QUERY SELECT true, 'تم تسجيل المحاولة'::TEXT, (5 - new_attempts);
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up expired tokens
CREATE OR REPLACE FUNCTION public.cleanup_expired_verification_tokens()
RETURNS TABLE(
    cleaned_tokens INTEGER,
    cleaned_logs INTEGER
) AS $
DECLARE
    tokens_count INTEGER;
    logs_count INTEGER;
BEGIN
    -- Delete expired tokens
    DELETE FROM public.email_verification_tokens 
    WHERE expires_at <= NOW() - INTERVAL '7 days';
    GET DIAGNOSTICS tokens_count = ROW_COUNT;
    
    -- Delete old logs (keep last 30 days)
    DELETE FROM public.email_verification_logs 
    WHERE created_at <= NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS logs_count = ROW_COUNT;
    
    RETURN QUERY SELECT tokens_count, logs_count;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user verification status
CREATE OR REPLACE FUNCTION public.get_user_verification_status(
    p_user_id UUID
)
RETURNS TABLE(
    is_verified BOOLEAN,
    verification_status TEXT,
    email_verified BOOLEAN,
    pending_verifications INTEGER,
    last_verification_attempt TIMESTAMP WITH TIME ZONE
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        u.is_verified,
        u.verification_status,
        (u.is_verified IS TRUE) as email_verified,
        COALESCE(
            (SELECT COUNT(*)::INTEGER 
             FROM public.email_verification_tokens 
             WHERE user_id = p_user_id 
               AND used_at IS NULL 
               AND expires_at > NOW()), 0
        ) as pending_verifications,
        (
            SELECT MAX(created_at) 
            FROM public.email_verification_logs 
            WHERE user_id = p_user_id
        ) as last_verification_attempt
    FROM public.users u
    WHERE u.id = p_user_id;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- EMAIL VERIFICATION TRIGGERS
-- =============================================================================

-- Trigger to update email verification tokens timestamp
CREATE TRIGGER update_email_verification_tokens_updated_at 
    BEFORE UPDATE ON public.email_verification_tokens
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- EMAIL VERIFICATION RLS POLICIES
-- =============================================================================

-- Enable RLS on email verification tables
ALTER TABLE public.email_verification_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_verification_logs ENABLE ROW LEVEL SECURITY;

-- Email verification tokens policies
DROP POLICY IF EXISTS "Users can view own verification tokens" ON public.email_verification_tokens;
CREATE POLICY "Users can view own verification tokens" ON public.email_verification_tokens
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own verification tokens" ON public.email_verification_tokens;
CREATE POLICY "Users can insert own verification tokens" ON public.email_verification_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own verification tokens" ON public.email_verification_tokens;
CREATE POLICY "Users can update own verification tokens" ON public.email_verification_tokens
    FOR UPDATE USING (auth.uid() = user_id);

-- Email verification logs policies
DROP POLICY IF EXISTS "Users can view own verification logs" ON public.email_verification_logs;
CREATE POLICY "Users can view own verification logs" ON public.email_verification_logs
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own verification logs" ON public.email_verification_logs;
CREATE POLICY "Users can insert own verification logs" ON public.email_verification_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- =============================================================================
-- ENABLE REALTIME FOR EMAIL VERIFICATION TABLES
-- =============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.email_verification_tokens;
ALTER PUBLICATION supabase_realtime ADD TABLE public.email_verification_logs;

-- =============================================================================
-- SCHEDULED CLEANUP JOB (Manual execution)
-- =============================================================================

-- Create a function to be called periodically to clean up expired data
CREATE OR REPLACE FUNCTION public.scheduled_email_verification_cleanup()
RETURNS TEXT AS $
DECLARE
    cleanup_result RECORD;
BEGIN
    SELECT * INTO cleanup_result FROM public.cleanup_expired_verification_tokens();
    
    RETURN format('تم تنظيف %s رمز منتهي الصلاحية و %s سجل قديم', 
                  cleanup_result.cleaned_tokens, 
                  cleanup_result.cleaned_logs);
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- OTP SYSTEM FOR PHONE VERIFICATION
-- =============================================================================

-- OTPs table - stores one-time passwords for phone verification
CREATE TABLE IF NOT EXISTS public.otps (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    phone_number TEXT NOT NULL,
    otp_code TEXT NOT NULL,
    otp_type TEXT NOT NULL CHECK (otp_type IN ('phone_verification', 'login', 'password_reset', 'transaction')),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    attempts INTEGER DEFAULT 0 NOT NULL CHECK (attempts >= 0 AND attempts <= 5),
    is_verified BOOLEAN DEFAULT false NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- OTP logs table - tracks all OTP activities
CREATE TABLE IF NOT EXISTS public.otp_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    otp_id UUID REFERENCES public.otps(id) ON DELETE SET NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    phone_number TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('sent', 'verified', 'expired', 'failed', 'resent', 'blocked')),
    otp_type TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    error_message TEXT,
    metadata JSON,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- OTP INDEXES FOR PERFORMANCE
-- =============================================================================

-- OTP table indexes
CREATE INDEX IF NOT EXISTS idx_otps_user_id ON public.otps(user_id);
CREATE INDEX IF NOT EXISTS idx_otps_phone_number ON public.otps(phone_number);
CREATE INDEX IF NOT EXISTS idx_otps_otp_code ON public.otps(otp_code);
CREATE INDEX IF NOT EXISTS idx_otps_expires_at ON public.otps(expires_at);
CREATE INDEX IF NOT EXISTS idx_otps_type_status ON public.otps(otp_type, used_at);
CREATE INDEX IF NOT EXISTS idx_otps_active ON public.otps(phone_number, otp_type) WHERE used_at IS NULL AND expires_at > NOW();
CREATE INDEX IF NOT EXISTS idx_otps_verification_status ON public.otps(is_verified, created_at DESC);

-- OTP logs indexes
CREATE INDEX IF NOT EXISTS idx_otp_logs_otp_id ON public.otp_logs(otp_id);
CREATE INDEX IF NOT EXISTS idx_otp_logs_user_id ON public.otp_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_otp_logs_phone_number ON public.otp_logs(phone_number);
CREATE INDEX IF NOT EXISTS idx_otp_logs_action ON public.otp_logs(action);
CREATE INDEX IF NOT EXISTS idx_otp_logs_created_at ON public.otp_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_otp_logs_user_action ON public.otp_logs(user_id, action, created_at DESC);

-- =============================================================================
-- OTP FUNCTIONS
-- =============================================================================

-- Function to generate secure 6-digit OTP
CREATE OR REPLACE FUNCTION public.generate_otp_code()
RETURNS TEXT AS $
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a 6-digit code
        code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        
        -- Check if code already exists and is not expired
        SELECT EXISTS(
            SELECT 1 FROM public.otps 
            WHERE otp_code = code 
            AND expires_at > NOW() 
            AND used_at IS NULL
        ) INTO exists;
        
        -- If code doesn't exist or is expired, return it
        IF NOT exists THEN
            RETURN code;
        END IF;
    END LOOP;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create OTP
CREATE OR REPLACE FUNCTION public.create_otp(
    p_user_id UUID DEFAULT NULL,
    p_phone_number TEXT,
    p_otp_type TEXT DEFAULT 'phone_verification',
    p_expires_in_minutes INTEGER DEFAULT 5,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    otp_id UUID,
    otp_code TEXT,
    expires_at TIMESTAMP WITH TIME ZONE
) AS $
DECLARE
    new_otp_code TEXT;
    new_otp_id UUID;
    otp_expires_at TIMESTAMP WITH TIME ZONE;
    phone_exists BOOLEAN;
    rate_limit_check INTEGER;
BEGIN
    -- Validate phone number format
    IF p_phone_number IS NULL OR LENGTH(TRIM(p_phone_number)) < 10 THEN
        RETURN QUERY SELECT false, 'رقم الهاتف غير صحيح'::TEXT, NULL::UUID, ''::TEXT, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;
    
    -- Validate OTP type
    IF p_otp_type NOT IN ('phone_verification', 'login', 'password_reset', 'transaction') THEN
        RETURN QUERY SELECT false, 'نوع OTP غير صحيح'::TEXT, NULL::UUID, ''::TEXT, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;
    
    -- Rate limiting: Check if too many OTPs sent in last 5 minutes
    SELECT COUNT(*) INTO rate_limit_check
    FROM public.otp_logs 
    WHERE phone_number = p_phone_number 
      AND action = 'sent'
      AND created_at > NOW() - INTERVAL '5 minutes';
      
    IF rate_limit_check >= 3 THEN
        RETURN QUERY SELECT false, 'تم تجاوز الحد المسموح لإرسال OTP. يرجى الانتظار 5 دقائق'::TEXT, NULL::UUID, ''::TEXT, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;
    
    -- Clean up expired OTPs for this phone number
    DELETE FROM public.otps 
    WHERE phone_number = p_phone_number 
      AND otp_type = p_otp_type 
      AND expires_at <= NOW();
    
    -- Check if there's already an active OTP
    IF EXISTS(
        SELECT 1 FROM public.otps 
        WHERE phone_number = p_phone_number 
          AND otp_type = p_otp_type 
          AND used_at IS NULL 
          AND expires_at > NOW()
    ) THEN
        RETURN QUERY SELECT false, 'يوجد OTP نشط بالفعل لهذا الرقم'::TEXT, NULL::UUID, ''::TEXT, NULL::TIMESTAMP WITH TIME ZONE;
        RETURN;
    END IF;
    
    -- Generate new OTP code
    new_otp_code := public.generate_otp_code();
    otp_expires_at := NOW() + (p_expires_in_minutes || ' minutes')::INTERVAL;
    
    -- Insert new OTP
    INSERT INTO public.otps (
        user_id, phone_number, otp_code, otp_type, expires_at, ip_address, user_agent
    ) VALUES (
        p_user_id, p_phone_number, new_otp_code, p_otp_type, otp_expires_at, p_ip_address, p_user_agent
    ) RETURNING id INTO new_otp_id;
    
    -- Log the OTP creation
    INSERT INTO public.otp_logs (
        otp_id, user_id, phone_number, action, otp_type, ip_address, user_agent
    ) VALUES (
        new_otp_id, p_user_id, p_phone_number, 'sent', p_otp_type, p_ip_address, p_user_agent
    );
    
    RETURN QUERY SELECT true, 'تم إنشاء OTP بنجاح'::TEXT, new_otp_id, new_otp_code, otp_expires_at;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify OTP
CREATE OR REPLACE FUNCTION public.verify_otp(
    p_phone_number TEXT,
    p_otp_code TEXT,
    p_otp_type TEXT DEFAULT 'phone_verification',
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    user_id UUID,
    phone_number TEXT,
    otp_type TEXT
) AS $
DECLARE
    otp_record RECORD;
    log_action TEXT;
BEGIN
    -- Find the OTP
    SELECT o.*, u.id as user_id_from_users
    INTO otp_record
    FROM public.otps o
    LEFT JOIN public.users u ON o.user_id = u.id
    WHERE o.phone_number = p_phone_number 
      AND o.otp_code = p_otp_code 
      AND o.otp_type = p_otp_type;
    
    -- Check if OTP exists
    IF otp_record IS NULL THEN
        INSERT INTO public.otp_logs (
            user_id, phone_number, action, otp_type, ip_address, user_agent, error_message
        ) VALUES (
            NULL, p_phone_number, 'failed', p_otp_type, p_ip_address, p_user_agent, 'OTP غير موجود'
        );
        RETURN QUERY SELECT false, 'رمز OTP غير صحيح أو غير موجود'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check if OTP is already used
    IF otp_record.used_at IS NOT NULL THEN
        log_action := 'failed';
        INSERT INTO public.otp_logs (
            otp_id, user_id, phone_number, action, otp_type, ip_address, user_agent, error_message
        ) VALUES (
            otp_record.id, otp_record.user_id, p_phone_number, log_action, p_otp_type, 
            p_ip_address, p_user_agent, 'OTP مستخدم مسبقاً'
        );
        RETURN QUERY SELECT false, 'رمز OTP مستخدم مسبقاً'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check if OTP is expired
    IF otp_record.expires_at <= NOW() THEN
        log_action := 'expired';
        INSERT INTO public.otp_logs (
            otp_id, user_id, phone_number, action, otp_type, ip_address, user_agent, error_message
        ) VALUES (
            otp_record.id, otp_record.user_id, p_phone_number, log_action, p_otp_type, 
            p_ip_address, p_user_agent, 'انتهت صلاحية OTP'
        );
        RETURN QUERY SELECT false, 'انتهت صلاحية رمز OTP'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Check attempts limit
    IF otp_record.attempts >= 5 THEN
        log_action := 'blocked';
        INSERT INTO public.otp_logs (
            otp_id, user_id, phone_number, action, otp_type, ip_address, user_agent, error_message
        ) VALUES (
            otp_record.id, otp_record.user_id, p_phone_number, log_action, p_otp_type, 
            p_ip_address, p_user_agent, 'تم تجاوز عدد المحاولات المسموح'
        );
        RETURN QUERY SELECT false, 'تم تجاوز عدد المحاولات المسموح'::TEXT, NULL::UUID, ''::TEXT, ''::TEXT;
        RETURN;
    END IF;
    
    -- Mark OTP as used and verified
    UPDATE public.otps 
    SET used_at = NOW(), 
        is_verified = true,
        updated_at = NOW()
    WHERE id = otp_record.id;
    
    -- Update user phone verification status if it's phone verification
    IF p_otp_type = 'phone_verification' AND otp_record.user_id IS NOT NULL THEN
        UPDATE public.users 
        SET phone = p_phone_number,
            is_verified = true,
            verification_status = 'verified',
            updated_at = NOW()
        WHERE id = otp_record.user_id;
    END IF;
    
    -- Log successful verification
    INSERT INTO public.otp_logs (
        otp_id, user_id, phone_number, action, otp_type, ip_address, user_agent
    ) VALUES (
        otp_record.id, otp_record.user_id, p_phone_number, 'verified', p_otp_type, 
        p_ip_address, p_user_agent
    );
    
    RETURN QUERY SELECT true, 'تم تأكيد OTP بنجاح'::TEXT, 
                        otp_record.user_id, p_phone_number, p_otp_type;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment OTP attempts
CREATE OR REPLACE FUNCTION public.increment_otp_attempts(
    p_phone_number TEXT,
    p_otp_code TEXT,
    p_otp_type TEXT DEFAULT 'phone_verification',
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    attempts_remaining INTEGER
) AS $
DECLARE
    otp_record RECORD;
    new_attempts INTEGER;
BEGIN
    -- Find and update the OTP
    UPDATE public.otps 
    SET attempts = attempts + 1,
        updated_at = NOW()
    WHERE phone_number = p_phone_number 
      AND otp_code = p_otp_code
      AND otp_type = p_otp_type
      AND used_at IS NULL 
      AND expires_at > NOW()
    RETURNING * INTO otp_record;
    
    IF otp_record IS NULL THEN
        RETURN QUERY SELECT false, 'رمز OTP غير صحيح أو منتهي الصلاحية'::TEXT, 0;
        RETURN;
    END IF;
    
    new_attempts := otp_record.attempts;
    
    -- Log the failed attempt
    INSERT INTO public.otp_logs (
        otp_id, user_id, phone_number, action, otp_type, ip_address, user_agent, error_message
    ) VALUES (
        otp_record.id, otp_record.user_id, p_phone_number, 'failed', p_otp_type, 
        p_ip_address, p_user_agent, 'محاولة تأكيد فاشلة'
    );
    
    RETURN QUERY SELECT true, 'تم تسجيل المحاولة'::TEXT, (5 - new_attempts);
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up expired OTPs
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS TABLE(
    cleaned_otps INTEGER,
    cleaned_logs INTEGER
) AS $
DECLARE
    otps_count INTEGER;
    logs_count INTEGER;
BEGIN
    -- Delete expired OTPs
    DELETE FROM public.otps 
    WHERE expires_at <= NOW() - INTERVAL '1 day';
    GET DIAGNOSTICS otps_count = ROW_COUNT;
    
    -- Delete old logs (keep last 30 days)
    DELETE FROM public.otp_logs 
    WHERE created_at <= NOW() - INTERVAL '30 days';
    GET DIAGNOSTICS logs_count = ROW_COUNT;
    
    RETURN QUERY SELECT otps_count, logs_count;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get OTP status
CREATE OR REPLACE FUNCTION public.get_otp_status(
    p_phone_number TEXT,
    p_otp_type TEXT DEFAULT 'phone_verification'
)
RETURNS TABLE(
    has_active_otp BOOLEAN,
    expires_at TIMESTAMP WITH TIME ZONE,
    attempts_used INTEGER,
    can_resend BOOLEAN,
    next_resend_at TIMESTAMP WITH TIME ZONE
) AS $
DECLARE
    active_otp RECORD;
    last_sent TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get active OTP
    SELECT * INTO active_otp
    FROM public.otps 
    WHERE phone_number = p_phone_number 
      AND otp_type = p_otp_type 
      AND used_at IS NULL 
      AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1;
    
    -- Get last sent time
    SELECT MAX(created_at) INTO last_sent
    FROM public.otp_logs 
    WHERE phone_number = p_phone_number 
      AND action = 'sent'
      AND created_at > NOW() - INTERVAL '5 minutes';
    
    IF active_otp IS NOT NULL THEN
        RETURN QUERY SELECT 
            true,
            active_otp.expires_at,
            active_otp.attempts,
            (last_sent IS NULL OR last_sent < NOW() - INTERVAL '1 minute'),
            CASE 
                WHEN last_sent IS NOT NULL THEN last_sent + INTERVAL '1 minute'
                ELSE NOW()
            END;
    ELSE
        RETURN QUERY SELECT 
            false,
            NULL::TIMESTAMP WITH TIME ZONE,
            0,
            (last_sent IS NULL OR last_sent < NOW() - INTERVAL '1 minute'),
            CASE 
                WHEN last_sent IS NOT NULL THEN last_sent + INTERVAL '1 minute'
                ELSE NOW()
            END;
    END IF;
END;
$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- OTP TRIGGERS
-- =============================================================================

-- Trigger to update OTP timestamps
CREATE TRIGGER update_otps_updated_at 
    BEFORE UPDATE ON public.otps
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- OTP RLS POLICIES
-- =============================================================================

-- Enable RLS on OTP tables
ALTER TABLE public.otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_logs ENABLE ROW LEVEL SECURITY;

-- OTP table policies
DROP POLICY IF EXISTS "Users can view own OTPs" ON public.otps;
CREATE POLICY "Users can view own OTPs" ON public.otps
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can insert own OTPs" ON public.otps;
CREATE POLICY "Users can insert own OTPs" ON public.otps
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can update own OTPs" ON public.otps;
CREATE POLICY "Users can update own OTPs" ON public.otps
    FOR UPDATE USING (auth.uid() = user_id OR user_id IS NULL);

-- OTP logs policies
DROP POLICY IF EXISTS "Users can view own OTP logs" ON public.otp_logs;
CREATE POLICY "Users can view own OTP logs" ON public.otp_logs
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can insert own OTP logs" ON public.otp_logs;
CREATE POLICY "Users can insert own OTP logs" ON public.otp_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- =============================================================================
-- ENABLE REALTIME FOR OTP TABLES
-- =============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.otps;
ALTER PUBLICATION supabase_realtime ADD TABLE public.otp_logs;

-- =============================================================================
-- SCRIPT COMPLETION
-- =============================================================================
-- Database setup completed successfully!
-- All tables, indexes, triggers, policies, email verification system, and OTP system have been created.
-- =============================================================================
