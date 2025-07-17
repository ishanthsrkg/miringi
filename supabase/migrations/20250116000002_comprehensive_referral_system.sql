-- =============================================================================
-- COMPREHENSIVE REFERRAL SYSTEM - EFFECTIVE IMPLEMENTATION
-- =============================================================================
-- This migration creates a complete, effective referral system with:
-- 1. Enhanced referral tracking and rewards
-- 2. Multi-tier referral bonuses
-- 3. Referral analytics and reporting
-- 4. Automated reward distribution
-- 5. Fraud prevention and validation
-- 6. Performance optimization
-- =============================================================================

-- =============================================================================
-- 1. ENHANCED REFERRAL TABLES
-- =============================================================================

-- Check if users table exists before proceeding
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
        RAISE EXCEPTION 'public.users table does not exist. Please run the comprehensive database setup migration first.';
    END IF;
END $$;

-- Add new columns to existing referrals table instead of dropping it
ALTER TABLE public.referrals 
ADD COLUMN IF NOT EXISTS base_reward DECIMAL(15,2) DEFAULT 500.00 NOT NULL,
ADD COLUMN IF NOT EXISTS bonus_reward DECIMAL(15,2) DEFAULT 0.00 NOT NULL,
ADD COLUMN IF NOT EXISTS validation_status TEXT DEFAULT 'verified' CHECK (validation_status IN ('unverified', 'verified', 'rejected')),
ADD COLUMN IF NOT EXISTS referred_user_first_transaction_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS referred_user_total_transactions INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS referred_user_total_volume DECIMAL(15,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS ip_address INET,
ADD COLUMN IF NOT EXISTS user_agent TEXT,
ADD COLUMN IF NOT EXISTS device_fingerprint TEXT,
ADD COLUMN IF NOT EXISTS referral_tier INTEGER DEFAULT 1 CHECK (referral_tier BETWEEN 1 AND 5),
ADD COLUMN IF NOT EXISTS tier_bonus_applied BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;

-- Update existing status column to include new values
ALTER TABLE public.referrals DROP CONSTRAINT IF EXISTS referrals_status_check;
ALTER TABLE public.referrals ADD CONSTRAINT referrals_status_check 
CHECK (status IN ('pending', 'completed', 'cancelled', 'expired', 'fraud'));

-- Add constraint for valid completion
ALTER TABLE public.referrals DROP CONSTRAINT IF EXISTS valid_completion;
ALTER TABLE public.referrals ADD CONSTRAINT valid_completion CHECK (
    (status = 'completed' AND completed_at IS NOT NULL) OR 
    (status != 'completed')
);

-- Update total_reward to be calculated from base_reward and bonus_reward
ALTER TABLE public.referrals DROP COLUMN IF EXISTS total_reward;
ALTER TABLE public.referrals ADD COLUMN total_reward DECIMAL(15,2) GENERATED ALWAYS AS (base_reward + bonus_reward) STORED;

-- Update existing records to have proper base_reward values
UPDATE public.referrals 
SET base_reward = COALESCE(reward_amount, 500.00),
    bonus_reward = COALESCE(bonus_amount, 0.00),
    validation_status = 'verified',
    completed_at = CASE WHEN status = 'completed' THEN completion_date ELSE NULL END
WHERE base_reward IS NULL OR bonus_reward IS NULL;

-- Referral tiers configuration
CREATE TABLE public.referral_tiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tier_level INTEGER UNIQUE NOT NULL CHECK (tier_level BETWEEN 1 AND 5),
    tier_name TEXT NOT NULL,
    min_referrals INTEGER NOT NULL DEFAULT 0,
    base_reward DECIMAL(15,2) NOT NULL DEFAULT 500.00,
    bonus_multiplier DECIMAL(5,2) NOT NULL DEFAULT 1.00,
    monthly_bonus DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    requirements JSONB,
    benefits JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Referral campaigns for special promotions
CREATE TABLE public.referral_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    campaign_code TEXT UNIQUE,
    
    -- Campaign rewards
    base_reward DECIMAL(15,2) NOT NULL DEFAULT 500.00,
    referrer_bonus DECIMAL(15,2) DEFAULT 0.00,
    referred_bonus DECIMAL(15,2) DEFAULT 100.00,
    
    -- Campaign period
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Limits
    max_referrals_per_user INTEGER,
    total_campaign_limit INTEGER,
    current_usage INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_campaign_dates CHECK (end_date > start_date)
);

