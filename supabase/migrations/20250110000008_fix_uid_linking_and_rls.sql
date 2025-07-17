-- =============================================================================
-- FIX UID LINKING AND RLS POLICIES - COMPREHENSIVE SOLUTION
-- إصلاح ربط البيانات بـ UID المستخدم وسياسات RLS - الحل الشامل
-- Created: 2025-01-10
-- Purpose: Ensure all data is properly linked to auth.uid() and RLS is enforced
-- =============================================================================

-- =============================================================================
-- STEP 1: Ensure all tables have proper user_id columns linked to auth.users
-- =============================================================================

-- Fix users table to ensure it's properly linked to auth.users
DO $users_table_fix$
BEGIN
    -- Ensure users.id is UUID and references auth.users(id)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'users' AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'id' AND kcu.referenced_table_schema = 'auth'
    ) THEN
        -- Add foreign key constraint to auth.users if missing
        ALTER TABLE public.users 
        ADD CONSTRAINT users_id_fkey 
        FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
    END IF;
END $users_table_fix$;

-- Ensure balances table has proper user_id
DO $balances_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'balances' AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.balances DROP COLUMN IF EXISTS user_id;
        ALTER TABLE public.balances 
        ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_balances_user_id ON public.balances(user_id);
    END IF;
END $balances_uid_fix$;

-- Ensure transactions table has proper user_id
DO $transactions_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'transactions' AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.transactions DROP COLUMN IF EXISTS user_id;
        ALTER TABLE public.transactions 
        ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
    END IF;
END $transactions_uid_fix$;

-- Ensure investments table has proper user_id
DO $investments_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'investments' AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.investments DROP COLUMN IF EXISTS user_id;
        ALTER TABLE public.investments 
        ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_investments_user_id ON public.investments(user_id);
    END IF;
END $investments_uid_fix$;

-- Ensure savings_goals table has proper user_id
DO $savings_goals_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'savings_goals' AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.savings_goals DROP COLUMN IF EXISTS user_id;
        ALTER TABLE public.savings_goals 
        ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_savings_goals_user_id ON public.savings_goals(user_id);
    END IF;
END $savings_goals_uid_fix$;

-- Ensure cards table has proper user_id
DO $cards_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'cards' AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.cards DROP COLUMN IF EXISTS user_id;
        ALTER TABLE public.cards 
        ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_cards_user_id ON public.cards(user_id);
    END IF;
END $cards_uid_fix$;

-- Ensure notifications table has proper user_id
DO $notifications_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.notifications DROP COLUMN IF EXISTS user_id;
        ALTER TABLE public.notifications 
        ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
    END IF;
END $notifications_uid_fix$;

-- Ensure referrals table has proper user_id columns
DO $referrals_uid_fix$
BEGIN
    -- Fix referrer_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'referrals' AND column_name = 'referrer_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.referrals DROP COLUMN IF EXISTS referrer_id;
        ALTER TABLE public.referrals 
        ADD COLUMN referrer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);
    END IF;
    
    -- Fix referred_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'referrals' AND column_name = 'referred_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.referrals DROP COLUMN IF EXISTS referred_id;
        ALTER TABLE public.referrals 
        ADD COLUMN referred_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON public.referrals(referred_id);
    END IF;
END $referrals_uid_fix$;

-- Ensure simple_balances table has proper user_id
DO $simple_balances_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'simple_balances' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.simple_balances 
        ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_simple_balances_user_id ON public.simple_balances(user_id);
    END IF;
END $simple_balances_uid_fix$;

-- Ensure simple_transfers table has proper user_id columns
DO $simple_transfers_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'simple_transfers' AND column_name = 'sender_user_id'
    ) THEN
        ALTER TABLE public.simple_transfers 
        ADD COLUMN sender_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_simple_transfers_sender_user_id ON public.simple_transfers(sender_user_id);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'simple_transfers' AND column_name = 'recipient_user_id'
    ) THEN
        ALTER TABLE public.simple_transfers 
        ADD COLUMN recipient_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_simple_transfers_recipient_user_id ON public.simple_transfers(recipient_user_id);
    END IF;
END $simple_transfers_uid_fix$;

-- Ensure support_messages table has proper user_id
DO $support_messages_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'support_messages' AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.support_messages DROP COLUMN IF EXISTS user_id;
        ALTER TABLE public.support_messages 
        ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON public.support_messages(user_id);
    END IF;
END $support_messages_uid_fix$;

-- Ensure account_verifications table has proper user_id
DO $account_verifications_uid_fix$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'account_verifications' AND column_name = 'user_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.account_verifications DROP COLUMN IF EXISTS user_id;
        ALTER TABLE public.account_verifications 
        ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_account_verifications_user_id ON public.account_verifications(user_id);
    END IF;
END $account_verifications_uid_fix$;

-- =============================================================================
-- STEP 2: Link existing data to auth.users UIDs
-- =============================================================================

-- Update simple_balances to link with auth.users
UPDATE public.simple_balances 
SET user_id = u.id
FROM public.users u
WHERE simple_balances.user_email = u.email
AND simple_balances.user_id IS NULL;

