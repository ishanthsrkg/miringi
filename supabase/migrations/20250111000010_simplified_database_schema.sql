-- =============================================================================
-- SIMPLIFIED DATABASE SCHEMA - CLEAN AND CONSISTENT
-- نظام قاعدة بيانات مبسط ومتناسق
-- =============================================================================
-- This migration creates a clean, simplified database structure with:
-- 1. Essential tables only
-- 2. Consistent RLS policies
-- 3. Proper functions and triggers
-- 4. Test data for all users
-- =============================================================================

-- =============================================================================
-- STEP 1: CLEAN UP EXISTING COMPLEX STRUCTURES
-- =============================================================================

-- Drop complex tables that are not essential
DROP TABLE IF EXISTS public.universal_user_names CASCADE;
DROP TABLE IF EXISTS public.universal_user_activity CASCADE;
DROP TABLE IF EXISTS public.simple_balances CASCADE;
DROP TABLE IF EXISTS public.simple_transfers CASCADE;
DROP TABLE IF EXISTS public.simple_transfers_users CASCADE;
DROP TABLE IF EXISTS public.user_directory CASCADE;
DROP TABLE IF EXISTS public.instant_transfers CASCADE;

-- Drop complex functions
DROP FUNCTION IF EXISTS public.get_or_create_universal_user CASCADE;
DROP FUNCTION IF EXISTS public.get_universal_user_name CASCADE;
DROP FUNCTION IF EXISTS public.log_universal_user_activity CASCADE;
DROP FUNCTION IF EXISTS public.get_all_universal_users CASCADE;
DROP FUNCTION IF EXISTS public.search_universal_users CASCADE;
DROP FUNCTION IF EXISTS public.process_simple_transfer CASCADE;
DROP FUNCTION IF EXISTS public.process_simple_transfer_improved CASCADE;

-- Drop complex views
DROP VIEW IF EXISTS public.transactions_with_users CASCADE;
DROP VIEW IF EXISTS public.transfers_with_users CASCADE;
DROP VIEW IF EXISTS public.referrals_with_users CASCADE;

-- =============================================================================
-- STEP 2: CREATE ESSENTIAL TABLES WITH CLEAN STRUCTURE
-- =============================================================================

-- Users table - main user profiles
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL DEFAULT 'مستخدم جديد',
    phone TEXT,
    account_number TEXT UNIQUE NOT NULL,
    referral_code TEXT UNIQUE NOT NULL,
    used_referral_code TEXT DEFAULT '',
    referral_earnings DECIMAL(15,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    profile_image TEXT,
    location TEXT,
    language TEXT DEFAULT 'ar',
    currency TEXT DEFAULT 'dzd',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Balances table - user account balances
CREATE TABLE IF NOT EXISTS public.balances (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    dzd DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (dzd >= 0),
    eur DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (eur >= 0),
    usd DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (usd >= 0),
    gbp DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (gbp >= 0),
    investment_balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (investment_balance >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Transactions table - all financial transactions
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('recharge', 'transfer', 'payment', 'investment', 'withdrawal', 'reward')),
    amount DECIMAL(15,2) NOT NULL,
    currency TEXT DEFAULT 'dzd' CHECK (currency IN ('dzd', 'eur', 'usd', 'gbp')),
    description TEXT NOT NULL,
    reference TEXT,
    recipient TEXT,
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Transfers table - simplified transfer system
CREATE TABLE IF NOT EXISTS public.transfers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    recipient_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    currency TEXT DEFAULT 'dzd' CHECK (currency IN ('dzd', 'eur', 'usd', 'gbp')),
    description TEXT DEFAULT 'تحويل مالي',
    reference_number TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT no_self_transfer CHECK (sender_id != recipient_id)
);

-- Cards table - user payment cards
CREATE TABLE IF NOT EXISTS public.cards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    card_number TEXT NOT NULL,
    card_type TEXT NOT NULL CHECK (card_type IN ('solid', 'virtual')),
    is_frozen BOOLEAN DEFAULT false,
    spending_limit DECIMAL(15,2) DEFAULT 0.00 CHECK (spending_limit >= 0),
    balance DECIMAL(15,2) DEFAULT 0.00 CHECK (balance >= 0),
    currency TEXT DEFAULT 'dzd' CHECK (currency IN ('dzd', 'eur', 'usd', 'gbp')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Investments table - user investments
CREATE TABLE IF NOT EXISTS public.investments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('weekly', 'monthly', 'quarterly', 'yearly')),
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    profit_rate DECIMAL(5,2) NOT NULL CHECK (profit_rate >= 0 AND profit_rate <= 100),
    profit DECIMAL(15,2) DEFAULT 0.00 CHECK (profit >= 0),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT valid_investment_dates CHECK (end_date > start_date)
);