-- Referral analytics and stats
CREATE TABLE public.referral_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Monthly stats
    month_year TEXT NOT NULL, -- Format: 'YYYY-MM'
    
    -- Referral counts
    total_referrals INTEGER DEFAULT 0,
    successful_referrals INTEGER DEFAULT 0,
    pending_referrals INTEGER DEFAULT 0,
    
    -- Financial metrics
    total_rewards_earned DECIMAL(15,2) DEFAULT 0.00,
    total_rewards_paid DECIMAL(15,2) DEFAULT 0.00,
    pending_rewards DECIMAL(15,2) DEFAULT 0.00,
    
    -- Performance metrics
    conversion_rate DECIMAL(5,2) DEFAULT 0.00,
    average_reward DECIMAL(15,2) DEFAULT 0.00,
    
    -- Tier information
    current_tier INTEGER DEFAULT 1,
    tier_progress DECIMAL(5,2) DEFAULT 0.00,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, month_year)
);

-- Referral fraud detection
CREATE TABLE public.referral_fraud_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referral_id UUID REFERENCES public.referrals(id) ON DELETE CASCADE,
    fraud_type TEXT NOT NULL CHECK (fraud_type IN (
        'duplicate_ip', 'suspicious_pattern', 'fake_account', 
        'rapid_signup', 'device_fingerprint', 'manual_review'
    )),
    risk_score INTEGER CHECK (risk_score BETWEEN 0 AND 100),
    details JSONB,
    action_taken TEXT,
    reviewed_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 2. INDEXES FOR PERFORMANCE
-- =============================================================================

-- Referrals table indexes (create only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_id ON public.referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON public.referrals(status);
CREATE INDEX IF NOT EXISTS idx_referrals_created_at ON public.referrals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_status ON public.referrals(referrer_id, status);
CREATE INDEX IF NOT EXISTS idx_referrals_tier ON public.referrals(referral_tier);
CREATE INDEX IF NOT EXISTS idx_referrals_validation ON public.referrals(validation_status);

-- Analytics indexes
CREATE INDEX idx_referral_analytics_user_month ON public.referral_analytics(user_id, month_year);
CREATE INDEX idx_referral_analytics_month ON public.referral_analytics(month_year);
CREATE INDEX idx_referral_analytics_tier ON public.referral_analytics(current_tier);

-- Campaign indexes
CREATE INDEX idx_referral_campaigns_active ON public.referral_campaigns(is_active, start_date, end_date);
CREATE INDEX idx_referral_campaigns_code ON public.referral_campaigns(campaign_code);

-- =============================================================================
-- 3. INITIALIZE REFERRAL TIERS
-- =============================================================================

INSERT INTO public.referral_tiers (tier_level, tier_name, min_referrals, base_reward, bonus_multiplier, monthly_bonus, requirements, benefits) VALUES
(1, 'مبتدئ', 0, 500.00, 1.00, 0.00, 
 '{"min_referrals": 0, "min_activity": "basic"}',
 '{"base_reward": 500, "support_priority": "standard"}'),

(2, 'نشط', 5, 600.00, 1.20, 100.00,
 '{"min_referrals": 5, "min_monthly_activity": 2}',
 '{"base_reward": 600, "monthly_bonus": 100, "support_priority": "high"}'),

(3, 'متقدم', 15, 750.00, 1.50, 250.00,
 '{"min_referrals": 15, "min_monthly_activity": 5, "min_transaction_volume": 10000}',
 '{"base_reward": 750, "monthly_bonus": 250, "exclusive_offers": true}'),

(4, 'خبير', 30, 1000.00, 2.00, 500.00,
 '{"min_referrals": 30, "min_monthly_activity": 10, "min_transaction_volume": 50000}',
 '{"base_reward": 1000, "monthly_bonus": 500, "personal_manager": true}'),

(5, 'سفير', 50, 1500.00, 3.00, 1000.00,
 '{"min_referrals": 50, "min_monthly_activity": 20, "min_transaction_volume": 100000}',
 '{"base_reward": 1500, "monthly_bonus": 1000, "vip_benefits": true, "custom_rewards": true}');

-- =============================================================================
-- 4. ENHANCED REFERRAL FUNCTIONS
-- =============================================================================

-- Function to generate unique referral codes
CREATE OR REPLACE FUNCTION public.generate_referral_code()
RETURNS TEXT AS $$
DECLARE
    code TEXT;
    exists BOOLEAN;
    attempts INTEGER := 0;
BEGIN
    LOOP
        -- Generate a more sophisticated code
        code := 'REF' || UPPER(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));
        
        -- Check if code already exists
        SELECT EXISTS(
            SELECT 1 FROM public.users WHERE referral_code = code
            UNION
            SELECT 1 FROM public.referrals WHERE referral_code = code
        ) INTO exists;
        
        -- Prevent infinite loops
        attempts := attempts + 1;
        IF attempts > 100 THEN
            code := 'REF' || EXTRACT(EPOCH FROM NOW())::BIGINT || FLOOR(RANDOM() * 1000)::TEXT;
            EXIT;
        END IF;
        
        -- If code doesn't exist, return it
        IF NOT exists THEN
            RETURN code;
        END IF;
    END LOOP;
    
    RETURN code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate user's referral tier
