-- =============================================================================
-- COMPREHENSIVE DATABASE SETUP FOR FINANCIAL APPLICATION
-- =============================================================================
-- This migration creates a complete database setup with all necessary functions,
-- triggers, policies, and security measures for a professional financial app
-- =============================================================================

-- =============================================================================
-- ENABLE REQUIRED EXTENSIONS
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- =============================================================================
-- ENHANCED USERS TABLE WITH COMPREHENSIVE FIELDS
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL DEFAULT 'مستخدم جديد',
    phone TEXT,
    account_number TEXT UNIQUE NOT NULL,
    join_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    location TEXT,
    language TEXT DEFAULT 'ar',
    currency TEXT DEFAULT 'dzd',
    profile_image TEXT,
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'rejected', 'suspended')),
    referral_code TEXT UNIQUE,
    used_referral_code TEXT,
    referral_earnings DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    last_login TIMESTAMP WITH TIME ZONE,
    login_count INTEGER DEFAULT 0,
    security_level TEXT DEFAULT 'basic' CHECK (security_level IN ('basic', 'enhanced', 'premium')),
    two_factor_enabled BOOLEAN DEFAULT false,
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "push": true}'::jsonb,
    privacy_settings JSONB DEFAULT '{"profile_visible": true, "activity_visible": false}'::jsonb,
    kyc_status TEXT DEFAULT 'not_started' CHECK (kyc_status IN ('not_started', 'pending', 'approved', 'rejected')),
    kyc_documents JSONB DEFAULT '[]'::jsonb,
    risk_score INTEGER DEFAULT 0 CHECK (risk_score >= 0 AND risk_score <= 100),
    account_limits JSONB DEFAULT '{"daily_transfer": 50000, "monthly_transfer": 500000, "daily_withdrawal": 20000}'::jsonb
);

-- =============================================================================
-- ENHANCED BALANCES TABLE WITH INVESTMENT TRACKING
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.balances (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    dzd DECIMAL(15,2) DEFAULT 15000.00 NOT NULL CHECK (dzd >= 0),
    eur DECIMAL(15,2) DEFAULT 75.00 NOT NULL CHECK (eur >= 0),
    usd DECIMAL(15,2) DEFAULT 85.00 NOT NULL CHECK (usd >= 0),
    gbp DECIMAL(15,2) DEFAULT 65.50 NOT NULL CHECK (gbp >= 0),
    btc DECIMAL(15,8) DEFAULT 0.00000000 NOT NULL CHECK (btc >= 0),
    eth DECIMAL(15,8) DEFAULT 0.00000000 NOT NULL CHECK (eth >= 0),
    investment_balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (investment_balance >= 0),
    savings_balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (savings_balance >= 0),
    frozen_balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (frozen_balance >= 0),
    pending_balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (pending_balance >= 0),
    total_earned DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (total_earned >= 0),
    total_spent DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (total_spent >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- ENHANCED TRANSACTIONS TABLE WITH COMPREHENSIVE TRACKING
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('recharge', 'transfer', 'bill', 'investment', 'conversion', 'withdrawal', 'refund', 'fee', 'reward', 'penalty')),
    category TEXT DEFAULT 'general' CHECK (category IN ('general', 'food', 'transport', 'shopping', 'bills', 'entertainment', 'health', 'education', 'investment', 'savings')),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    fee DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (fee >= 0),
    net_amount DECIMAL(15,2) GENERATED ALWAYS AS (amount - fee) STORED,
    currency TEXT DEFAULT 'dzd' CHECK (currency IN ('dzd', 'eur', 'usd', 'gbp', 'btc', 'eth')),
    exchange_rate DECIMAL(15,6) DEFAULT 1.000000,
    description TEXT NOT NULL,
    reference TEXT UNIQUE,
    recipient TEXT,
    recipient_account TEXT,
    sender_account TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded')),
    failure_reason TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    location JSONB,
    device_info JSONB,
    ip_address INET,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- ENHANCED INVESTMENTS TABLE WITH DETAILED TRACKING
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.investments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('weekly', 'monthly', 'quarterly', 'yearly', 'flexible')),
    product_name TEXT NOT NULL DEFAULT 'استثمار عام',
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    maturity_date TIMESTAMP WITH TIME ZONE,
    profit_rate DECIMAL(5,2) NOT NULL CHECK (profit_rate >= 0 AND profit_rate <= 100),
    expected_profit DECIMAL(15,2) GENERATED ALWAYS AS (amount * profit_rate / 100) STORED,
    actual_profit DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    total_return DECIMAL(15,2) GENERATED ALWAYS AS (amount + actual_profit) STORED,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'paused', 'liquidated')),
    auto_renew BOOLEAN DEFAULT false,
    risk_level TEXT DEFAULT 'medium' CHECK (risk_level IN ('low', 'medium', 'high')),
    terms_accepted BOOLEAN DEFAULT false NOT NULL,
    early_withdrawal_penalty DECIMAL(5,2) DEFAULT 5.00,
    compound_interest BOOLEAN DEFAULT false,
    payment_frequency TEXT DEFAULT 'maturity' CHECK (payment_frequency IN ('daily', 'weekly', 'monthly', 'quarterly', 'yearly', 'maturity')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT valid_investment_dates CHECK (end_date > start_date)
);