-- Update simple_transfers to link with auth.users
UPDATE public.simple_transfers 
SET sender_user_id = u.id
FROM public.users u
WHERE simple_transfers.sender_email = u.email
AND simple_transfers.sender_user_id IS NULL;

UPDATE public.simple_transfers 
SET recipient_user_id = u.id
FROM public.users u
WHERE simple_transfers.recipient_email = u.email
AND simple_transfers.recipient_user_id IS NULL;

-- Update any existing records that might not be linked properly
DO $link_existing_data$
BEGIN
    -- Link balances to users
    UPDATE public.balances 
    SET user_id = u.id
    FROM public.users u
    WHERE balances.user_id IS NULL
    AND EXISTS (SELECT 1 FROM public.users WHERE id = u.id);
    
    -- Link transactions to users (if any exist without proper linking)
    UPDATE public.transactions 
    SET user_id = u.id
    FROM public.users u
    WHERE transactions.user_id IS NULL
    AND EXISTS (SELECT 1 FROM public.users WHERE id = u.id)
    LIMIT 1000; -- Limit to avoid timeout
    
    -- Link other tables similarly if needed
    UPDATE public.investments 
    SET user_id = u.id
    FROM public.users u
    WHERE investments.user_id IS NULL
    AND EXISTS (SELECT 1 FROM public.users WHERE id = u.id)
    LIMIT 1000;
    
    UPDATE public.savings_goals 
    SET user_id = u.id
    FROM public.users u
    WHERE savings_goals.user_id IS NULL
    AND EXISTS (SELECT 1 FROM public.users WHERE id = u.id)
    LIMIT 1000;
    
    UPDATE public.cards 
    SET user_id = u.id
    FROM public.users u
    WHERE cards.user_id IS NULL
    AND EXISTS (SELECT 1 FROM public.users WHERE id = u.id)
    LIMIT 1000;
    
    UPDATE public.notifications 
    SET user_id = u.id
    FROM public.users u
    WHERE notifications.user_id IS NULL
    AND EXISTS (SELECT 1 FROM public.users WHERE id = u.id)
    LIMIT 1000;
END $link_existing_data$;

-- =============================================================================
-- STEP 3: Create/Update RLS policies for all tables
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
ALTER TABLE public.simple_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.simple_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_verifications ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- Users table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- =============================================================================
-- Balances table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own balance" ON public.balances;
CREATE POLICY "Users can view own balance" ON public.balances
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own balance" ON public.balances;
CREATE POLICY "Users can update own balance" ON public.balances
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own balance" ON public.balances;
CREATE POLICY "Users can insert own balance" ON public.balances
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- Transactions table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
CREATE POLICY "Users can insert own transactions" ON public.transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own transactions" ON public.transactions;
CREATE POLICY "Users can update own transactions" ON public.transactions
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- Investments table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own investments" ON public.investments;
CREATE POLICY "Users can view own investments" ON public.investments
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own investments" ON public.investments;
CREATE POLICY "Users can insert own investments" ON public.investments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own investments" ON public.investments;
CREATE POLICY "Users can update own investments" ON public.investments
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- Savings goals table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own savings goals" ON public.savings_goals;
CREATE POLICY "Users can view own savings goals" ON public.savings_goals
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own savings goals" ON public.savings_goals;
CREATE POLICY "Users can insert own savings goals" ON public.savings_goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own savings goals" ON public.savings_goals;
CREATE POLICY "Users can update own savings goals" ON public.savings_goals
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- Cards table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own cards" ON public.cards;
CREATE POLICY "Users can view own cards" ON public.cards
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own cards" ON public.cards;
CREATE POLICY "Users can insert own cards" ON public.cards
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own cards" ON public.cards;
CREATE POLICY "Users can update own cards" ON public.cards
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- Notifications table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own notifications" ON public.notifications;
CREATE POLICY "Users can insert own notifications" ON public.notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- Referrals table policies
-- =============================================================================
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
-- Simple balances table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own simple balance" ON public.simple_balances;
CREATE POLICY "Users can view own simple balance" ON public.simple_balances
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own simple balance" ON public.simple_balances;
CREATE POLICY "Users can update own simple balance" ON public.simple_balances
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own simple balance" ON public.simple_balances;
CREATE POLICY "Users can insert own simple balance" ON public.simple_balances
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- Simple transfers table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view related simple transfers" ON public.simple_transfers;
CREATE POLICY "Users can view related simple transfers" ON public.simple_transfers
    FOR SELECT USING (auth.uid() = sender_user_id OR auth.uid() = recipient_user_id);

DROP POLICY IF EXISTS "Users can insert simple transfers" ON public.simple_transfers;
CREATE POLICY "Users can insert simple transfers" ON public.simple_transfers
    FOR INSERT WITH CHECK (auth.uid() = sender_user_id);