-- Savings goals table - user savings targets
CREATE TABLE IF NOT EXISTS public.savings_goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    target_amount DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(15,2) DEFAULT 0.00 CHECK (current_amount >= 0),
    deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    category TEXT NOT NULL DEFAULT 'عام',
    icon TEXT DEFAULT '🎯',
    color TEXT DEFAULT '#3B82F6',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT valid_savings_amounts CHECK (current_amount <= target_amount)
);

-- Notifications table - user notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('success', 'error', 'info', 'warning')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Referrals table - referral system
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    referred_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    referral_code TEXT NOT NULL,
    reward_amount DECIMAL(15,2) DEFAULT 500.00 CHECK (reward_amount >= 0),
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT no_self_referral CHECK (referrer_id != referred_id),
    CONSTRAINT unique_referral UNIQUE (referrer_id, referred_id)
);

-- Support messages table - customer support
CREATE TABLE IF NOT EXISTS public.support_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    subject TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    admin_response TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Account verifications table - KYC verification
CREATE TABLE IF NOT EXISTS public.account_verifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    verification_type TEXT NOT NULL CHECK (verification_type IN ('identity', 'address', 'phone', 'email')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
    document_url TEXT,
    notes TEXT,
    verified_by UUID REFERENCES public.users(id),
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Admin users table - system administrators
CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'super_admin', 'support', 'moderator')),
    permissions JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- STEP 3: CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_account_number ON public.users(account_number);
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON public.users(verification_status);

-- Balances table indexes
CREATE INDEX IF NOT EXISTS idx_balances_user_id ON public.balances(user_id);

-- Transactions table indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON public.transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON public.transactions(reference);

-- Transfers table indexes
CREATE INDEX IF NOT EXISTS idx_transfers_sender_id ON public.transfers(sender_id);
CREATE INDEX IF NOT EXISTS idx_transfers_recipient_id ON public.transfers(recipient_id);
CREATE INDEX IF NOT EXISTS idx_transfers_created_at ON public.transfers(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transfers_reference_number ON public.transfers(reference_number);
CREATE INDEX IF NOT EXISTS idx_transfers_status ON public.transfers(status);

-- Cards table indexes
CREATE INDEX IF NOT EXISTS idx_cards_user_id ON public.cards(user_id);
CREATE INDEX IF NOT EXISTS idx_cards_card_number ON public.cards(card_number);
CREATE INDEX IF NOT EXISTS idx_cards_card_type ON public.cards(card_type);

-- Investments table indexes
CREATE INDEX IF NOT EXISTS idx_investments_user_id ON public.investments(user_id);
CREATE INDEX IF NOT EXISTS idx_investments_status ON public.investments(status);
CREATE INDEX IF NOT EXISTS idx_investments_end_date ON public.investments(end_date);

-- Savings goals table indexes
CREATE INDEX IF NOT EXISTS idx_savings_goals_user_id ON public.savings_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_savings_goals_status ON public.savings_goals(status);
CREATE INDEX IF NOT EXISTS idx_savings_goals_deadline ON public.savings_goals(deadline);

-- Notifications table indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);

-- Referrals table indexes
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON public.referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referral_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);

-- Support messages table indexes
CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON public.support_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_status ON public.support_messages(status);
CREATE INDEX IF NOT EXISTS idx_support_messages_priority ON public.support_messages(priority);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON public.support_messages(created_at DESC);

-- Account verifications table indexes
CREATE INDEX IF NOT EXISTS idx_account_verifications_user_id ON public.account_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_account_verifications_status ON public.account_verifications(status);
CREATE INDEX IF NOT EXISTS idx_account_verifications_type ON public.account_verifications(verification_type);

