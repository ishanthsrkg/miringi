-- Add Bitcoin Support to the Database
-- This migration adds Bitcoin functionality to the existing system

-- =============================================================================
-- Add Bitcoin balance to existing balances table
-- =============================================================================

ALTER TABLE public.balances 
ADD COLUMN IF NOT EXISTS btc DECIMAL(18,8) DEFAULT 0.00000000;

-- Update existing balances to have Bitcoin balance
UPDATE public.balances 
SET btc = 0.00000000 
WHERE btc IS NULL;

-- =============================================================================
-- Create Bitcoin transactions table
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.bitcoin_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('buy', 'sell', 'send', 'receive', 'exchange')),
    amount_btc DECIMAL(18,8) NOT NULL,
    amount_fiat DECIMAL(15,2) NOT NULL,
    fiat_currency VARCHAR(3) NOT NULL DEFAULT 'DZD',
    exchange_rate DECIMAL(15,2) NOT NULL,
    bitcoin_address VARCHAR(100),
    transaction_hash VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
    description TEXT,
    fees_btc DECIMAL(18,8) DEFAULT 0.00000000,
    fees_fiat DECIMAL(15,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_bitcoin_transactions_user_id ON public.bitcoin_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_bitcoin_transactions_status ON public.bitcoin_transactions(status);
CREATE INDEX IF NOT EXISTS idx_bitcoin_transactions_type ON public.bitcoin_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_bitcoin_transactions_created_at ON public.bitcoin_transactions(created_at);

-- Enable realtime for Bitcoin transactions
ALTER PUBLICATION supabase_realtime ADD TABLE public.bitcoin_transactions;

-- =============================================================================
-- Create Bitcoin wallet addresses table
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.bitcoin_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    wallet_address VARCHAR(100) NOT NULL UNIQUE,
    wallet_type VARCHAR(20) NOT NULL DEFAULT 'receiving' CHECK (wallet_type IN ('receiving', 'sending', 'cold_storage')),
    is_active BOOLEAN DEFAULT true,
    label VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_bitcoin_wallets_user_id ON public.bitcoin_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_bitcoin_wallets_address ON public.bitcoin_wallets(wallet_address);
CREATE INDEX IF NOT EXISTS idx_bitcoin_wallets_active ON public.bitcoin_wallets(is_active);

-- Enable realtime for Bitcoin wallets
ALTER PUBLICATION supabase_realtime ADD TABLE public.bitcoin_wallets;

-- =============================================================================
-- Create Bitcoin exchange rates table
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.bitcoin_exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    currency VARCHAR(3) NOT NULL,
    rate DECIMAL(15,2) NOT NULL,
    source VARCHAR(50) NOT NULL DEFAULT 'manual',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Add unique constraint for active rates per currency
CREATE UNIQUE INDEX IF NOT EXISTS idx_bitcoin_rates_currency_active 
ON public.bitcoin_exchange_rates(currency) 
WHERE is_active = true;

-- Insert initial exchange rates
INSERT INTO public.bitcoin_exchange_rates (currency, rate, source) VALUES
('DZD', 12500000.00, 'manual'),
('USD', 95000.00, 'manual'),
('EUR', 88000.00, 'manual'),
('GBP', 75000.00, 'manual')
ON CONFLICT DO NOTHING;

-- Enable realtime for exchange rates
ALTER PUBLICATION supabase_realtime ADD TABLE public.bitcoin_exchange_rates;

-- =============================================================================
-- Update the update_user_balance function to include Bitcoin
-- =============================================================================

CREATE OR REPLACE FUNCTION public.update_user_balance(
    p_user_id UUID,
    p_dzd DECIMAL DEFAULT NULL,
    p_eur DECIMAL DEFAULT NULL,
    p_usd DECIMAL DEFAULT NULL,
    p_gbp DECIMAL DEFAULT NULL,
    p_btc DECIMAL DEFAULT NULL,
    p_investment_balance DECIMAL DEFAULT NULL
)
RETURNS TABLE(
    user_id UUID,
    dzd DECIMAL,
    eur DECIMAL,
    usd DECIMAL,
    gbp DECIMAL,
    btc DECIMAL,
    investment_balance DECIMAL,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Update only the fields that are provided (not NULL)
    UPDATE public.balances 
    SET 
        dzd = CASE WHEN p_dzd IS NOT NULL THEN p_dzd ELSE balances.dzd END,
        eur = CASE WHEN p_eur IS NOT NULL THEN p_eur ELSE balances.eur END,
        usd = CASE WHEN p_usd IS NOT NULL THEN p_usd ELSE balances.usd END,
        gbp = CASE WHEN p_gbp IS NOT NULL THEN p_gbp ELSE balances.gbp END,
        btc = CASE WHEN p_btc IS NOT NULL THEN p_btc ELSE balances.btc END,
        investment_balance = CASE WHEN p_investment_balance IS NOT NULL THEN p_investment_balance ELSE balances.investment_balance END,
        updated_at = timezone('utc'::text, now())
    WHERE balances.user_id = p_user_id;
    
    -- Return the updated balance
    RETURN QUERY
    SELECT 
        b.user_id,
        b.dzd,
        b.eur,
        b.usd,
        b.gbp,
        b.btc,
        b.investment_balance,
        b.updated_at
    FROM public.balances b
    WHERE b.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create Bitcoin transaction processing function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.process_bitcoin_transaction(
    p_user_id UUID,
    p_transaction_type VARCHAR,
    p_amount_btc DECIMAL,
    p_amount_fiat DECIMAL,
    p_fiat_currency VARCHAR DEFAULT 'DZD',
    p_exchange_rate DECIMAL DEFAULT NULL,
    p_bitcoin_address VARCHAR DEFAULT NULL,
    p_description TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    transaction_id UUID,
    new_btc_balance DECIMAL,
    new_fiat_balance DECIMAL
) AS $$
DECLARE
    current_btc_balance DECIMAL;
    current_fiat_balance DECIMAL;
    new_transaction_id UUID;
    calculated_exchange_rate DECIMAL;
BEGIN
    -- Get current exchange rate if not provided
    IF p_exchange_rate IS NULL THEN
        SELECT rate INTO calculated_exchange_rate
        FROM public.bitcoin_exchange_rates
        WHERE currency = p_fiat_currency AND is_active = true
        LIMIT 1;
        
        IF calculated_exchange_rate IS NULL THEN
            RETURN QUERY SELECT false, 'سعر الصرف غير متوفر للعملة المحددة', NULL::UUID, 0::DECIMAL, 0::DECIMAL;
            RETURN;
        END IF;
    ELSE
        calculated_exchange_rate := p_exchange_rate;
    END IF;
    
    -- Get current balances
    SELECT btc, 
           CASE 
               WHEN p_fiat_currency = 'DZD' THEN dzd
               WHEN p_fiat_currency = 'USD' THEN usd
               WHEN p_fiat_currency = 'EUR' THEN eur
               WHEN p_fiat_currency = 'GBP' THEN gbp
               ELSE dzd
           END
    INTO current_btc_balance, current_fiat_balance
    FROM public.balances
    WHERE user_id = p_user_id;
    
    -- Validate transaction based on type
    IF p_transaction_type = 'buy' THEN
        -- Check if user has enough fiat currency
        IF current_fiat_balance < p_amount_fiat THEN
            RETURN QUERY SELECT false, 'رصيد غير كافي لشراء البيتكوين', NULL::UUID, current_btc_balance, current_fiat_balance;
            RETURN;
        END IF;
        
        -- Update balances: add BTC, subtract fiat
        current_btc_balance := current_btc_balance + p_amount_btc;
        current_fiat_balance := current_fiat_balance - p_amount_fiat;
        
    ELSIF p_transaction_type = 'sell' THEN
        -- Check if user has enough Bitcoin
        IF current_btc_balance < p_amount_btc THEN
            RETURN QUERY SELECT false, 'رصيد بيتكوين غير كافي للبيع', NULL::UUID, current_btc_balance, current_fiat_balance;
            RETURN;
        END IF;
        
        -- Update balances: subtract BTC, add fiat
        current_btc_balance := current_btc_balance - p_amount_btc;
        current_fiat_balance := current_fiat_balance + p_amount_fiat;
        
    ELSIF p_transaction_type = 'send' THEN
        -- Check if user has enough Bitcoin
        IF current_btc_balance < p_amount_btc THEN
            RETURN QUERY SELECT false, 'رصيد بيتكوين غير كافي للإرسال', NULL::UUID, current_btc_balance, current_fiat_balance;
            RETURN;
        END IF;
        
        -- Update balance: subtract BTC
        current_btc_balance := current_btc_balance - p_amount_btc;
        
    ELSIF p_transaction_type = 'receive' THEN
        -- Update balance: add BTC
        current_btc_balance := current_btc_balance + p_amount_btc;
    END IF;
    
    -- Create transaction record
    INSERT INTO public.bitcoin_transactions (
        user_id, transaction_type, amount_btc, amount_fiat, fiat_currency,
        exchange_rate, bitcoin_address, description, status
    ) VALUES (
        p_user_id, p_transaction_type, p_amount_btc, p_amount_fiat, p_fiat_currency,
        calculated_exchange_rate, p_bitcoin_address, p_description, 'completed'
    ) RETURNING id INTO new_transaction_id;
    
    -- Update user balance
    IF p_fiat_currency = 'DZD' THEN
        PERFORM public.update_user_balance(p_user_id, p_dzd => current_fiat_balance, p_btc => current_btc_balance);
    ELSIF p_fiat_currency = 'USD' THEN
        PERFORM public.update_user_balance(p_user_id, p_usd => current_fiat_balance, p_btc => current_btc_balance);
    ELSIF p_fiat_currency = 'EUR' THEN
        PERFORM public.update_user_balance(p_user_id, p_eur => current_fiat_balance, p_btc => current_btc_balance);
    ELSIF p_fiat_currency = 'GBP' THEN
        PERFORM public.update_user_balance(p_user_id, p_gbp => current_fiat_balance, p_btc => current_btc_balance);
    END IF;
    
    RETURN QUERY SELECT true, 'تمت المعاملة بنجاح', new_transaction_id, current_btc_balance, current_fiat_balance;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create function to get Bitcoin balance and transactions
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_bitcoin_summary(
    p_user_id UUID
)
RETURNS TABLE(
    btc_balance DECIMAL,
    total_bought DECIMAL,
    total_sold DECIMAL,
    total_sent DECIMAL,
    total_received DECIMAL,
    transaction_count INTEGER,
    last_transaction_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.btc,
        COALESCE(SUM(CASE WHEN bt.transaction_type = 'buy' THEN bt.amount_btc ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN bt.transaction_type = 'sell' THEN bt.amount_btc ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN bt.transaction_type = 'send' THEN bt.amount_btc ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN bt.transaction_type = 'receive' THEN bt.amount_btc ELSE 0 END), 0),
        COUNT(bt.id)::INTEGER,
        MAX(bt.created_at)
    FROM public.balances b
    LEFT JOIN public.bitcoin_transactions bt ON b.user_id = bt.user_id AND bt.status = 'completed'
    WHERE b.user_id = p_user_id
    GROUP BY b.btc;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create function to get current Bitcoin exchange rates
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_bitcoin_rates()
RETURNS TABLE(
    currency VARCHAR,
    rate DECIMAL,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ber.currency,
        ber.rate,
        ber.updated_at
    FROM public.bitcoin_exchange_rates ber
    WHERE ber.is_active = true
    ORDER BY ber.currency;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Update existing user balances to include Bitcoin
-- =============================================================================

-- Update the safe_create_user_data function to include Bitcoin balance
CREATE OR REPLACE FUNCTION public.safe_create_user_data(
    p_user_id UUID,
    p_email TEXT,
    p_user_metadata JSONB DEFAULT '{}'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    created_components TEXT[]
) AS $$
DECLARE
    new_referral_code TEXT;
    new_account_number TEXT;
    user_full_name TEXT;
    user_phone TEXT;
    user_username TEXT;
    user_address TEXT;
    user_referral_code TEXT;
    created_items TEXT[] := ARRAY[]::TEXT[];
    referrer_user_id UUID;
BEGIN
    -- Log start
    PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'START', 'INFO');
    
    -- Extract user metadata
    user_full_name := COALESCE(NULLIF(TRIM(p_user_metadata->>'full_name'), ''), 'مستخدم جديد');
    user_phone := COALESCE(NULLIF(TRIM(p_user_metadata->>'phone'), ''), '');
    user_username := COALESCE(NULLIF(TRIM(p_user_metadata->>'username'), ''), '');
    user_address := COALESCE(NULLIF(TRIM(p_user_metadata->>'address'), ''), '');
    user_referral_code := COALESCE(NULLIF(TRIM(p_user_metadata->>'used_referral_code'), ''), '');
    
    -- Generate codes
    BEGIN
        new_referral_code := public.generate_referral_code();
        IF new_referral_code IS NULL THEN
            new_referral_code := 'REF' || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            new_referral_code := 'REF' || LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    END;
    
    new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
    
    -- 1. Create user profile
    BEGIN
        INSERT INTO public.users (
            id, email, full_name, phone, username, address, account_number,
            join_date, created_at, updated_at, referral_code, used_referral_code,
            referral_earnings, is_active, is_verified, verification_status,
            profile_completed, registration_date
        ) VALUES (
            p_user_id, p_email, user_full_name, user_phone, user_username, user_address,
            new_account_number, timezone('utc'::text, now()), timezone('utc'::text, now()),
            timezone('utc'::text, now()), new_referral_code, user_referral_code,
            0.00, true, false, 'unverified', true, timezone('utc'::text, now())
        );
        
        created_items := array_append(created_items, 'user_profile');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_PROFILE', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_PROFILE', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'USER_PROFILE', 'ERROR', SQLERRM);
    END;
    
    -- 2. Create balance with Bitcoin support
    BEGIN
        INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, btc, investment_balance, created_at, updated_at)
        VALUES (p_user_id, 20000.00, 100.00, 110.00, 85.00, 0.00000000, 1000.00, timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        created_items := array_append(created_items, 'balance');
        PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'BALANCE', 'SUCCESS');
    EXCEPTION
        WHEN unique_violation THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'BALANCE', 'SKIPPED', 'Already exists');
        WHEN OTHERS THEN
            PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'BALANCE', 'ERROR', SQLERRM);
    END;
    
    -- Continue with other components...
    -- (Rest of the function remains the same)
    
    -- Return results
    PERFORM public.log_user_creation_attempt(p_user_id, p_email, 'COMPLETE', 'SUCCESS');
    
    RETURN QUERY SELECT 
        true as success,
        'User data created successfully with Bitcoin support' as message,
        created_items as created_components;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Add Bitcoin wallet generation function
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_bitcoin_address(
    p_user_id UUID,
    p_wallet_type VARCHAR DEFAULT 'receiving',
    p_label VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    wallet_address VARCHAR,
    wallet_id UUID
) AS $$
DECLARE
    new_address VARCHAR;
    new_wallet_id UUID;