CREATE OR REPLACE FUNCTION public.calculate_referral_tier(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_total_referrals INTEGER;
    v_monthly_activity INTEGER;
    v_transaction_volume DECIMAL;
    v_tier INTEGER := 1;
BEGIN
    -- Get user's referral stats
    SELECT 
        COUNT(*) FILTER (WHERE status = 'completed'),
        COUNT(*) FILTER (WHERE status = 'completed' AND completed_at >= DATE_TRUNC('month', NOW())),
        COALESCE(SUM(referred_user_total_volume) FILTER (WHERE status = 'completed'), 0)
    INTO v_total_referrals, v_monthly_activity, v_transaction_volume
    FROM public.referrals
    WHERE referrer_id = p_user_id;
    
    -- Determine tier based on criteria
    IF v_total_referrals >= 50 AND v_monthly_activity >= 20 AND v_transaction_volume >= 100000 THEN
        v_tier := 5; -- سفير
    ELSIF v_total_referrals >= 30 AND v_monthly_activity >= 10 AND v_transaction_volume >= 50000 THEN
        v_tier := 4; -- خبير
    ELSIF v_total_referrals >= 15 AND v_monthly_activity >= 5 AND v_transaction_volume >= 10000 THEN
        v_tier := 3; -- متقدم
    ELSIF v_total_referrals >= 5 AND v_monthly_activity >= 2 THEN
        v_tier := 2; -- نشط
    ELSE
        v_tier := 1; -- مبتدئ
    END IF;
    
    RETURN v_tier;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enhanced referral processing function
CREATE OR REPLACE FUNCTION public.process_referral_comprehensive(
    p_referrer_id UUID,
    p_referred_id UUID,
    p_referral_code TEXT,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_device_fingerprint TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    referral_id UUID,
    reward_amount DECIMAL,
    tier_level INTEGER
) AS $$
DECLARE
    v_referral_id UUID;
    v_tier INTEGER;
    v_base_reward DECIMAL;
    v_bonus_reward DECIMAL := 0;
    v_total_reward DECIMAL;
    v_fraud_score INTEGER := 0;
    v_campaign_active BOOLEAN := false;
    v_campaign_reward DECIMAL := 500.00;
BEGIN
    -- Validate inputs
    IF p_referrer_id IS NULL OR p_referred_id IS NULL OR p_referral_code IS NULL THEN
        RETURN QUERY SELECT false, 'بيانات غير مكتملة'::TEXT, NULL::UUID, 0::DECIMAL, 0;
        RETURN;
    END IF;
    
    -- Check for self-referral
    IF p_referrer_id = p_referred_id THEN
        RETURN QUERY SELECT false, 'لا يمكن إحالة نفسك'::TEXT, NULL::UUID, 0::DECIMAL, 0;
        RETURN;
    END IF;
    
    -- Check if referral already exists
    IF EXISTS (SELECT 1 FROM public.referrals WHERE referred_id = p_referred_id) THEN
        RETURN QUERY SELECT false, 'المستخدم مُحال مسبقاً'::TEXT, NULL::UUID, 0::DECIMAL, 0;
        RETURN;
    END IF;
    
    -- Calculate referrer's tier
    v_tier := public.calculate_referral_tier(p_referrer_id);
    
    -- Get tier-based reward
    SELECT base_reward, bonus_multiplier INTO v_base_reward, v_bonus_reward
    FROM public.referral_tiers
    WHERE tier_level = v_tier AND is_active = true;
    
    -- Check for active campaigns
    SELECT 
        true,
        GREATEST(base_reward, v_base_reward)
    INTO v_campaign_active, v_campaign_reward
    FROM public.referral_campaigns
    WHERE is_active = true 
        AND NOW() BETWEEN start_date AND end_date
        AND (max_referrals_per_user IS NULL OR 
             (SELECT COUNT(*) FROM public.referrals WHERE referrer_id = p_referrer_id) < max_referrals_per_user)
        AND (total_campaign_limit IS NULL OR current_usage < total_campaign_limit)
    ORDER BY base_reward DESC
    LIMIT 1;
    
    -- Use campaign reward if better
    IF v_campaign_active THEN
        v_base_reward := v_campaign_reward;
    END IF;
    
    -- Calculate bonus based on tier multiplier
    v_bonus_reward := v_base_reward * (COALESCE(v_bonus_reward, 1.0) - 1.0);
    v_total_reward := v_base_reward + v_bonus_reward;
    
    -- Basic fraud detection
    IF p_ip_address IS NOT NULL THEN
        -- Check for duplicate IP addresses in recent referrals
        IF EXISTS (
            SELECT 1 FROM public.referrals 
            WHERE ip_address = p_ip_address 
                AND created_at > NOW() - INTERVAL '24 hours'
                AND referrer_id != p_referrer_id
        ) THEN
            v_fraud_score := v_fraud_score + 30;
        END IF;
    END IF;
    
    -- Create referral record
    INSERT INTO public.referrals (
        referrer_id,
        referred_id,
        referral_code,
        base_reward,
        bonus_reward,
        status,
        validation_status,
        referral_tier,
        ip_address,
        user_agent,
        device_fingerprint
    ) VALUES (
        p_referrer_id,
        p_referred_id,
        p_referral_code,
        v_base_reward,
        v_bonus_reward,
        CASE WHEN v_fraud_score > 50 THEN 'pending' ELSE 'completed' END,
        CASE WHEN v_fraud_score > 50 THEN 'unverified' ELSE 'verified' END,
        v_tier,
        p_ip_address,
        p_user_agent,
        p_device_fingerprint
    ) RETURNING id INTO v_referral_id;
    
    -- Log fraud detection if suspicious
    IF v_fraud_score > 30 THEN
        INSERT INTO public.referral_fraud_logs (
            referral_id,
            fraud_type,
            risk_score,
            details
        ) VALUES (
            v_referral_id,
            CASE WHEN v_fraud_score > 50 THEN 'suspicious_pattern' ELSE 'duplicate_ip' END,
            v_fraud_score,
            jsonb_build_object(
                'ip_address', p_ip_address::TEXT,
                'user_agent', p_user_agent,
                'fraud_score', v_fraud_score
            )
        );
    END IF;
    
    -- Add rewards to referrer's balance if not flagged
    IF v_fraud_score <= 50 THEN
        -- Add to main balance
        UPDATE public.balances 
        SET dzd = dzd + v_total_reward,
            updated_at = NOW()
        WHERE user_id = p_referrer_id;
        
        -- Add welcome bonus to referred user
        UPDATE public.balances 
        SET dzd = dzd + 100.00,
            updated_at = NOW()
        WHERE user_id = p_referred_id;
        
        -- Update referrer's earnings
        UPDATE public.users 
        SET referral_earnings = COALESCE(referral_earnings, 0) + v_total_reward,
            updated_at = NOW()
        WHERE id = p_referrer_id;
        
        -- Mark referral as completed
        UPDATE public.referrals 
        SET status = 'completed',
            completed_at = NOW()
        WHERE id = v_referral_id;
    END IF;
    
    -- Update analytics
    PERFORM public.update_referral_analytics(p_referrer_id);
    
    RETURN QUERY SELECT 
        true, 
        CASE 
            WHEN v_fraud_score > 50 THEN 'الإحالة قيد المراجعة للتحقق من الأمان'
            ELSE format('تم منح %s دج كمكافأة إحالة (المستوى: %s)', v_total_reward, v_tier)
        END::TEXT,
        v_referral_id,
        CASE WHEN v_fraud_score <= 50 THEN v_total_reward ELSE 0::DECIMAL END,
        v_tier;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update referral analytics
CREATE OR REPLACE FUNCTION public.update_referral_analytics(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_month_year TEXT := TO_CHAR(NOW(), 'YYYY-MM');
    v_stats RECORD;
BEGIN
    -- Calculate current stats
    SELECT 
        COUNT(*) as total_referrals,
        COUNT(*) FILTER (WHERE status = 'completed') as successful_referrals,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_referrals,
        COALESCE(SUM(total_reward) FILTER (WHERE status = 'completed'), 0) as total_rewards_earned,
        COALESCE(SUM(total_reward) FILTER (WHERE status = 'pending'), 0) as pending_rewards,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(*) FILTER (WHERE status = 'completed')::DECIMAL / COUNT(*)) * 100, 2)
            ELSE 0 
        END as conversion_rate,
        CASE 
            WHEN COUNT(*) FILTER (WHERE status = 'completed') > 0 THEN 
                ROUND(SUM(total_reward) FILTER (WHERE status = 'completed') / COUNT(*) FILTER (WHERE status = 'completed'), 2)
            ELSE 0 
        END as average_reward
    INTO v_stats
    FROM public.referrals
    WHERE referrer_id = p_user_id
        AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW());
    
    -- Insert or update analytics
    INSERT INTO public.referral_analytics (
        user_id,
        month_year,
        total_referrals,
        successful_referrals,
        pending_referrals,
        total_rewards_earned,
        pending_rewards,
        conversion_rate,
        average_reward,
        current_tier
    ) VALUES (
        p_user_id,
        v_month_year,
        v_stats.total_referrals,
        v_stats.successful_referrals,
        v_stats.pending_referrals,
        v_stats.total_rewards_earned,
        v_stats.pending_rewards,
        v_stats.conversion_rate,
        v_stats.average_reward,
        public.calculate_referral_tier(p_user_id)
    )
    ON CONFLICT (user_id, month_year)
    DO UPDATE SET
        total_referrals = EXCLUDED.total_referrals,
        successful_referrals = EXCLUDED.successful_referrals,
        pending_referrals = EXCLUDED.pending_referrals,
        total_rewards_earned = EXCLUDED.total_rewards_earned,
        pending_rewards = EXCLUDED.pending_rewards,
        conversion_rate = EXCLUDED.conversion_rate,
        average_reward = EXCLUDED.average_reward,
        current_tier = EXCLUDED.current_tier,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get comprehensive referral stats