-- =============================================================================
-- ENHANCED SAVINGS GOALS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.savings_goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    target_amount DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (current_amount >= 0),
    monthly_target DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (monthly_target >= 0),
    progress_percentage DECIMAL(5,2) GENERATED ALWAYS AS (CASE WHEN target_amount > 0 THEN (current_amount / target_amount * 100) ELSE 0 END) STORED,
    deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    category TEXT NOT NULL DEFAULT 'general',
    icon TEXT NOT NULL DEFAULT 'target',
    color TEXT NOT NULL DEFAULT '#3B82F6',
    priority INTEGER DEFAULT 1 CHECK (priority >= 1 AND priority <= 5),
    auto_save BOOLEAN DEFAULT false,
    auto_save_amount DECIMAL(15,2) DEFAULT 0.00,
    auto_save_frequency TEXT DEFAULT 'monthly' CHECK (auto_save_frequency IN ('daily', 'weekly', 'monthly')),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    completion_date TIMESTAMP WITH TIME ZONE,
    reward_amount DECIMAL(15,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT valid_savings_amounts CHECK (current_amount <= target_amount)
);

-- =============================================================================
-- ENHANCED CARDS TABLE WITH COMPREHENSIVE FEATURES
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.cards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    card_number TEXT NOT NULL,
    card_type TEXT NOT NULL CHECK (card_type IN ('solid', 'virtual', 'premium', 'business')),
    card_name TEXT DEFAULT 'بطاقة شخصية',
    expiry_date DATE,
    cvv TEXT,
    pin_hash TEXT,
    is_frozen BOOLEAN DEFAULT false NOT NULL,
    freeze_reason TEXT,
    spending_limit DECIMAL(15,2) DEFAULT 50000.00 NOT NULL CHECK (spending_limit >= 0),
    daily_limit DECIMAL(15,2) DEFAULT 10000.00 NOT NULL CHECK (daily_limit >= 0),
    monthly_limit DECIMAL(15,2) DEFAULT 100000.00 NOT NULL CHECK (monthly_limit >= 0),
    current_daily_spent DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (current_daily_spent >= 0),
    current_monthly_spent DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (current_monthly_spent >= 0),
    contactless_enabled BOOLEAN DEFAULT true,
    online_payments_enabled BOOLEAN DEFAULT true,
    international_payments_enabled BOOLEAN DEFAULT false,
    atm_withdrawals_enabled BOOLEAN DEFAULT true,
    notifications_enabled BOOLEAN DEFAULT true,
    security_features JSONB DEFAULT '{"chip": true, "contactless": true, "3d_secure": true}'::jsonb,
    last_used TIMESTAMP WITH TIME ZONE,
    activation_date TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'active' CHECK (status IN ('pending', 'active', 'blocked', 'expired', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- ENHANCED NOTIFICATIONS TABLE WITH RICH FEATURES
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('success', 'error', 'info', 'warning', 'security', 'promotion', 'system')),
    category TEXT DEFAULT 'general' CHECK (category IN ('general', 'transaction', 'security', 'account', 'investment', 'promotion', 'system')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    action_url TEXT,
    action_text TEXT,
    priority INTEGER DEFAULT 1 CHECK (priority >= 1 AND priority <= 5),
    is_read BOOLEAN DEFAULT false NOT NULL,
    is_archived BOOLEAN DEFAULT false NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    delivery_channels TEXT[] DEFAULT ARRAY['app'],
    sent_via_email BOOLEAN DEFAULT false,
    sent_via_sms BOOLEAN DEFAULT false,
    sent_via_push BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- ENHANCED REFERRALS TABLE WITH DETAILED TRACKING
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    referred_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    referral_code TEXT NOT NULL,
    reward_amount DECIMAL(15,2) DEFAULT 500.00 NOT NULL CHECK (reward_amount >= 0),
    bonus_amount DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (bonus_amount >= 0),
    total_reward DECIMAL(15,2) GENERATED ALWAYS AS (reward_amount + bonus_amount) STORED,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled', 'expired')),
    completion_requirements JSONB DEFAULT '{"email_verified": true, "first_transaction": false, "minimum_balance": 0}'::jsonb,
    requirements_met JSONB DEFAULT '{}'::jsonb,
    completion_date TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (timezone('utc'::text, now()) + INTERVAL '30 days'),
    tier_level INTEGER DEFAULT 1 CHECK (tier_level >= 1 AND tier_level <= 5),
    campaign_id TEXT,
    source TEXT DEFAULT 'direct',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT no_self_referral CHECK (referrer_id != referred_id)
);

-- =============================================================================
-- SECURITY AUDIT LOG TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.security_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN ('login', 'logout', 'password_change', 'email_change', 'phone_change', 'failed_login', 'account_locked', 'suspicious_activity', 'device_change')),
    severity TEXT DEFAULT 'info' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    description TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    device_fingerprint TEXT,
    location JSONB,
    metadata JSONB DEFAULT '{}'::jsonb,
    resolved BOOLEAN DEFAULT false,
    resolved_by UUID REFERENCES public.users(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- SYSTEM SETTINGS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.system_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'general',
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- PERFORMANCE INDEXES
-- =============================================================================

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_account_number ON public.users(account_number);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON public.users(verification_status);
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code) WHERE referral_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_kyc_status ON public.users(kyc_status);
CREATE INDEX IF NOT EXISTS idx_users_last_login ON public.users(last_login DESC);

