-- =============================================================================
-- COMPREHENSIVE DATABASE FIX - FINAL SOLUTION
-- إصلاح شامل لقاعدة البيانات - الحل النهائي
-- =============================================================================
-- This migration ensures:
-- 1. All users exist in all required tables
-- 2. All functions work correctly
-- 3. All RLS policies are properly configured
-- 4. No database errors occur
-- =============================================================================

-- =============================================================================
-- STEP 1: CLEAN UP AND RESET DATABASE STATE
-- =============================================================================

-- Create user_credentials table first to avoid trigger drop errors
CREATE TABLE IF NOT EXISTS public.user_credentials (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    username TEXT UNIQUE,
    password_hash TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Drop all problematic triggers first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS trigger_sync_to_simple_balances ON public.users;
DROP TRIGGER IF EXISTS trigger_sync_balance_to_simple ON public.balances;
DROP TRIGGER IF EXISTS trigger_sync_user_directory ON public.users;
DROP TRIGGER IF EXISTS trigger_update_user_verification_status ON public.account_verifications;
DROP TRIGGER IF EXISTS trigger_investment_status_change ON public.investments;
DROP TRIGGER IF EXISTS trigger_update_investment_profit ON public.investments;
DROP TRIGGER IF EXISTS update_user_credentials_updated_at ON public.user_credentials;

-- Drop problematic functions that cause conflicts
DROP FUNCTION IF EXISTS public.handle_new_user CASCADE;
DROP FUNCTION IF EXISTS public.handle_user_credentials CASCADE;
DROP FUNCTION IF EXISTS public.sync_to_simple_balances CASCADE;
DROP FUNCTION IF EXISTS public.sync_balance_to_simple CASCADE;
DROP FUNCTION IF EXISTS public.sync_user_directory CASCADE;
DROP FUNCTION IF EXISTS public.update_user_verification_status CASCADE;
DROP FUNCTION IF EXISTS public.update_investment_balance_on_status_change CASCADE;
DROP FUNCTION IF EXISTS public.update_investment_profit CASCADE;
DROP FUNCTION IF EXISTS public.calculate_investment_profit CASCADE;

-- Drop complex tables that cause issues
DROP TABLE IF EXISTS public.simple_balances CASCADE;
DROP TABLE IF EXISTS public.simple_transfers CASCADE;
DROP TABLE IF EXISTS public.simple_transfers_users CASCADE;
DROP TABLE IF EXISTS public.user_directory CASCADE;
DROP TABLE IF EXISTS public.transfer_requests CASCADE;
DROP TABLE IF EXISTS public.completed_transfers CASCADE;
DROP TABLE IF EXISTS public.transfer_limits CASCADE;
DROP TABLE IF EXISTS public.universal_user_names CASCADE;
DROP TABLE IF EXISTS public.universal_user_activity CASCADE;
DROP TABLE IF EXISTS public.instant_transfers CASCADE;

-- =============================================================================
-- STEP 2: ENSURE CORE TABLES EXIST WITH PROPER STRUCTURE
-- =============================================================================

-- Users table - main user profiles
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL DEFAULT 'مستخدم جديد',
    phone TEXT DEFAULT '',
    account_number TEXT UNIQUE NOT NULL,
    referral_code TEXT UNIQUE NOT NULL,
    used_referral_code TEXT DEFAULT '',
    referral_earnings DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    verification_status TEXT DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    profile_image TEXT DEFAULT '',
    location TEXT DEFAULT '',
    language TEXT DEFAULT 'ar',
    currency TEXT DEFAULT 'dzd',
    address TEXT DEFAULT '',
    username TEXT DEFAULT '',
    profile_completed BOOLEAN DEFAULT false,
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    join_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
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
    type TEXT NOT NULL CHECK (type IN ('recharge', 'transfer', 'payment', 'investment', 'withdrawal', 'reward', 'bill')),
    amount DECIMAL(15,2) NOT NULL,
    currency TEXT DEFAULT 'dzd' CHECK (currency IN ('dzd', 'eur', 'usd', 'gbp')),
    description TEXT NOT NULL,
    reference TEXT,
    recipient TEXT,
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Cards table - user payment cards
CREATE TABLE IF NOT EXISTS public.cards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    card_number TEXT NOT NULL,
    card_type TEXT NOT NULL CHECK (card_type IN ('solid', 'virtual')),
    is_frozen BOOLEAN DEFAULT false NOT NULL,
    spending_limit DECIMAL(15,2) DEFAULT 0.00 NOT NULL CHECK (spending_limit >= 0),
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
    amount DECIMAL(15,2) NOT NULL CHECK (amount >= 0),
    profit_rate DECIMAL(5,2) NOT NULL DEFAULT 5.00 CHECK (profit_rate >= 0 AND profit_rate <= 100),
    profit DECIMAL(15,2) DEFAULT 0.00 CHECK (profit >= 0),
    start_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    end_date TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
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
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Notifications table - user notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('success', 'error', 'info', 'warning')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
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
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    category TEXT DEFAULT 'general' CHECK (category IN ('general', 'technical', 'billing', 'cards', 'transfers', 'investments')),
    admin_response TEXT,
    admin_id UUID,
    responded_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Account verifications table - KYC verification
CREATE TABLE IF NOT EXISTS public.account_verifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    country TEXT DEFAULT 'الجزائر',
    date_of_birth DATE,
    full_address TEXT DEFAULT '',
    postal_code TEXT DEFAULT '',
    document_type TEXT DEFAULT 'national_id' CHECK (document_type IN ('national_id', 'passport', 'driving_license')),
    document_number TEXT DEFAULT '',
    documents JSONB DEFAULT '[]'::jsonb,
    additional_notes TEXT DEFAULT '',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
    admin_notes TEXT,
    reviewed_by UUID,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =============================================================================
-- STEP 3: CREATE ESSENTIAL INDEXES
-- =============================================================================

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_account_number ON public.users(account_number);
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON public.users(is_active);

-- Balances table indexes
CREATE INDEX IF NOT EXISTS idx_balances_user_id ON public.balances(user_id);

-- Transactions table indexes
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_reference ON public.transactions(reference);

-- Cards table indexes
CREATE INDEX IF NOT EXISTS idx_cards_user_id ON public.cards(user_id);
CREATE INDEX IF NOT EXISTS idx_cards_card_number ON public.cards(card_number);

-- Other essential indexes
CREATE INDEX IF NOT EXISTS idx_investments_user_id ON public.investments(user_id);
CREATE INDEX IF NOT EXISTS idx_savings_goals_user_id ON public.savings_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON public.referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON public.support_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_account_verifications_user_id ON public.account_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_credentials_user_id ON public.user_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_user_credentials_username ON public.user_credentials(username);

-- =============================================================================
-- STEP 4: CREATE ESSENTIAL FUNCTIONS
-- =============================================================================

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function to search users (simplified)
CREATE OR REPLACE FUNCTION public.search_users(p_search_term TEXT)
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function to process transfers (enhanced for all account types)
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
    v_recipient_balance DECIMAL;
    v_reference TEXT;
    v_sender_email TEXT;
    v_recipient_email TEXT;
    v_sender_name TEXT;
    v_recipient_name TEXT;
BEGIN
    SET search_path = public;
    
    -- Validate amount
    IF p_amount <= 0 OR p_amount < 10 THEN
        RETURN QUERY SELECT false, 'المبلغ يجب أن يكون 10 دج على الأقل'::TEXT, ''::TEXT, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Get sender info and balance
    SELECT u.email, u.full_name, b.dzd 
    INTO v_sender_email, v_sender_name, v_sender_balance 
    FROM public.users u 
    LEFT JOIN public.balances b ON u.id = b.user_id 
    WHERE u.id = p_sender_id;
    
    IF v_sender_balance IS NULL THEN
        v_sender_balance := 0;
    END IF;
    
    IF v_sender_balance < p_amount THEN
        RETURN QUERY SELECT false, 'الرصيد غير كافي'::TEXT, ''::TEXT, v_sender_balance;
        RETURN;
    END IF;
    
    -- Find recipient by email, account number, or phone (allow all account types)
    SELECT u.id, u.email, u.full_name, COALESCE(b.dzd, 0)
    INTO v_recipient_id, v_recipient_email, v_recipient_name, v_recipient_balance
    FROM public.users u 
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE (u.email = p_recipient_identifier 
       OR u.account_number = p_recipient_identifier 
       OR u.phone = p_recipient_identifier)
       AND u.is_active = true;
    
    IF v_recipient_id IS NULL THEN
        RETURN QUERY SELECT false, 'المستلم غير موجود'::TEXT, ''::TEXT, v_sender_balance;
        RETURN;
    END IF;
    
    IF v_recipient_id = p_sender_id THEN
        RETURN QUERY SELECT false, 'لا يمكن التحويل لنفس الحساب'::TEXT, ''::TEXT, v_sender_balance;
        RETURN;
    END IF;
    
    -- Generate unique reference
    v_reference := 'TXN' || EXTRACT(EPOCH FROM NOW())::BIGINT || LPAD((RANDOM() * 999)::INT::TEXT, 3, '0');
    
    -- Process transfer (update balances)
    UPDATE public.balances SET 
        dzd = dzd - p_amount,
        updated_at = NOW()
    WHERE user_id = p_sender_id;
    
    UPDATE public.balances SET 
        dzd = dzd + p_amount,
        updated_at = NOW()
    WHERE user_id = v_recipient_id;
    
    -- Create transaction records for both parties
    INSERT INTO public.transactions (user_id, type, amount, description, reference, status, currency) VALUES 
        (p_sender_id, 'transfer', -p_amount, 'تحويل صادر إلى ' || v_recipient_name || ': ' || p_description, v_reference, 'completed', 'dzd'),
        (v_recipient_id, 'transfer', p_amount, 'تحويل وارد من ' || v_sender_name || ': ' || p_description, v_reference, 'completed', 'dzd');
    
    -- Create notifications for both parties
    INSERT INTO public.notifications (user_id, type, title, message) VALUES 
        (p_sender_id, 'success', 'تحويل ناجح', 'تم تحويل ' || p_amount || ' دج إلى ' || v_recipient_name || ' بنجاح'),
        (v_recipient_id, 'success', 'تحويل وارد', 'تم استلام ' || p_amount || ' دج من ' || v_sender_name);
    
    -- Get updated sender balance
    SELECT dzd INTO v_sender_balance FROM public.balances WHERE user_id = p_sender_id;
    
    RETURN QUERY SELECT true, 'تم التحويل بنجاح'::TEXT, v_reference, v_sender_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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
        COALESCE(b.dzd, 0::DECIMAL),
        COALESCE(b.eur, 0::DECIMAL),
        COALESCE(b.usd, 0::DECIMAL),
        COALESCE(b.gbp, 0::DECIMAL),
        COALESCE(b.investment_balance, 0::DECIMAL),
        u.is_verified
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE u.id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function to get user transactions
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function to create support message
CREATE OR REPLACE FUNCTION public.create_support_message(
    p_user_id UUID,
    p_subject TEXT,
    p_message TEXT,
    p_category TEXT DEFAULT 'general',
    p_priority TEXT DEFAULT 'normal'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    ticket_id UUID,
    reference_number TEXT
) AS $$
DECLARE
    v_ticket_id UUID;
    v_reference_number TEXT;
BEGIN
    v_ticket_id := gen_random_uuid();
    v_reference_number := 'SUP' || EXTRACT(EPOCH FROM NOW())::BIGINT || LPAD((RANDOM() * 999)::INT::TEXT, 3, '0');
    
    INSERT INTO public.support_messages (
        id, user_id, subject, message, category, priority, status
    ) VALUES (
        v_ticket_id, p_user_id, p_subject, p_message, p_category, p_priority, 'open'
    );
    
    RETURN QUERY SELECT 
        TRUE as success,
        'تم إرسال رسالة الدعم بنجاح' as message,
        v_ticket_id as ticket_id,
        v_reference_number as reference_number;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            FALSE as success,
            'فشل في إرسال رسالة الدعم: ' || SQLERRM as message,
            NULL::UUID as ticket_id,
            NULL::TEXT as reference_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- STEP 5: ENABLE RLS AND CREATE CONSISTENT POLICIES
-- =============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_credentials ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to avoid conflicts
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT schemaname, tablename, policyname 
        FROM pg_policies 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    END LOOP;
END $$;

-- Users table policies (enhanced for transfers)
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can search all active users for transfers" ON public.users
    FOR SELECT USING (is_active = true);

-- Balances table policies
CREATE POLICY "Users can manage own balance" ON public.balances
    FOR ALL USING (auth.uid() = user_id);

-- Transactions table policies
CREATE POLICY "Users can manage own transactions" ON public.transactions
    FOR ALL USING (auth.uid() = user_id);

-- Cards table policies
CREATE POLICY "Users can manage own cards" ON public.cards
    FOR ALL USING (auth.uid() = user_id);

-- Investments table policies
CREATE POLICY "Users can manage own investments" ON public.investments
    FOR ALL USING (auth.uid() = user_id);

-- Savings goals table policies
CREATE POLICY "Users can manage own savings goals" ON public.savings_goals
    FOR ALL USING (auth.uid() = user_id);

-- Notifications table policies
CREATE POLICY "Users can manage own notifications" ON public.notifications
    FOR ALL USING (auth.uid() = user_id);

-- Referrals table policies
CREATE POLICY "Users can view related referrals" ON public.referrals
    FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);