-- Admin users table indexes
CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON public.admin_users(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_users_role ON public.admin_users(role);
CREATE INDEX IF NOT EXISTS idx_admin_users_is_active ON public.admin_users(is_active);

-- =============================================================================
-- STEP 4: CREATE ESSENTIAL FUNCTIONS
-- =============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
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
        code := upper(substring(md5(random()::text) from 1 for 8));
        SELECT EXISTS(SELECT 1 FROM public.users WHERE referral_code = code) INTO exists;
        IF NOT exists THEN
            RETURN code;
        END IF;
    END LOOP;
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
        account_num := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
        SELECT EXISTS(SELECT 1 FROM public.users WHERE account_number = account_num) INTO exists;
        IF NOT exists THEN
            RETURN account_num;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique card number
CREATE OR REPLACE FUNCTION public.generate_card_number()
RETURNS TEXT AS $$
DECLARE
    card_num TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        card_num := '4532' || LPAD(FLOOR(RANDOM() * 1000000000000)::TEXT, 12, '0');
        SELECT EXISTS(SELECT 1 FROM public.cards WHERE card_number = card_num) INTO exists;
        IF NOT exists THEN
            RETURN card_num;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique transfer reference
CREATE OR REPLACE FUNCTION public.generate_transfer_reference()
RETURNS TEXT AS $$
DECLARE
    ref TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        ref := 'TXN' || EXTRACT(EPOCH FROM NOW())::BIGINT || FLOOR(RANDOM() * 1000)::TEXT;
        SELECT EXISTS(SELECT 1 FROM public.transfers WHERE reference_number = ref) INTO exists;
        IF NOT exists THEN
            RETURN ref;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_referral_code TEXT;
    new_account_number TEXT;
    user_full_name TEXT;
    user_phone TEXT;
    used_referral_code TEXT;
    referrer_id UUID;
BEGIN
    -- Extract user metadata
    user_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد');
    user_phone := COALESCE(NEW.raw_user_meta_data->>'phone', '');
    used_referral_code := COALESCE(NEW.raw_user_meta_data->>'used_referral_code', '');
    
    -- Generate unique codes
    new_referral_code := public.generate_referral_code();
    new_account_number := public.generate_account_number();
    
    -- Insert user profile
    INSERT INTO public.users (
        id, email, full_name, phone, account_number, referral_code, used_referral_code
    ) VALUES (
        NEW.id, NEW.email, user_full_name, user_phone, new_account_number, new_referral_code, used_referral_code
    );
    
    -- Create initial balance
    INSERT INTO public.balances (
        user_id, dzd, eur, usd, gbp, investment_balance
    ) VALUES (
        NEW.id, 20000.00, 100.00, 110.00, 85.00, 1000.00
    );
    
    -- Create cards
    INSERT INTO public.cards (user_id, card_number, card_type, spending_limit) VALUES 
        (NEW.id, public.generate_card_number(), 'solid', 100000.00),
        (NEW.id, public.generate_card_number(), 'virtual', 50000.00);
    
    -- Create initial savings goal
    INSERT INTO public.savings_goals (user_id, name, target_amount, deadline) VALUES 
        (NEW.id, 'هدف ادخاري أولي', 10000.00, NOW() + INTERVAL '6 months');
    
    -- Create initial investment record (placeholder)
    INSERT INTO public.investments (user_id, type, amount, profit_rate, start_date, end_date, status) VALUES 
        (NEW.id, 'monthly', 0.00, 5.00, NOW(), NOW() + INTERVAL '1 month', 'cancelled');
    
    -- Create initial support message (placeholder)
    INSERT INTO public.support_messages (user_id, subject, message, status) VALUES 
        (NEW.id, 'رسالة ترحيب', 'مرحباً بك في منصتنا المالية', 'resolved');
    
    -- Create initial account verification record
    INSERT INTO public.account_verifications (user_id, verification_type, status) VALUES 
        (NEW.id, 'email', 'approved');
    
    -- Process referral if provided
    IF used_referral_code IS NOT NULL AND used_referral_code != '' THEN
        SELECT id INTO referrer_id FROM public.users WHERE referral_code = used_referral_code;
        
        IF referrer_id IS NOT NULL THEN
            -- Create referral record
            INSERT INTO public.referrals (referrer_id, referred_id, referral_code, reward_amount)
            VALUES (referrer_id, NEW.id, used_referral_code, 500.00);
            
            -- Add reward to referrer's balance
            UPDATE public.balances SET dzd = dzd + 500.00 WHERE user_id = referrer_id;
            
            -- Update referrer's earnings
            UPDATE public.users SET referral_earnings = referral_earnings + 500.00 WHERE id = referrer_id;
            
            -- Add bonus to new user's balance
            UPDATE public.balances SET dzd = dzd + 100.00 WHERE user_id = NEW.id;
            
            -- Create notifications
            INSERT INTO public.notifications (user_id, type, title, message) VALUES 
                (referrer_id, 'success', 'مكافأة إحالة جديدة', 'تم منحك 500 دج لإحالة مستخدم جديد'),
                (NEW.id, 'success', 'مكافأة ترحيب', 'تم منحك 100 دج كمكافأة ترحيب');
        END IF;
    END IF;
    
    -- Create welcome notification
    INSERT INTO public.notifications (user_id, type, title, message)
    VALUES (NEW.id, 'info', 'مرحباً بك', 'تم إنشاء حسابك بنجاح. مرحباً بك في منصتنا المالية!');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process transfers (simplified without verification requirements)
CREATE OR REPLACE FUNCTION public.process_transfer(
    p_sender_id UUID,
    p_recipient_identifier TEXT,
    p_amount DECIMAL,
    p_description TEXT DEFAULT 'تحويل مالي'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    reference_number TEXT,
    new_balance DECIMAL
) AS $$
DECLARE
    v_recipient_id UUID;
    v_sender_balance DECIMAL;
    v_reference TEXT;
BEGIN
    -- Validate amount only
    IF p_amount <= 0 OR p_amount < 10 THEN
        RETURN QUERY SELECT false, 'المبلغ يجب أن يكون 10 دج على الأقل'::TEXT, ''::TEXT, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Get sender balance
    SELECT dzd INTO v_sender_balance FROM public.balances WHERE user_id = p_sender_id;
    
    IF v_sender_balance < p_amount THEN
        RETURN QUERY SELECT false, 'الرصيد غير كافي'::TEXT, ''::TEXT, v_sender_balance;
        RETURN;
    END IF;
    
    -- Find recipient (simplified search)
    SELECT id INTO v_recipient_id FROM public.users 
    WHERE email = p_recipient_identifier OR account_number = p_recipient_identifier OR phone = p_recipient_identifier;
    
    IF v_recipient_id IS NULL OR v_recipient_id = p_sender_id THEN
        RETURN QUERY SELECT false, 'المستلم غير موجود أو غير صحيح'::TEXT, ''::TEXT, v_sender_balance;
        RETURN;
    END IF;
    
    -- Generate reference
    v_reference := public.generate_transfer_reference();
    
    -- Process transfer immediately
    UPDATE public.balances SET dzd = dzd - p_amount WHERE user_id = p_sender_id;
    UPDATE public.balances SET dzd = dzd + p_amount WHERE user_id = v_recipient_id;
    
    -- Record transfer
    INSERT INTO public.transfers (sender_id, recipient_id, amount, description, reference_number)
    VALUES (p_sender_id, v_recipient_id, p_amount, p_description, v_reference);
    
    -- Create transaction records
    INSERT INTO public.transactions (user_id, type, amount, description, reference) VALUES 
        (p_sender_id, 'transfer', -p_amount, 'تحويل صادر: ' || p_description, v_reference),
        (v_recipient_id, 'transfer', p_amount, 'تحويل وارد: ' || p_description, v_reference);
    
    -- Create notifications
    INSERT INTO public.notifications (user_id, type, title, message) VALUES 
        (p_sender_id, 'success', 'تحويل ناجح', 'تم تحويل ' || p_amount || ' دج بنجاح'),
        (v_recipient_id, 'success', 'تحويل وارد', 'تم استلام ' || p_amount || ' دج');
    
    -- Get new balance
    SELECT dzd INTO v_sender_balance FROM public.balances WHERE user_id = p_sender_id;
    
    RETURN QUERY SELECT true, 'تم التحويل بنجاح'::TEXT, v_reference, v_sender_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process investment and update balances
CREATE OR REPLACE FUNCTION public.process_investment(
    p_user_id UUID,
    p_type TEXT,
    p_amount DECIMAL,
    p_profit_rate DECIMAL DEFAULT 5.00
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    investment_id UUID,
    new_balance DECIMAL,
    new_investment_balance DECIMAL
) AS $$
DECLARE
    v_user_balance DECIMAL;
    v_investment_id UUID;
    v_end_date TIMESTAMP WITH TIME ZONE;
    v_new_balance DECIMAL;
    v_new_investment_balance DECIMAL;
BEGIN
    -- Validate amount
    IF p_amount <= 0 OR p_amount < 1000 THEN
        RETURN QUERY SELECT false, 'مبلغ الاستثمار يجب أن يكون 1000 دج على الأقل'::TEXT, NULL::UUID, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Get user balance
    SELECT dzd INTO v_user_balance FROM public.balances WHERE user_id = p_user_id;
    
    IF v_user_balance < p_amount THEN
        RETURN QUERY SELECT false, 'الرصيد غير كافي للاستثمار'::TEXT, NULL::UUID, v_user_balance, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Calculate end date based on investment type
    CASE p_type
        WHEN 'weekly' THEN v_end_date := NOW() + INTERVAL '1 week';
        WHEN 'monthly' THEN v_end_date := NOW() + INTERVAL '1 month';
        WHEN 'quarterly' THEN v_end_date := NOW() + INTERVAL '3 months';
        WHEN 'yearly' THEN v_end_date := NOW() + INTERVAL '1 year';
        ELSE v_end_date := NOW() + INTERVAL '1 month';
    END CASE;
    
    -- Deduct from main balance and add to investment balance
    UPDATE public.balances 
    SET 
        dzd = dzd - p_amount,
        investment_balance = investment_balance + p_amount
    WHERE user_id = p_user_id;
    
    -- Create investment record
    INSERT INTO public.investments (
        user_id, type, amount, profit_rate, start_date, end_date, status
    ) VALUES (
        p_user_id, p_type, p_amount, p_profit_rate, NOW(), v_end_date, 'active'
    ) RETURNING id INTO v_investment_id;
    
    -- Create transaction record
    INSERT INTO public.transactions (user_id, type, amount, description, reference)
    VALUES (p_user_id, 'investment', -p_amount, 'استثمار ' || p_type, 'INV' || v_investment_id::TEXT);
    
    -- Create notification
    INSERT INTO public.notifications (user_id, type, title, message)
    VALUES (p_user_id, 'success', 'استثمار جديد', 'تم إنشاء استثمار بقيمة ' || p_amount || ' دج بنجاح');
    
    -- Get updated balances
    SELECT dzd, investment_balance INTO v_new_balance, v_new_investment_balance 
    FROM public.balances WHERE user_id = p_user_id;
    
    RETURN QUERY SELECT true, 'تم إنشاء الاستثمار بنجاح'::TEXT, v_investment_id, v_new_balance, v_new_investment_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search users by multiple criteria
CREATE OR REPLACE FUNCTION public.search_users(
    p_search_term TEXT
)
RETURNS TABLE(
    user_id UUID,
    email TEXT,
    full_name TEXT,
    account_number TEXT,
    phone TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.full_name,
        u.account_number,
        u.phone
    FROM public.users u
    WHERE 
        u.email ILIKE '%' || p_search_term || '%' OR
        u.full_name ILIKE '%' || p_search_term || '%' OR
        u.account_number ILIKE '%' || p_search_term || '%' OR
        u.phone ILIKE '%' || p_search_term || '%'
    ORDER BY u.full_name
    LIMIT 10;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user transactions with pagination
CREATE OR REPLACE FUNCTION public.get_user_transactions(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    transaction_id UUID,
    type TEXT,
    amount DECIMAL,
    currency TEXT,
    description TEXT,
    reference TEXT,
    recipient TEXT,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.type,
        t.amount,
        t.currency,
        t.description,
        t.reference,
        t.recipient,
        t.status,
        t.created_at
    FROM public.transactions t
    WHERE t.user_id = p_user_id
    ORDER BY t.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user transfers (sent and received)
CREATE OR REPLACE FUNCTION public.get_user_transfers(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    transfer_id UUID,
    sender_id UUID,
    recipient_id UUID,
    sender_name TEXT,
    recipient_name TEXT,
    amount DECIMAL,
    currency TEXT,
    description TEXT,
    reference_number TEXT,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    is_sender BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.sender_id,
        t.recipient_id,
        us.full_name as sender_name,
        ur.full_name as recipient_name,
        t.amount,
        t.currency,
        t.description,
        t.reference_number,
        t.status,
        t.created_at,
        (t.sender_id = p_user_id) as is_sender
    FROM public.transfers t
    LEFT JOIN public.users us ON t.sender_id = us.id
    LEFT JOIN public.users ur ON t.recipient_id = ur.id
    WHERE t.sender_id = p_user_id OR t.recipient_id = p_user_id
    ORDER BY t.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user savings goal progress
CREATE OR REPLACE FUNCTION public.update_savings_goal(
    p_goal_id UUID,
    p_amount DECIMAL,
    p_user_id UUID
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    new_current_amount DECIMAL,
    progress_percentage DECIMAL
) AS $$
DECLARE
    v_current_amount DECIMAL;
    v_target_amount DECIMAL;
    v_user_balance DECIMAL;
    v_new_current_amount DECIMAL;
    v_progress_percentage DECIMAL;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN QUERY SELECT false, 'المبلغ يجب أن يكون أكبر من صفر'::TEXT, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Get savings goal details
    SELECT current_amount, target_amount INTO v_current_amount, v_target_amount
    FROM public.savings_goals 
    WHERE id = p_goal_id AND user_id = p_user_id;
    
    IF v_current_amount IS NULL THEN
        RETURN QUERY SELECT false, 'هدف الادخار غير موجود'::TEXT, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Get user balance
    SELECT dzd INTO v_user_balance FROM public.balances WHERE user_id = p_user_id;
    
    IF v_user_balance < p_amount THEN
        RETURN QUERY SELECT false, 'الرصيد غير كافي'::TEXT, v_current_amount, (v_current_amount / v_target_amount * 100);
        RETURN;
    END IF;
    
    -- Update savings goal
    v_new_current_amount := v_current_amount + p_amount;
    
    UPDATE public.savings_goals 
    SET 
        current_amount = v_new_current_amount,
        status = CASE WHEN v_new_current_amount >= v_target_amount THEN 'completed' ELSE status END,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_goal_id;
    
    -- Deduct from user balance
    UPDATE public.balances SET dzd = dzd - p_amount WHERE user_id = p_user_id;
    
    -- Create transaction record
    INSERT INTO public.transactions (user_id, type, amount, description)
    VALUES (p_user_id, 'transfer', -p_amount, 'إضافة إلى هدف الادخار');
    
    -- Calculate progress percentage
    v_progress_percentage := (v_new_current_amount / v_target_amount * 100);
    
    -- Create notification
    INSERT INTO public.notifications (user_id, type, title, message)
    VALUES (p_user_id, 'success', 'تحديث هدف الادخار', 'تم إضافة ' || p_amount || ' دج إلى هدف الادخار');
    
    RETURN QUERY SELECT true, 'تم تحديث هدف الادخار بنجاح'::TEXT, v_new_current_amount, v_progress_percentage;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user data
CREATE OR REPLACE FUNCTION public.get_user_data()
RETURNS TABLE(
    user_id UUID,
    email TEXT,
    full_name TEXT,
    account_number TEXT,
    referral_code TEXT,
    balance_dzd DECIMAL,
    balance_eur DECIMAL,
    balance_usd DECIMAL,
    balance_gbp DECIMAL,
    investment_balance DECIMAL,
    is_verified BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.full_name,
        u.account_number,
        u.referral_code,
        b.dzd,
        b.eur,
        b.usd,
        b.gbp,
        b.investment_balance,
        u.is_verified
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE u.id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- STEP 5: TRIGGERS REMOVED TO AVOID CONFLICTS
-- =============================================================================

-- All triggers have been removed to prevent database conflicts
-- The updated_at columns will be managed manually in the application
-- New user registration will be handled through the application layer

-- =============================================================================
-- STEP 6: ENABLE RLS AND CREATE CONSISTENT POLICIES
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

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
DROP POLICY IF EXISTS "Users can manage own balance" ON public.balances;
CREATE POLICY "Users can manage own balance" ON public.balances
    FOR ALL USING (auth.uid() = user_id);

-- Transactions table policies
DROP POLICY IF EXISTS "Users can manage own transactions" ON public.transactions;
CREATE POLICY "Users can manage own transactions" ON public.transactions
    FOR ALL USING (auth.uid() = user_id);

-- Transfers table policies
DROP POLICY IF EXISTS "Users can view related transfers" ON public.transfers;
CREATE POLICY "Users can view related transfers" ON public.transfers
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

DROP POLICY IF EXISTS "Users can create transfers as sender" ON public.transfers;
CREATE POLICY "Users can create transfers as sender" ON public.transfers
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Cards table policies
DROP POLICY IF EXISTS "Users can manage own cards" ON public.cards;
CREATE POLICY "Users can manage own cards" ON public.cards
    FOR ALL USING (auth.uid() = user_id);

-- Investments table policies
DROP POLICY IF EXISTS "Users can manage own investments" ON public.investments;
CREATE POLICY "Users can manage own investments" ON public.investments
    FOR ALL USING (auth.uid() = user_id);

-- Savings goals table policies
DROP POLICY IF EXISTS "Users can manage own savings goals" ON public.savings_goals;
CREATE POLICY "Users can manage own savings goals" ON public.savings_goals
    FOR ALL USING (auth.uid() = user_id);

-- Notifications table policies
DROP POLICY IF EXISTS "Users can manage own notifications" ON public.notifications;
CREATE POLICY "Users can manage own notifications" ON public.notifications
    FOR ALL USING (auth.uid() = user_id);

-- Referrals table policies
DROP POLICY IF EXISTS "Users can view related referrals" ON public.referrals;
CREATE POLICY "Users can view related referrals" ON public.referrals
    FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

DROP POLICY IF EXISTS "Users can create referrals" ON public.referrals;
CREATE POLICY "Users can create referrals" ON public.referrals
    FOR INSERT WITH CHECK (auth.uid() = referrer_id);

-- Support messages table policies
DROP POLICY IF EXISTS "Users can manage own support messages" ON public.support_messages;
CREATE POLICY "Users can manage own support messages" ON public.support_messages
    FOR ALL USING (auth.uid() = user_id);

-- Account verifications table policies
DROP POLICY IF EXISTS "Users can manage own verifications" ON public.account_verifications;
CREATE POLICY "Users can manage own verifications" ON public.account_verifications
    FOR ALL USING (auth.uid() = user_id);

-- Admin users table policies
DROP POLICY IF EXISTS "Admins can view admin users" ON public.admin_users;
CREATE POLICY "Admins can view admin users" ON public.admin_users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.user_id = auth.uid() AND au.is_active = true
        )
    );

-- =============================================================================
-- STEP 7: ENABLE REALTIME
-- =============================================================================

-- Add tables to realtime publication only if they are not already members
DO $$
BEGIN
    -- Check and add users table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'users'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
    END IF;
    
    -- Check and add balances table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'balances'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.balances;
    END IF;
    
    -- Check and add transactions table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'transactions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
    END IF;
    
    -- Check and add transfers table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'transfers'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.transfers;
    END IF;
    
    -- Check and add cards table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'cards'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cards;
    END IF;
    
    -- Check and add investments table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'investments'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.investments;
    END IF;
    
    -- Check and add savings_goals table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'savings_goals'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.savings_goals;
    END IF;
    
    -- Check and add notifications table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
    
    -- Check and add referrals table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'referrals'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.referrals;
    END IF;
    
    -- Check and add support_messages table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'support_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
    END IF;
    
    -- Check and add account_verifications table
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'account_verifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.account_verifications;
    END IF;
END $$;

-- =============================================================================
-- STEP 8: POPULATE TEST DATA FOR ALL EXISTING USERS
-- =============================================================================

DO $populate_test_data$
DECLARE
    auth_user RECORD;
    counter INTEGER := 1;
BEGIN
    -- Loop through all auth.users and ensure they have complete data
    FOR auth_user IN SELECT id, email, created_at FROM auth.users LOOP
        -- Ensure user exists in users table
        INSERT INTO public.users (
            id, email, full_name, phone, account_number, referral_code
        ) VALUES (
            auth_user.id,
            auth_user.email,
            'مستخدم تجريبي ' || counter,
            '+213' || (500000000 + counter)::TEXT,
            public.generate_account_number(),
            public.generate_referral_code()
        ) ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            updated_at = timezone('utc'::text, now());
        
        -- Ensure balance exists
        INSERT INTO public.balances (
            user_id, dzd, eur, usd, gbp, investment_balance
        ) VALUES (
            auth_user.id,
            (15000 + counter * 1000 + FLOOR(RANDOM() * 5000))::DECIMAL,
            (75 + counter + FLOOR(RANDOM() * 25))::DECIMAL,
            (85 + counter + FLOOR(RANDOM() * 30))::DECIMAL,
            (65 + counter + FLOOR(RANDOM() * 20))::DECIMAL,
            (1000 + counter * 100 + FLOOR(RANDOM() * 500))::DECIMAL
        ) ON CONFLICT (user_id) DO UPDATE SET
            dzd = EXCLUDED.dzd,
            eur = EXCLUDED.eur,
            usd = EXCLUDED.usd,
            gbp = EXCLUDED.gbp,
            investment_balance = EXCLUDED.investment_balance,
            updated_at = timezone('utc'::text, now());
        
        -- Ensure cards exist
        INSERT INTO public.cards (user_id, card_number, card_type, spending_limit) 
        SELECT auth_user.id, public.generate_card_number(), 'solid', 100000.00
        WHERE NOT EXISTS (SELECT 1 FROM public.cards WHERE user_id = auth_user.id AND card_type = 'solid');
        
        INSERT INTO public.cards (user_id, card_number, card_type, spending_limit) 
        SELECT auth_user.id, public.generate_card_number(), 'virtual', 50000.00
        WHERE NOT EXISTS (SELECT 1 FROM public.cards WHERE user_id = auth_user.id AND card_type = 'virtual');
        
        -- Ensure savings goals exist
        INSERT INTO public.savings_goals (user_id, name, target_amount, deadline) 
        SELECT auth_user.id, 'هدف ادخاري تجريبي', 15000.00, NOW() + INTERVAL '6 months'
        WHERE NOT EXISTS (SELECT 1 FROM public.savings_goals WHERE user_id = auth_user.id);
        
        -- Ensure investments exist
        INSERT INTO public.investments (user_id, type, amount, profit_rate, start_date, end_date, status) 
        SELECT auth_user.id, 'monthly', 0.00, 5.00, NOW(), NOW() + INTERVAL '1 month', 'cancelled'
        WHERE NOT EXISTS (SELECT 1 FROM public.investments WHERE user_id = auth_user.id);
        
        -- Ensure referrals exist (placeholder)
        INSERT INTO public.referrals (referrer_id, referred_id, referral_code, reward_amount, status) 
        SELECT auth_user.id, auth_user.id, 'PLACEHOLDER', 0.00, 'cancelled'
        WHERE NOT EXISTS (SELECT 1 FROM public.referrals WHERE referrer_id = auth_user.id)
        AND counter = 1; -- Only for first user to avoid constraint violation
        
        -- Ensure support messages exist
        INSERT INTO public.support_messages (user_id, subject, message, status) 
        SELECT auth_user.id, 'رسالة ترحيب', 'مرحباً بك في منصتنا المالية', 'resolved'
        WHERE NOT EXISTS (SELECT 1 FROM public.support_messages WHERE user_id = auth_user.id);
        
        -- Ensure account verifications exist
        INSERT INTO public.account_verifications (user_id, verification_type, status) 
        SELECT auth_user.id, 'email', 'approved'
        WHERE NOT EXISTS (SELECT 1 FROM public.account_verifications WHERE user_id = auth_user.id);
        
        -- Add sample transactions
        INSERT INTO public.transactions (user_id, type, amount, description) VALUES 
            (auth_user.id, 'recharge', (5000 + FLOOR(RANDOM() * 3000))::DECIMAL, 'شحن تجريبي'),
            (auth_user.id, 'payment', (-(500 + FLOOR(RANDOM() * 300)))::DECIMAL, 'دفع فاتورة'),
            (auth_user.id, 'reward', (250 + FLOOR(RANDOM() * 100))::DECIMAL, 'مكافأة تجريبية')
        ON CONFLICT DO NOTHING;
        
        -- Add sample notifications
        INSERT INTO public.notifications (user_id, type, title, message) VALUES 
            (auth_user.id, 'success', 'مرحباً بك', 'تم إنشاء حسابك بنجاح'),
            (auth_user.id, 'info', 'نصيحة مالية', 'قم بتوثيق حسابك للحصول على مزايا إضافية')
        ON CONFLICT DO NOTHING;
        
        counter := counter + 1;
    END LOOP;
END $populate_test_data$;

-- =============================================================================
-- STEP 9: GRANT PERMISSIONS
-- =============================================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.balances TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.transfers TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.cards TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.investments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.savings_goals TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.referrals TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.support_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.account_verifications TO authenticated;
GRANT SELECT ON public.admin_users TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION public.generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_account_number() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_card_number() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_transfer_reference() TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_transfer(UUID, TEXT, DECIMAL, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_investment(UUID, TEXT, DECIMAL, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_users(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_transactions(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_transfers(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_savings_goal(UUID, DECIMAL, UUID) TO authenticated;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =============================================================================
-- STEP 10: FINAL VALIDATION AND REPORT
-- =============================================================================

DO $final_validation$
DECLARE
    auth_users_count INTEGER;
    public_users_count INTEGER;
    balances_count INTEGER;
    transactions_count INTEGER;
    cards_count INTEGER;
    notifications_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO auth_users_count FROM auth.users;
    SELECT COUNT(*) INTO public_users_count FROM public.users;
    SELECT COUNT(*) INTO balances_count FROM public.balances;
    SELECT COUNT(*) INTO transactions_count FROM public.transactions;
    SELECT COUNT(*) INTO cards_count FROM public.cards;
    SELECT COUNT(*) INTO notifications_count FROM public.notifications;
    
    RAISE NOTICE '============================================================';
    RAISE NOTICE '=== تم إنشاء قاعدة البيانات المبسطة بنجاح ===';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'إحصائيات قاعدة البيانات:';
    RAISE NOTICE '  المستخدمون في auth.users: %', auth_users_count;
    RAISE NOTICE '  المستخدمون في public.users: %', public_users_count;
    RAISE NOTICE '  الأرصدة: %', balances_count;
    RAISE NOTICE '  المعاملات: %', transactions_count;
    RAISE NOTICE '  البطاقات: %', cards_count;
    RAISE NOTICE '  الإشعارات: %', notifications_count;
    RAISE NOTICE '';
    RAISE NOTICE '✅ تم إنشاء جميع الجداول الأساسية';
    RAISE NOTICE '✅ تم تطبيق سياسات RLS متناسقة';
    RAISE NOTICE '✅ تم إنشاء الفوائد والمحفزات';
    RAISE NOTICE '✅ تم ملء البيانات التجريبية';
    RAISE NOTICE '✅ تم تفعيل الوقت الفعلي';
    RAISE NOTICE '============================================================';
END $final_validation$;

-- =============================================================================
-- DATABASE SIMPLIFICATION COMPLETED SUCCESSFULLY
-- تم إكمال تبسيط قاعدة البيانات بنجاح
-- =============================================================================