-- Balances table indexes
CREATE INDEX IF NOT EXISTS idx_balances_user_id ON public.balances(user_id);
CREATE INDEX IF NOT EXISTS idx_balances_updated_at ON public.balances(updated_at DESC);

-- Transactions table indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON public.transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON public.transactions(reference) WHERE reference IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON public.transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user_status ON public.transactions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON public.transactions(category);
CREATE INDEX IF NOT EXISTS idx_transactions_amount ON public.transactions(amount DESC);

-- Investments table indexes
CREATE INDEX IF NOT EXISTS idx_investments_user_id ON public.investments(user_id);
CREATE INDEX IF NOT EXISTS idx_investments_status ON public.investments(status);
CREATE INDEX IF NOT EXISTS idx_investments_end_date ON public.investments(end_date);
CREATE INDEX IF NOT EXISTS idx_investments_type ON public.investments(type);
CREATE INDEX IF NOT EXISTS idx_investments_profit_rate ON public.investments(profit_rate DESC);

-- Savings goals table indexes
CREATE INDEX IF NOT EXISTS idx_savings_goals_user_id ON public.savings_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_savings_goals_status ON public.savings_goals(status);
CREATE INDEX IF NOT EXISTS idx_savings_goals_deadline ON public.savings_goals(deadline);
CREATE INDEX IF NOT EXISTS idx_savings_goals_priority ON public.savings_goals(priority DESC);