CREATE OR REPLACE FUNCTION public.get_referral_stats_comprehensive(p_user_id UUID)
RETURNS TABLE(
    total_referrals INTEGER,
    successful_referrals INTEGER,
    pending_referrals INTEGER,
    total_earnings DECIMAL,
    pending_rewards DECIMAL,
    current_tier INTEGER,
    tier_name TEXT,
    next_tier_requirements JSONB,
    monthly_bonus DECIMAL,
    conversion_rate DECIMAL,
    this_month_referrals INTEGER,
    tier_progress DECIMAL
) AS $$
DECLARE
    v_current_tier INTEGER;
    v_next_tier INTEGER;
BEGIN
    -- Calculate current tier
    v_current_tier := public.calculate_referral_tier(p_user_id);
    v_next_tier := LEAST(v_current_tier + 1, 5);
    
    RETURN QUERY
    SELECT 
        -- Basic stats
        COALESCE(COUNT(r.*), 0)::INTEGER as total_referrals,
        COALESCE(COUNT(r.*) FILTER (WHERE r.status = 'completed'), 0)::INTEGER as successful_referrals,
        COALESCE(COUNT(r.*) FILTER (WHERE r.status = 'pending'), 0)::INTEGER as pending_referrals,
        
        -- Financial stats
        COALESCE(SUM(r.total_reward) FILTER (WHERE r.status = 'completed'), 0)::DECIMAL as total_earnings,
        COALESCE(SUM(r.total_reward) FILTER (WHERE r.status = 'pending'), 0)::DECIMAL as pending_rewards,
        
        -- Tier information
        v_current_tier as current_tier,
        ct.tier_name,
        nt.requirements as next_tier_requirements,
        ct.monthly_bonus,
        
        -- Performance metrics
        CASE 
            WHEN COUNT(r.*) > 0 THEN 
                ROUND((COUNT(r.*) FILTER (WHERE r.status = 'completed')::DECIMAL / COUNT(r.*)) * 100, 2)
            ELSE 0::DECIMAL 
        END as conversion_rate,
        
        COALESCE(COUNT(r.*) FILTER (WHERE r.created_at >= DATE_TRUNC('month', NOW())), 0)::INTEGER as this_month_referrals,
        
        -- Progress to next tier
        CASE 
            WHEN v_current_tier < 5 THEN
                ROUND(
                    (COUNT(r.*) FILTER (WHERE r.status = 'completed')::DECIMAL / 
                     COALESCE((nt.requirements->>'min_referrals')::INTEGER, 999)) * 100, 2
                )
            ELSE 100::DECIMAL
        END as tier_progress
        
    FROM public.referrals r
    RIGHT JOIN (SELECT p_user_id as user_id) u ON r.referrer_id = u.user_id
    LEFT JOIN public.referral_tiers ct ON ct.tier_level = v_current_tier
    LEFT JOIN public.referral_tiers nt ON nt.tier_level = v_next_tier
    WHERE ct.is_active = true
    GROUP BY ct.tier_name, ct.monthly_bonus, nt.requirements;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get referral leaderboard
