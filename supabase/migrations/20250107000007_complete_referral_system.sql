-- Complete Referral System Migration
-- This migration adds referral functionality to the existing database

-- Add referral columns to users table if they don't exist
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS used_referral_code TEXT,
ADD COLUMN IF NOT EXISTS referral_earnings DECIMAL(15,2) DEFAULT 0.00 NOT NULL;

-- Create index for referral code lookups
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_used_referral_code ON public.users(used_referral_code);

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
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Update existing users to have referral codes
UPDATE public.users 
SET referral_code = public.generate_referral_code()
WHERE referral_code IS NULL;

-- Update the handle_new_user function to include referral logic
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
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
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Enable realtime for referrals table (if not already enabled)
ALTER PUBLICATION supabase_realtime ADD TABLE public.referrals;