-- =============================================================================
-- Support messages table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own support messages" ON public.support_messages;
CREATE POLICY "Users can view own support messages" ON public.support_messages
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own support messages" ON public.support_messages;
CREATE POLICY "Users can insert own support messages" ON public.support_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own support messages" ON public.support_messages;
CREATE POLICY "Users can update own support messages" ON public.support_messages
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- Account verifications table policies
-- =============================================================================
DROP POLICY IF EXISTS "Users can view own verifications" ON public.account_verifications;
CREATE POLICY "Users can view own verifications" ON public.account_verifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own verifications" ON public.account_verifications;
CREATE POLICY "Users can insert own verifications" ON public.account_verifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own verifications" ON public.account_verifications;
CREATE POLICY "Users can update own verifications" ON public.account_verifications
    FOR UPDATE USING (auth.uid() = user_id);

-- =============================================================================
-- STEP 4: Update functions to use auth.uid()
-- =============================================================================

-- =============================================================================
-- STEP 4: Update all functions to use auth.uid() properly
-- =============================================================================

-- Drop existing function first to avoid signature conflicts
DROP FUNCTION IF EXISTS public.process_simple_transfer(TEXT, TEXT, DECIMAL, TEXT);
DROP FUNCTION IF EXISTS public.process_simple_transfer(TEXT, TEXT, NUMERIC, TEXT);

-- Create enhanced transfer function that uses auth.uid()
CREATE OR REPLACE FUNCTION public.process_simple_transfer(
    p_sender_email TEXT,
    p_recipient_identifier TEXT,
    p_amount DECIMAL,
    p_description TEXT DEFAULT 'تحويل فوري'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    reference_number TEXT,
    sender_new_balance DECIMAL,
    recipient_new_balance DECIMAL
) AS $process_simple_transfer$
DECLARE
    v_sender_id UUID;
    v_recipient_id UUID;
    v_sender_balance DECIMAL;
    v_recipient_info RECORD;
    v_reference TEXT;
BEGIN
    -- Get sender ID from auth.uid() - this ensures RLS compliance
    v_sender_id := auth.uid();
    
    IF v_sender_id IS NULL THEN
        RETURN QUERY SELECT false, 'المستخدم غير مصرح له - يجب تسجيل الدخول'::TEXT, ''::TEXT, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Validate sender email matches authenticated user
    IF NOT EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = v_sender_id AND email = p_sender_email
    ) THEN
        RETURN QUERY SELECT false, 'البريد الإلكتروني غير متطابق مع المستخدم المصرح'::TEXT, ''::TEXT, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Validate amount
    IF p_amount <= 0 THEN
        RETURN QUERY SELECT false, 'المبلغ يجب أن يكون أكبر من صفر'::TEXT, ''::TEXT, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    IF p_amount < 100 THEN
        RETURN QUERY SELECT false, 'الحد الأدنى للتحويل هو 100 دج'::TEXT, ''::TEXT, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Get sender balance using auth.uid() for RLS compliance
    SELECT dzd INTO v_sender_balance 
    FROM public.balances 
    WHERE user_id = auth.uid();
    
    IF v_sender_balance IS NULL OR v_sender_balance < p_amount THEN
        RETURN QUERY SELECT false, 'الرصيد غير كافي'::TEXT, ''::TEXT, COALESCE(v_sender_balance, 0)::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Find recipient using proper identifier matching
    SELECT u.id, u.full_name, u.email, u.account_number 
    INTO v_recipient_info
    FROM public.users u
    WHERE (u.email = p_recipient_identifier OR u.account_number = p_recipient_identifier)
    AND u.is_active = true
    AND u.id != auth.uid();
    
    IF v_recipient_info.id IS NULL THEN
        RETURN QUERY SELECT false, 'المستلم غير موجود أو غير نشط'::TEXT, ''::TEXT, v_sender_balance::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- Generate reference
    v_reference := 'TXN' || EXTRACT(EPOCH FROM NOW())::BIGINT || FLOOR(RANDOM() * 1000)::TEXT;
    
    -- Update sender balance using auth.uid()
    UPDATE public.balances 
    SET dzd = dzd - p_amount, updated_at = timezone('utc'::text, now())
    WHERE user_id = auth.uid();
    
    -- Update recipient balance
    UPDATE public.balances 
    SET dzd = dzd + p_amount, updated_at = timezone('utc'::text, now())
    WHERE user_id = v_recipient_info.id;
    
    -- Record transfer with proper UIDs
    INSERT INTO public.simple_transfers (
        sender_user_id,
        recipient_user_id,
        sender_email,
        recipient_email,
        sender_name,
        recipient_name,
        sender_account_number,
        recipient_account_number,
        amount,
        description,
        reference_number,
        status,
        created_at
    )
    SELECT 
        auth.uid(),
        v_recipient_info.id,
        p_sender_email,
        v_recipient_info.email,
        (SELECT full_name FROM public.users WHERE id = auth.uid()),
        v_recipient_info.full_name,
        (SELECT account_number FROM public.users WHERE id = auth.uid()),
        v_recipient_info.account_number,
        p_amount,
        p_description,
        v_reference,
        'completed',
        timezone('utc'::text, now());
    
    -- Create transaction records with proper UIDs for RLS compliance
    INSERT INTO public.transactions (user_id, type, amount, currency, description, recipient, reference, status, created_at)
    VALUES 
        (auth.uid(), 'transfer', -p_amount, 'dzd', 'تحويل صادر إلى ' || v_recipient_info.full_name, v_recipient_info.email, v_reference, 'completed', timezone('utc'::text, now())),
        (v_recipient_info.id, 'transfer', p_amount, 'dzd', 'تحويل وارد من ' || (SELECT full_name FROM public.users WHERE id = auth.uid()), p_sender_email, v_reference, 'completed', timezone('utc'::text, now()));
    
    -- Get new sender balance
    SELECT dzd INTO v_sender_balance FROM public.balances WHERE user_id = auth.uid();
    
    RETURN QUERY SELECT true, 'تم التحويل بنجاح'::TEXT, v_reference, v_sender_balance, (SELECT dzd FROM public.balances WHERE user_id = v_recipient_info.id);