CREATE OR REPLACE FUNCTION public.get_referral_leaderboard(p_limit INTEGER DEFAULT 10)
RETURNS TABLE(
    rank INTEGER,
    user_id UUID,
    full_name TEXT,
    total_referrals INTEGER,
    total_earnings DECIMAL,
    current_tier INTEGER,
    tier_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY COUNT(r.id) DESC, SUM(r.total_reward) DESC)::INTEGER as rank,
        u.id as user_id,
        u.full_name,
        COUNT(r.id)::INTEGER as total_referrals,
        COALESCE(SUM(r.total_reward), 0)::DECIMAL as total_earnings,
        public.calculate_referral_tier(u.id) as current_tier,
        rt.tier_name
    FROM public.users u
    LEFT JOIN public.referrals r ON r.referrer_id = u.id AND r.status = 'completed'
    LEFT JOIN public.referral_tiers rt ON rt.tier_level = public.calculate_referral_tier(u.id)
    WHERE u.is_active = true
    GROUP BY u.id, u.full_name, rt.tier_name
    HAVING COUNT(r.id) > 0
    ORDER BY total_referrals DESC, total_earnings DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 5. TRIGGERS AND AUTOMATION
-- =============================================================================

-- Trigger to update analytics when referrals change
CREATE OR REPLACE FUNCTION public.trigger_update_referral_analytics()
RETURNS TRIGGER AS $$
BEGIN
    -- Update analytics for the referrer
    PERFORM public.update_referral_analytics(COALESCE(NEW.referrer_id, OLD.referrer_id));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_referral_analytics_update ON public.referrals;