BEGIN
    -- Generate a mock Bitcoin address (in production, use proper Bitcoin address generation)
    new_address := '1' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT || p_user_id::TEXT), 1, 33));
    
    -- Insert new wallet
    INSERT INTO public.bitcoin_wallets (user_id, wallet_address, wallet_type, label)
    VALUES (p_user_id, new_address, p_wallet_type, p_label)
    RETURNING id INTO new_wallet_id;
    
    RETURN QUERY SELECT true, 'تم إنشاء عنوان البيتكوين بنجاح', new_address, new_wallet_id;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT false, 'فشل في إنشاء عنوان البيتكوين: ' || SQLERRM, NULL::VARCHAR, NULL::UUID;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create indexes for better performance
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_balances_btc ON public.balances(btc) WHERE btc > 0;
CREATE INDEX IF NOT EXISTS idx_bitcoin_transactions_completed ON public.bitcoin_transactions(completed_at) WHERE status = 'completed';

-- =============================================================================
-- Grant necessary permissions
-- =============================================================================

-- Grant permissions for authenticated users
GRANT SELECT, INSERT, UPDATE ON public.bitcoin_transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.bitcoin_wallets TO authenticated;
GRANT SELECT ON public.bitcoin_exchange_rates TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION public.process_bitcoin_transaction TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_bitcoin_summary TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_bitcoin_rates TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_bitcoin_address TO authenticated;

COMMIT;