-- Cards table indexes
CREATE INDEX IF NOT EXISTS idx_cards_user_id ON public.cards(user_id);
CREATE INDEX IF NOT EXISTS idx_cards_card_number ON public.cards(card_number);
CREATE INDEX IF NOT EXISTS idx_cards_status ON public.cards(status);
CREATE INDEX IF NOT EXISTS idx_cards_type ON public.cards(card_type);

-- Notifications table indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_category ON public.notifications(category);
CREATE INDEX IF NOT EXISTS idx_notifications_priority ON public.notifications(priority DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = false;

-- Referrals table indexes
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON public.referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);
CREATE INDEX IF NOT EXISTS idx_referrals_expires_at ON public.referrals(expires_at);

-- Security logs table indexes
CREATE INDEX IF NOT EXISTS idx_security_logs_user_id ON public.security_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_security_logs_event_type ON public.security_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_security_logs_severity ON public.security_logs(severity);
CREATE INDEX IF NOT EXISTS idx_security_logs_created_at ON public.security_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_logs_resolved ON public.security_logs(resolved);

-- System settings table indexes
CREATE INDEX IF NOT EXISTS idx_system_settings_key ON public.system_settings(key);
CREATE INDEX IF NOT EXISTS idx_system_settings_category ON public.system_settings(category);

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique account number
CREATE OR REPLACE FUNCTION public.generate_account_number()
RETURNS TEXT AS $$
DECLARE
    account_num TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate a 12-digit account number starting with 'ACC'
        account_num := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
        
        -- Check if account number already exists
        SELECT EXISTS(SELECT 1 FROM public.users WHERE account_number = account_num) INTO exists;
        
        -- If account number doesn't exist, return it
        IF NOT exists THEN
            RETURN account_num;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT AS $$
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
$$ LANGUAGE plpgsql;

-- Function to generate secure card number
CREATE OR REPLACE FUNCTION public.generate_card_number(card_type TEXT DEFAULT 'virtual')
RETURNS TEXT AS $$
DECLARE
    card_num TEXT;
    exists BOOLEAN;
    prefix TEXT;
BEGIN
    -- Set prefix based on card type
    CASE card_type
        WHEN 'solid' THEN prefix := '4532';
        WHEN 'premium' THEN prefix := '4539';
        WHEN 'business' THEN prefix := '4556';
        ELSE prefix := '4521'; -- virtual
    END CASE;
    
    LOOP
        -- Generate a 16-digit card number
        card_num := prefix || LPAD(FLOOR(RANDOM() * 1000000000000)::TEXT, 12, '0');
        
        -- Check if card number already exists
        SELECT EXISTS(SELECT 1 FROM public.cards WHERE card_number = card_num) INTO exists;
        
        -- If card number doesn't exist, return it
        IF NOT exists THEN
            RETURN card_num;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to log security events