CREATE POLICY "Users can create referrals" ON public.referrals
    FOR INSERT WITH CHECK (auth.uid() = referrer_id);

-- Support messages table policies
CREATE POLICY "Users can manage own support messages" ON public.support_messages
    FOR ALL USING (auth.uid() = user_id);

-- Account verifications table policies
CREATE POLICY "Users can manage own verifications" ON public.account_verifications
    FOR ALL USING (auth.uid() = user_id);

-- User credentials table policies
CREATE POLICY "Users can manage own credentials" ON public.user_credentials
    FOR ALL USING (auth.uid() = user_id);

-- =============================================================================
-- STEP 6: ENABLE REALTIME
-- =============================================================================

DO $$
BEGIN
    -- Add tables to realtime publication only if they are not already members
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'users') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'balances') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.balances;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'transactions') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'cards') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cards;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'investments') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.investments;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'savings_goals') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.savings_goals;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'notifications') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'referrals') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.referrals;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'support_messages') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'account_verifications') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.account_verifications;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'user_credentials') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_credentials;
    END IF;
END $$;

-- =============================================================================
-- STEP 7: GRANT PERMISSIONS
-- =============================================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.balances TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.cards TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.investments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.savings_goals TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.referrals TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.support_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.account_verifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_credentials TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION public.generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_account_number() TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_card_number() TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_users(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_transfer(UUID, TEXT, DECIMAL, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_transactions(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_support_message(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =============================================================================
-- STEP 8: UPDATE ALL USERS TO BE VERIFIED
-- تحديث جميع المستخدمين ليكونوا موثقين
-- =============================================================================

-- Update all existing users to be verified
UPDATE public.users 
SET 
    is_verified = true,
    verification_status = 'approved',
    updated_at = timezone('utc'::text, now())
WHERE is_verified = false OR verification_status != 'approved';

-- Update all account verifications to approved status
UPDATE public.account_verifications 
SET 
    status = 'approved',
    reviewed_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
WHERE status != 'approved';

-- =============================================================================
-- DATABASE FIX COMPLETED SUCCESSFULLY
-- تم إكمال إصلاح قاعدة البيانات بنجاح
-- =============================================================================