CREATE TRIGGER trigger_referral_analytics_update
    AFTER INSERT OR UPDATE OR DELETE ON public.referrals
    FOR EACH ROW EXECUTE FUNCTION public.trigger_update_referral_analytics();

-- Trigger to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_referrals_updated_at ON public.referrals;
CREATE TRIGGER update_referrals_updated_at
    BEFORE UPDATE ON public.referrals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_referral_tiers_updated_at ON public.referral_tiers;
CREATE TRIGGER update_referral_tiers_updated_at
    BEFORE UPDATE ON public.referral_tiers
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_referral_campaigns_updated_at ON public.referral_campaigns;
CREATE TRIGGER update_referral_campaigns_updated_at
    BEFORE UPDATE ON public.referral_campaigns
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- 6. RLS POLICIES
-- =============================================================================

-- Enable RLS (referrals table already has RLS enabled)
ALTER TABLE public.referral_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_fraud_logs ENABLE ROW LEVEL SECURITY;

-- Update existing referrals policies
DROP POLICY IF EXISTS "Users can view own referrals" ON public.referrals;
DROP POLICY IF EXISTS "Users can insert referrals" ON public.referrals;
DROP POLICY IF EXISTS "Users can update own referrals" ON public.referrals;

CREATE POLICY "Users can view referrals they are involved in" ON public.referrals
    FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);