CREATE OR REPLACE FUNCTION public.log_security_event(
    p_user_id UUID,
    p_event_type TEXT,
    p_description TEXT,
    p_severity TEXT DEFAULT 'info',
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO public.security_logs (
        user_id, event_type, description, severity, ip_address, user_agent, metadata
    ) VALUES (
        p_user_id, p_event_type, p_description, p_severity, p_ip_address, p_user_agent, p_metadata
    ) RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create notification
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_message TEXT,
    p_category TEXT DEFAULT 'general',
    p_priority INTEGER DEFAULT 1,
    p_action_url TEXT DEFAULT NULL,
    p_action_text TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO public.notifications (
        user_id, type, title, message, category, priority, action_url, action_text, metadata
    ) VALUES (
        p_user_id, p_type, p_title, p_message, p_category, p_priority, p_action_url, p_action_text, p_metadata
    ) RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- COMPREHENSIVE USER REGISTRATION FUNCTION
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_referral_code TEXT;
    new_account_number TEXT;
    referrer_user_id UUID;
    welcome_bonus DECIMAL(15,2) := 100.00;
BEGIN
    -- Generate unique codes
    new_referral_code := public.generate_referral_code();
    new_account_number := public.generate_account_number();
    
    -- Insert user profile with comprehensive data
    INSERT INTO public.users (
        id, 
        email, 
        full_name, 
        phone, 
        account_number, 
        join_date,
        referral_code,
        used_referral_code,
        is_verified,
        verification_status,
        last_login,
        login_count
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'fullName', 'مستخدم جديد'),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        new_account_number,
        timezone('utc'::text, now()),
        new_referral_code,
        COALESCE(NEW.raw_user_meta_data->>'referralCode', NEW.raw_user_meta_data->>'used_referral_code', ''),
        CASE WHEN NEW.email_confirmed_at IS NOT NULL THEN true ELSE false END,
        CASE WHEN NEW.email_confirmed_at IS NOT NULL THEN 'verified' ELSE 'pending' END,
        timezone('utc'::text, now()),
        1
    );
    
    -- Create initial balance record with welcome bonus
    INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
    VALUES (NEW.id, 15000.00 + welcome_bonus, 75.00, 85.00, 65.50);
    
    -- Create welcome virtual card
    INSERT INTO public.cards (
        user_id, 
        card_number, 
        card_type, 
        card_name,
        expiry_date,
        status,
        activation_date
    )
    VALUES (
        NEW.id,
        public.generate_card_number('virtual'),
        'virtual',
        'بطاقة ترحيبية',
        CURRENT_DATE + INTERVAL '3 years',
        'active',
        timezone('utc'::text, now())
    );
    
    -- Handle referral reward if user used a referral code
    IF NEW.raw_user_meta_data->>'referralCode' IS NOT NULL AND NEW.raw_user_meta_data->>'referralCode' != '' THEN
        -- Find the referrer
        SELECT id INTO referrer_user_id 
        FROM public.users 
        WHERE referral_code = NEW.raw_user_meta_data->>'referralCode'
        AND is_active = true;
        
        -- If referrer found, create referral record and add reward
        IF referrer_user_id IS NOT NULL THEN
            -- Create referral record
            INSERT INTO public.referrals (
                referrer_id,
                referred_id,
                referral_code,
                reward_amount,
                status,
                completion_date
            )
            VALUES (
                referrer_user_id,
                NEW.id,
                NEW.raw_user_meta_data->>'referralCode',
                500.00,
                'completed',
                timezone('utc'::text, now())
            );
            
            -- Add reward to referrer's balance
            UPDATE public.balances 
            SET dzd = dzd + 500.00,
                total_earned = total_earned + 500.00,
                updated_at = timezone('utc'::text, now())
            WHERE user_id = referrer_user_id;
            
            -- Update referrer's earnings
            UPDATE public.users 
            SET referral_earnings = referral_earnings + 500.00,
                updated_at = timezone('utc'::text, now())
            WHERE id = referrer_user_id;
            
            -- Create notification for referrer
            PERFORM public.create_notification(
                referrer_user_id,
                'success',
                'مكافأة إحالة جديدة! 🎉',
                'تم إضافة 500 دج إلى رصيدك بسبب إحالة مستخدم جديد. شكراً لك على دعم منصتنا!',
                'referral',
                2,
                '/referrals',
                'عرض الإحالات',
                json_build_object('reward_amount', 500.00, 'referred_user', NEW.email)
            );
            
            -- Create transaction record for referrer
            INSERT INTO public.transactions (
                user_id,
                type,
                category,
                amount,
                currency,
                description,
                reference,
                status,
                processed_at
            )
            VALUES (
                referrer_user_id,
                'reward',
                'general',
                500.00,
                'dzd',
                'مكافأة إحالة مستخدم جديد',
                'REF_' || NEW.id::text,
                'completed',
                timezone('utc'::text, now())
            );
        END IF;
    END IF;
    
    -- Create welcome notification for new user
    PERFORM public.create_notification(
        NEW.id,
        'success',
        'مرحباً بك في منصة NETLIFY! 🎉',
        format('أهلاً وسهلاً %s! تم إنشاء حسابك بنجاح. استمتع بجميع خدماتنا المصرفية الرقمية.', 
               COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'fullName', 'عزيزي العميل')),
        'account',
        3,
        '/home',
        'استكشف الخدمات',
        json_build_object('welcome_bonus', welcome_bonus, 'account_number', new_account_number)
    );
    
    -- Log security event for new registration
    PERFORM public.log_security_event(
        NEW.id,
        'login',
        'تسجيل مستخدم جديد في النظام',
        'info',
        NULL,
        NULL,
        json_build_object('registration_method', 'google_oauth', 'email_verified', NEW.email_confirmed_at IS NOT NULL)
    );
    
    -- Create welcome transaction record
    INSERT INTO public.transactions (
        user_id,
        type,
        category,
        amount,
        currency,
        description,
        reference,
        status,
        processed_at
    )
    VALUES (
        NEW.id,
        'reward',
        'general',
        welcome_bonus,
        'dzd',
        'مكافأة الترحيب للعضوية الجديدة',
        'WELCOME_' || NEW.id::text,
        'completed',
        timezone('utc'::text, now())
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- TRIGGERS SETUP
-- =============================================================================

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger for new user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

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

CREATE TRIGGER update_system_settings_updated_at 
    BEFORE UPDATE ON public.system_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

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
ALTER TABLE public.security_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- COMPREHENSIVE RLS POLICIES
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

-- Security logs table policies
DROP POLICY IF EXISTS "Users can view own security logs" ON public.security_logs;
CREATE POLICY "Users can view own security logs" ON public.security_logs
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert security logs" ON public.security_logs;
CREATE POLICY "System can insert security logs" ON public.security_logs
    FOR INSERT WITH CHECK (true);

-- System settings policies (public read access for public settings)
DROP POLICY IF EXISTS "Public can view public settings" ON public.system_settings;
CREATE POLICY "Public can view public settings" ON public.system_settings
    FOR SELECT USING (is_public = true);

-- =============================================================================
-- ENABLE REALTIME FOR ALL TABLES
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
ALTER PUBLICATION supabase_realtime ADD TABLE public.security_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.system_settings;

-- =============================================================================
-- INSERT DEFAULT SYSTEM SETTINGS
-- =============================================================================

INSERT INTO public.system_settings (key, value, description, category, is_public) VALUES
('app_name', '"NETLIFY"', 'اسم التطبيق', 'general', true),
('app_version', '"1.0.0"', 'إصدار التطبيق', 'general', true),
('maintenance_mode', 'false', 'وضع الصيانة', 'system', false),
('welcome_bonus', '100.00', 'مكافأة الترحيب للأعضاء الجدد', 'rewards', false),
('referral_reward', '500.00', 'مكافأة الإحالة', 'rewards', false),
('max_daily_transfer', '50000.00', 'الحد الأقصى للتحويل اليومي', 'limits', false),
('max_monthly_transfer', '500000.00', 'الحد الأقصى للتحويل الشهري', 'limits', false),
('supported_currencies', '["dzd", "eur", "usd", "gbp", "btc", "eth"]', 'العملات المدعومة', 'general', true),
('investment_rates', '{"weekly": 2.5, "monthly": 8.0, "quarterly": 12.0, "yearly": 15.0}', 'معدلات الاستثمار', 'investment', true),
('contact_email', '"support@netlify-bank.com"', 'بريد الدعم الفني', 'contact', true),
('contact_phone', '"+213-555-0123"', 'هاتف الدعم الفني', 'contact', true)
ON CONFLICT (key) DO NOTHING;

-- =============================================================================
-- MIGRATION COMPLETED SUCCESSFULLY
-- =============================================================================
-- Database setup completed with:
-- ✅ Enhanced tables with comprehensive fields
-- ✅ Performance indexes for optimal queries
-- ✅ Utility functions for common operations
-- ✅ Comprehensive user registration system
-- ✅ Automatic triggers for data consistency
-- ✅ Row Level Security policies
-- ✅ Realtime subscriptions enabled
-- ✅ Default system settings configured
-- ✅ Security logging system
-- ✅ Professional referral system
-- =============================================================================