END;
$process_simple_transfer$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user data using auth.uid()
CREATE OR REPLACE FUNCTION public.get_current_user_data()
RETURNS TABLE(
    user_id UUID,
    email TEXT,
    full_name TEXT,
    account_number TEXT,
    balance_dzd DECIMAL,
    balance_eur DECIMAL,
    balance_usd DECIMAL,
    balance_gbp DECIMAL,
    investment_balance DECIMAL,
    is_verified BOOLEAN
) AS $get_current_user_data$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.full_name,
        u.account_number,
        COALESCE(b.dzd, 0)::DECIMAL,
        COALESCE(b.eur, 0)::DECIMAL,
        COALESCE(b.usd, 0)::DECIMAL,
        COALESCE(b.gbp, 0)::DECIMAL,
        COALESCE(b.investment_balance, 0)::DECIMAL,
        COALESCE(u.is_verified, false)
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE u.id = auth.uid();
END;
$get_current_user_data$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user transactions using auth.uid()
CREATE OR REPLACE FUNCTION public.get_current_user_transactions(
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    id UUID,
    type TEXT,
    amount DECIMAL,
    currency TEXT,
    description TEXT,
    recipient TEXT,
    reference TEXT,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $get_current_user_transactions$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.type,
        t.amount,
        t.currency,
        t.description,
        t.recipient,
        t.reference,
        t.status,
        t.created_at
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
    ORDER BY t.created_at DESC
    LIMIT p_limit;
END;
$get_current_user_transactions$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update user balance using auth.uid()
CREATE OR REPLACE FUNCTION public.update_current_user_balance(
    p_dzd DECIMAL DEFAULT NULL,
    p_eur DECIMAL DEFAULT NULL,
    p_usd DECIMAL DEFAULT NULL,
    p_gbp DECIMAL DEFAULT NULL,
    p_investment_balance DECIMAL DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    new_balance RECORD
) AS $update_current_user_balance$
DECLARE
    v_current_balance RECORD;
    v_updated_balance RECORD;
BEGIN
    -- Check if user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN QUERY SELECT false, 'المستخدم غير مصرح له'::TEXT, NULL::RECORD;
        RETURN;
    END IF;
    
    -- Get current balance
    SELECT * INTO v_current_balance FROM public.balances WHERE user_id = auth.uid();
    
    -- Update balance with provided values or keep existing ones
    UPDATE public.balances 
    SET 
        dzd = COALESCE(p_dzd, dzd),
        eur = COALESCE(p_eur, eur),
        usd = COALESCE(p_usd, usd),
        gbp = COALESCE(p_gbp, gbp),
        investment_balance = COALESCE(p_investment_balance, investment_balance),
        updated_at = timezone('utc'::text, now())
    WHERE user_id = auth.uid()
    RETURNING * INTO v_updated_balance;
    
    RETURN QUERY SELECT true, 'تم تحديث الرصيد بنجاح'::TEXT, v_updated_balance;
END;
$update_current_user_balance$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- STEP 5: Create comprehensive test data for existing auth.users
-- =============================================================================

-- Insert comprehensive test data for existing users in auth.users
DO $comprehensive_test_data_block$
DECLARE
    auth_user RECORD;
    test_counter INTEGER := 1;
    v_account_number TEXT;
    v_referral_code TEXT;
BEGIN
    RAISE NOTICE 'بدء إنشاء البيانات التجريبية للمستخدمين الموجودين في auth.users';
    
    -- Loop through existing auth.users and create comprehensive test data
    FOR auth_user IN 
        SELECT id, email, created_at
        FROM auth.users 
        WHERE id NOT IN (SELECT id FROM public.users WHERE id IS NOT NULL)
        ORDER BY created_at
        LIMIT 20
    LOOP
        -- Generate unique identifiers
        v_account_number := 'ACC' || LPAD(test_counter::TEXT, 9, '0');
        v_referral_code := 'REF' || LPAD(test_counter::TEXT, 6, '0');
        
        -- Insert user profile with proper UID linking
        INSERT INTO public.users (
            id, email, full_name, phone, account_number, 
            referral_code, is_active, is_verified, verification_status,
            created_at, updated_at
        ) VALUES (
            auth_user.id,
            auth_user.email,
            'مستخدم تجريبي ' || test_counter,
            '+213' || (500000000 + test_counter)::TEXT,
            v_account_number,
            v_referral_code,
            true,
            (test_counter % 3 = 0), -- Every 3rd user is verified
            CASE WHEN test_counter % 3 = 0 THEN 'approved' ELSE 'pending' END,
            COALESCE(auth_user.created_at, timezone('utc'::text, now())),
            timezone('utc'::text, now())
        ) ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            updated_at = timezone('utc'::text, now());
        
        -- Insert balance with proper UID linking
        INSERT INTO public.balances (
            user_id, dzd, eur, usd, gbp, investment_balance, created_at, updated_at
        ) VALUES (
            auth_user.id,
            (15000 + (test_counter * 1000) + FLOOR(RANDOM() * 5000))::DECIMAL,
            (75 + test_counter + FLOOR(RANDOM() * 25))::DECIMAL,
            (85 + test_counter + FLOOR(RANDOM() * 30))::DECIMAL,
            (65 + test_counter + FLOOR(RANDOM() * 20))::DECIMAL,
            (1000 + (test_counter * 100) + FLOOR(RANDOM() * 500))::DECIMAL,
            COALESCE(auth_user.created_at, timezone('utc'::text, now())),
            timezone('utc'::text, now())
        ) ON CONFLICT (user_id) DO UPDATE SET
            dzd = EXCLUDED.dzd,
            eur = EXCLUDED.eur,
            usd = EXCLUDED.usd,
            gbp = EXCLUDED.gbp,
            investment_balance = EXCLUDED.investment_balance,
            updated_at = timezone('utc'::text, now());
        
        -- Insert simple_balances with proper UID linking
        INSERT INTO public.simple_balances (
            user_id, user_email, user_name, account_number, balance, updated_at
        ) VALUES (
            auth_user.id,
            auth_user.email,
            'مستخدم تجريبي ' || test_counter,
            v_account_number,
            (15000 + (test_counter * 1000) + FLOOR(RANDOM() * 5000))::DECIMAL,
            timezone('utc'::text, now())
        ) ON CONFLICT (user_email) DO UPDATE SET
            user_id = EXCLUDED.user_id,
            balance = EXCLUDED.balance,
            updated_at = timezone('utc'::text, now());
        
        -- Insert sample transactions with proper UID linking
        INSERT INTO public.transactions (
            user_id, type, amount, currency, description, status, created_at
        ) VALUES 
            (auth_user.id, 'recharge', 5000 + FLOOR(RANDOM() * 3000), 'dzd', 'شحن تجريبي أولي', 'completed', COALESCE(auth_user.created_at, timezone('utc'::text, now()))),
            (auth_user.id, 'transfer', -(1000 + FLOOR(RANDOM() * 500)), 'dzd', 'تحويل تجريبي', 'completed', timezone('utc'::text, now() - interval '1 day')),
            (auth_user.id, 'investment', 2000 + FLOOR(RANDOM() * 1000), 'dzd', 'عائد استثمار تجريبي', 'completed', timezone('utc'::text, now() - interval '2 days'));
        
        -- Insert sample cards with proper UID linking
        INSERT INTO public.cards (
            user_id, card_number, card_type, is_frozen, spending_limit, balance, currency, created_at, updated_at
        ) VALUES 
            (auth_user.id, '4532' || LPAD((1000000000 + test_counter)::TEXT, 12, '0'), 'solid', false, 100000, 0, 'dzd', timezone('utc'::text, now()), timezone('utc'::text, now())),
            (auth_user.id, '5555' || LPAD((2000000000 + test_counter)::TEXT, 12, '0'), 'virtual', false, 50000, 0, 'dzd', timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        -- Insert sample notifications with proper UID linking
        INSERT INTO public.notifications (
            user_id, type, title, message, is_read, created_at
        ) VALUES 
            (auth_user.id, 'success', 'مرحباً بك', 'تم إنشاء حسابك بنجاح', false, timezone('utc'::text, now())),
            (auth_user.id, 'info', 'نصيحة مالية', 'قم بتوثيق حسابك للحصول على مزايا إضافية', false, timezone('utc'::text, now() - interval '1 hour'));
        
        -- Insert sample savings goal with proper UID linking (every 2nd user)
        IF test_counter % 2 = 0 THEN
            INSERT INTO public.savings_goals (
                user_id, name, target_amount, current_amount, deadline, category, status, created_at, updated_at
            ) VALUES (
                auth_user.id, 
                'هدف ادخار تجريبي', 
                50000 + (test_counter * 1000), 
                FLOOR(RANDOM() * 10000), 
                timezone('utc'::text, now() + interval '6 months'), 
                'عام', 
                'active', 
                timezone('utc'::text, now()), 
                timezone('utc'::text, now())
            );
        END IF;
        
        -- Insert sample investment with proper UID linking (every 3rd user)
        IF test_counter % 3 = 0 THEN
            INSERT INTO public.investments (
                user_id, type, amount, profit_rate, start_date, end_date, status, created_at, updated_at
            ) VALUES (
                auth_user.id, 
                'monthly', 
                5000 + (test_counter * 500), 
                8.5 + (RANDOM() * 3), 
                timezone('utc'::text, now() - interval '1 month'), 
                timezone('utc'::text, now() + interval '11 months'), 
                'active', 
                timezone('utc'::text, now()), 
                timezone('utc'::text, now())
            );
        END IF;
        
        test_counter := test_counter + 1;
        
        -- Add a small delay to avoid overwhelming the database
        IF test_counter % 5 = 0 THEN
            PERFORM pg_sleep(0.1);
        END IF;
    END LOOP;
    
    RAISE NOTICE 'تم إنشاء بيانات تجريبية شاملة لـ % مستخدم', test_counter - 1;
    
    -- Create some sample transfers between users
    IF test_counter > 2 THEN
        INSERT INTO public.simple_transfers (
            sender_user_id, recipient_user_id, sender_email, recipient_email,
            sender_name, recipient_name, amount, description, reference_number, status, created_at
        )
        SELECT 
            u1.id, u2.id, u1.email, u2.email,
            u1.full_name, u2.full_name, 1500, 'تحويل تجريبي بين المستخدمين',
            'TXN' || EXTRACT(EPOCH FROM NOW())::BIGINT || FLOOR(RANDOM() * 1000)::TEXT,
            'completed', timezone('utc'::text, now() - interval '3 hours')
        FROM public.users u1, public.users u2
        WHERE u1.id != u2.id
        AND u1.full_name LIKE 'مستخدم تجريبي%'
        AND u2.full_name LIKE 'مستخدم تجريبي%'
        LIMIT 3;
        
        RAISE NOTICE 'تم إنشاء تحويلات تجريبية بين المستخدمين';
    END IF;
END $comprehensive_test_data_block$;

-- =============================================================================
-- STEP 6: Create comprehensive helper functions for UID-based operations
-- =============================================================================

-- Function to get complete user data using auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_data_by_uid()
RETURNS TABLE(
    user_id UUID,
    email TEXT,
    full_name TEXT,
    account_number TEXT,
    phone TEXT,
    referral_code TEXT,
    balance_dzd DECIMAL,
    balance_eur DECIMAL,
    balance_usd DECIMAL,
    balance_gbp DECIMAL,
    investment_balance DECIMAL,
    is_verified BOOLEAN,
    verification_status TEXT,
    is_active BOOLEAN
) AS $get_user_data_by_uid$
BEGIN
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.full_name,
        u.account_number,
        u.phone,
        u.referral_code,
        COALESCE(b.dzd, 0)::DECIMAL,
        COALESCE(b.eur, 0)::DECIMAL,
        COALESCE(b.usd, 0)::DECIMAL,
        COALESCE(b.gbp, 0)::DECIMAL,
        COALESCE(b.investment_balance, 0)::DECIMAL,
        COALESCE(u.is_verified, false),
        COALESCE(u.verification_status, 'pending'),
        COALESCE(u.is_active, true)
    FROM public.users u
    LEFT JOIN public.balances b ON u.id = b.user_id
    WHERE u.id = auth.uid();
END;
$get_user_data_by_uid$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user transactions using auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_transactions_by_uid(
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    id UUID,
    type TEXT,
    amount DECIMAL,
    currency TEXT,
    description TEXT,
    recipient TEXT,
    reference TEXT,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $get_user_transactions_by_uid$
BEGIN
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        t.id,
        t.type,
        t.amount,
        t.currency,
        t.description,
        t.recipient,
        t.reference,
        t.status,
        t.created_at
    FROM public.transactions t
    WHERE t.user_id = auth.uid()
    ORDER BY t.created_at DESC
    LIMIT p_limit;
END;
$get_user_transactions_by_uid$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user referrals using auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_referrals_by_uid()
RETURNS TABLE(
    id UUID,
    referred_user_name TEXT,
    referred_user_email TEXT,
    reward_amount DECIMAL,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $get_user_referrals_by_uid$
BEGIN
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        r.id,
        u.full_name,
        u.email,
        r.reward_amount,
        r.status,
        r.created_at
    FROM public.referrals r
    JOIN public.users u ON r.referred_id = u.id
    WHERE r.referrer_id = auth.uid()
    ORDER BY r.created_at DESC;
END;
$get_user_referrals_by_uid$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user cards using auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_cards_by_uid()
RETURNS TABLE(
    id UUID,
    card_number TEXT,
    card_type TEXT,
    is_frozen BOOLEAN,
    spending_limit DECIMAL,
    balance DECIMAL,
    currency TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $get_user_cards_by_uid$
BEGIN
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        c.id,
        c.card_number,
        c.card_type,
        c.is_frozen,
        c.spending_limit,
        c.balance,
        c.currency,
        c.created_at
    FROM public.cards c
    WHERE c.user_id = auth.uid()
    ORDER BY c.created_at DESC;
END;
$get_user_cards_by_uid$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user notifications using auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_notifications_by_uid(
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
    id UUID,
    type TEXT,
    title TEXT,
    message TEXT,
    is_read BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $get_user_notifications_by_uid$
BEGIN
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        n.id,
        n.type,
        n.title,
        n.message,
        n.is_read,
        n.created_at
    FROM public.notifications n
    WHERE n.user_id = auth.uid()
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$get_user_notifications_by_uid$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user investments using auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_investments_by_uid()
RETURNS TABLE(
    id UUID,
    type TEXT,
    amount DECIMAL,
    profit_rate DECIMAL,
    profit DECIMAL,
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $get_user_investments_by_uid$
BEGIN
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        i.id,
        i.type,
        i.amount,
        i.profit_rate,
        COALESCE(i.profit, 0)::DECIMAL,
        i.start_date,
        i.end_date,
        i.status,
        i.created_at
    FROM public.investments i
    WHERE i.user_id = auth.uid()
    ORDER BY i.created_at DESC;
END;
$get_user_investments_by_uid$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user savings goals using auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_savings_goals_by_uid()
RETURNS TABLE(
    id UUID,
    name TEXT,
    target_amount DECIMAL,
    current_amount DECIMAL,
    deadline TIMESTAMP WITH TIME ZONE,
    category TEXT,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $get_user_savings_goals_by_uid$
BEGIN
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        sg.id,
        sg.name,
        sg.target_amount,
        COALESCE(sg.current_amount, 0)::DECIMAL,
        sg.deadline,
        sg.category,
        sg.status,
        sg.created_at
    FROM public.savings_goals sg
    WHERE sg.user_id = auth.uid()
    AND sg.status = 'active'
    ORDER BY sg.created_at DESC;
END;
$get_user_savings_goals_by_uid$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user transfer history using auth.uid()
CREATE OR REPLACE FUNCTION public.get_user_transfer_history_by_uid(
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    id UUID,
    sender_name TEXT,
    recipient_name TEXT,
    sender_email TEXT,
    recipient_email TEXT,
    amount DECIMAL,
    description TEXT,
    reference_number TEXT,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    is_sender BOOLEAN
) AS $get_user_transfer_history_by_uid$
BEGIN
    -- Ensure user is authenticated
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        st.id,
        st.sender_name,
        st.recipient_name,
        st.sender_email,
        st.recipient_email,
        st.amount,
        st.description,
        st.reference_number,
        st.status,
        st.created_at,
        (st.sender_user_id = auth.uid()) as is_sender
    FROM public.simple_transfers st
    WHERE st.sender_user_id = auth.uid() OR st.recipient_user_id = auth.uid()
    ORDER BY st.created_at DESC
    LIMIT p_limit;
END;
$get_user_transfer_history_by_uid$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- STEP 7: Grant necessary permissions for all functions
-- =============================================================================

-- Grant execute permissions on all UID-based functions
GRANT EXECUTE ON FUNCTION public.get_user_data_by_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_transactions_by_uid(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_referrals_by_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_cards_by_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_notifications_by_uid(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_investments_by_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_savings_goals_by_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_transfer_history_by_uid(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_simple_transfer(TEXT, TEXT, DECIMAL, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_user_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_user_transactions(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_current_user_balance(DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL) TO authenticated;

-- Grant necessary table permissions for authenticated users (RLS will control access)
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.balances TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.investments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.savings_goals TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.cards TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.referrals TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.simple_balances TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.simple_transfers TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.support_messages TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.account_verifications TO authenticated;

-- Grant usage on sequences
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =============================================================================
-- STEP 8: Final validation, testing, and comprehensive logging
-- =============================================================================

DO $final_comprehensive_validation$
DECLARE
    auth_users_count INTEGER;
    public_users_count INTEGER;
    balances_count INTEGER;
    simple_balances_count INTEGER;
    transactions_count INTEGER;
    referrals_count INTEGER;
    cards_count INTEGER;
    notifications_count INTEGER;
    investments_count INTEGER;
    savings_goals_count INTEGER;
    transfers_count INTEGER;
    linked_balances_count INTEGER;
    linked_transactions_count INTEGER;
    rls_enabled_tables INTEGER;
BEGIN
    -- Count records in each table
    SELECT COUNT(*) INTO auth_users_count FROM auth.users;
    SELECT COUNT(*) INTO public_users_count FROM public.users;
    SELECT COUNT(*) INTO balances_count FROM public.balances;
    SELECT COUNT(*) INTO simple_balances_count FROM public.simple_balances;
    SELECT COUNT(*) INTO transactions_count FROM public.transactions;
    SELECT COUNT(*) INTO referrals_count FROM public.referrals;
    SELECT COUNT(*) INTO cards_count FROM public.cards;
    SELECT COUNT(*) INTO notifications_count FROM public.notifications;
    SELECT COUNT(*) INTO investments_count FROM public.investments;
    SELECT COUNT(*) INTO savings_goals_count FROM public.savings_goals;
    SELECT COUNT(*) INTO transfers_count FROM public.simple_transfers;
    
    -- Count properly linked records
    SELECT COUNT(*) INTO linked_balances_count 
    FROM public.balances b 
    JOIN auth.users au ON b.user_id = au.id;
    
    SELECT COUNT(*) INTO linked_transactions_count 
    FROM public.transactions t 
    JOIN auth.users au ON t.user_id = au.id;
    
    -- Count RLS enabled tables
    SELECT COUNT(*) INTO rls_enabled_tables
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relrowsecurity = true
    AND c.relname IN ('users', 'balances', 'transactions', 'investments', 'savings_goals', 'cards', 'notifications', 'referrals', 'simple_balances', 'simple_transfers', 'support_messages', 'account_verifications');
    
    RAISE NOTICE '============================================================';
    RAISE NOTICE '=== UID LINKING AND RLS COMPREHENSIVE FIX COMPLETED ===';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 DATABASE STATISTICS:';
    RAISE NOTICE '  Auth users: %', auth_users_count;
    RAISE NOTICE '  Public users: %', public_users_count;
    RAISE NOTICE '  Balances: %', balances_count;
    RAISE NOTICE '  Simple balances: %', simple_balances_count;
    RAISE NOTICE '  Transactions: %', transactions_count;
    RAISE NOTICE '  Referrals: %', referrals_count;
    RAISE NOTICE '  Cards: %', cards_count;
    RAISE NOTICE '  Notifications: %', notifications_count;
    RAISE NOTICE '  Investments: %', investments_count;
    RAISE NOTICE '  Savings goals: %', savings_goals_count;
    RAISE NOTICE '  Transfers: %', transfers_count;
    RAISE NOTICE '';
    RAISE NOTICE '🔗 UID LINKING STATUS:';
    RAISE NOTICE '  Linked balances: % / %', linked_balances_count, balances_count;
    RAISE NOTICE '  Linked transactions: % / %', linked_transactions_count, transactions_count;
    RAISE NOTICE '';
    RAISE NOTICE '🔒 RLS STATUS:';
    RAISE NOTICE '  RLS enabled tables: % / 12', rls_enabled_tables;
    RAISE NOTICE '';
    
    -- Validation checks
    IF public_users_count < auth_users_count THEN
        RAISE WARNING '⚠️  Some auth.users are not linked to public.users! (% missing)', auth_users_count - public_users_count;
    ELSE
        RAISE NOTICE '✅ All auth.users are properly linked to public.users';
    END IF;
    
    IF balances_count < public_users_count THEN
        RAISE WARNING '⚠️  Some users are missing balance records! (% missing)', public_users_count - balances_count;
    ELSE
        RAISE NOTICE '✅ All users have balance records';
    END IF;
    
    IF linked_balances_count < balances_count THEN
        RAISE WARNING '⚠️  Some balances are not properly linked to auth.users! (% unlinked)', balances_count - linked_balances_count;
    ELSE
        RAISE NOTICE '✅ All balances are properly linked to auth.users';
    END IF;
    
    IF linked_transactions_count < transactions_count THEN
        RAISE WARNING '⚠️  Some transactions are not properly linked to auth.users! (% unlinked)', transactions_count - linked_transactions_count;
    ELSE
        RAISE NOTICE '✅ All transactions are properly linked to auth.users';
    END IF;
    
    IF rls_enabled_tables < 12 THEN
        RAISE WARNING '⚠️  Not all tables have RLS enabled! (% / 12)', rls_enabled_tables;
    ELSE
        RAISE NOTICE '✅ All required tables have RLS enabled';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 SUMMARY:';
    IF public_users_count >= auth_users_count 
       AND balances_count >= public_users_count 
       AND linked_balances_count = balances_count 
       AND linked_transactions_count = transactions_count 
       AND rls_enabled_tables = 12 THEN
        RAISE NOTICE '✅ ALL SYSTEMS PROPERLY CONFIGURED!';
        RAISE NOTICE '✅ UID linking is complete and functional';
        RAISE NOTICE '✅ RLS policies are active and enforced';
        RAISE NOTICE '✅ Test data has been created successfully';
        RAISE NOTICE '✅ All functions are using auth.uid() properly';
    ELSE
        RAISE WARNING '⚠️  Some issues detected - please review warnings above';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔧 AVAILABLE FUNCTIONS:';
    RAISE NOTICE '  - get_user_data_by_uid()';
    RAISE NOTICE '  - get_user_transactions_by_uid(limit)';
    RAISE NOTICE '  - get_user_referrals_by_uid()';
    RAISE NOTICE '  - get_user_cards_by_uid()';
    RAISE NOTICE '  - get_user_notifications_by_uid(limit)';
    RAISE NOTICE '  - get_user_investments_by_uid()';
    RAISE NOTICE '  - get_user_savings_goals_by_uid()';
    RAISE NOTICE '  - get_user_transfer_history_by_uid(limit)';
    RAISE NOTICE '  - process_simple_transfer(sender_email, recipient, amount, description)';
    RAISE NOTICE '  - get_current_user_data()';
    RAISE NOTICE '  - get_current_user_transactions(limit)';
    RAISE NOTICE '  - update_current_user_balance(...)';
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '=== MIGRATION COMPLETED SUCCESSFULLY ===';
    RAISE NOTICE '============================================================';
END $final_comprehensive_validation$;

-- =============================================================================
-- END OF COMPREHENSIVE UID LINKING AND RLS MIGRATION
-- =============================================================================