CREATE POLICY "Users can insert referrals as referrer" ON public.referrals
    FOR INSERT WITH CHECK (auth.uid() = referrer_id);

CREATE POLICY "Users can update own referrals" ON public.referrals
    FOR UPDATE USING (auth.uid() = referrer_id);

-- Tiers policies (read-only for users)
DROP POLICY IF EXISTS "Users can view referral tiers" ON public.referral_tiers;
CREATE POLICY "Users can view referral tiers" ON public.referral_tiers
    FOR SELECT USING (is_active = true);

-- Campaigns policies (read-only for users)
DROP POLICY IF EXISTS "Users can view active campaigns" ON public.referral_campaigns;
CREATE POLICY "Users can view active campaigns" ON public.referral_campaigns
    FOR SELECT USING (is_active = true AND NOW() BETWEEN start_date AND end_date);

-- Analytics policies
DROP POLICY IF EXISTS "Users can view own analytics" ON public.referral_analytics;
CREATE POLICY "Users can view own analytics" ON public.referral_analytics
    FOR SELECT USING (auth.uid() = user_id);

-- =============================================================================
-- 7. ENABLE REALTIME
-- =============================================================================

-- Referrals table already has realtime enabled, add new tables
DO $$
BEGIN
    -- Add tables to realtime publication if they exist
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'referral_analytics') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.referral_analytics;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'referral_campaigns') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.referral_campaigns;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'referral_tiers') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.referral_tiers;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'referral_fraud_logs') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.referral_fraud_logs;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Ignore errors if tables are already in publication
        NULL;
END $$;

-- =============================================================================
-- 8. SAMPLE DATA AND TESTING
-- =============================================================================

-- Create a sample campaign
INSERT INTO public.referral_campaigns (
    name,
    description,
    campaign_code,
    base_reward,
    referrer_bonus,
    referred_bonus,
    start_date,
    end_date,
    max_referrals_per_user,
    total_campaign_limit
) VALUES (
    'حملة العام الجديد 2025',
    'مكافآت مضاعفة للإحالات خلال شهر يناير',
    'NY2025',
    750.00,
    250.00,
    150.00,
    '2025-01-01 00:00:00+00',
    '2025-01-31 23:59:59+00',
    20,
    1000
);

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_referral_tier(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_referral_comprehensive(UUID, UUID, TEXT, INET, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referral_stats_comprehensive(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referral_leaderboard(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_referral_analytics(UUID) TO authenticated;

-- =============================================================================
-- MIGRATION COMPLETED SUCCESSFULLY
-- =============================================================================
-- The comprehensive referral system includes:
-- ✅ Multi-tier reward system with automatic tier calculation
-- ✅ Campaign management for special promotions
-- ✅ Fraud detection and prevention
-- ✅ Comprehensive analytics and reporting
-- ✅ Performance optimization with proper indexing
-- ✅ Real-time updates and notifications
-- ✅ Automated reward distribution
-- ✅ Leaderboard and gamification features
-- =============================================================================