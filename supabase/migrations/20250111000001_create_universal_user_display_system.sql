-- =============================================================================
-- UNIVERSAL USER DISPLAY SYSTEM
-- =============================================================================
-- This migration creates a comprehensive system to display user names across
-- all tables and operations, supporting anonymous, authenticated, and all users
-- =============================================================================

-- =============================================================================
-- 1. CREATE UNIVERSAL USER NAMES TABLE
-- =============================================================================

-- Table to store all user names (anonymous and authenticated)
CREATE TABLE IF NOT EXISTS public.universal_user_names (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    user_type TEXT NOT NULL CHECK (user_type IN ('authenticated', 'anonymous', 'guest')),
    email TEXT,
    phone TEXT,
    is_active BOOLEAN DEFAULT true,
    session_id TEXT, -- For anonymous users
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_universal_user_names_user_id ON public.universal_user_names(user_id);
CREATE INDEX IF NOT EXISTS idx_universal_user_names_session_id ON public.universal_user_names(session_id);
CREATE INDEX IF NOT EXISTS idx_universal_user_names_user_type ON public.universal_user_names(user_type);
CREATE INDEX IF NOT EXISTS idx_universal_user_names_is_active ON public.universal_user_names(is_active);
CREATE INDEX IF NOT EXISTS idx_universal_user_names_email ON public.universal_user_names(email);

-- =============================================================================
-- 2. CREATE UNIVERSAL USER ACTIVITY LOG
-- =============================================================================

-- Table to log all user activities across the system
CREATE TABLE IF NOT EXISTS public.universal_user_activity (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    universal_user_id UUID REFERENCES public.universal_user_names(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id TEXT,
    activity_type TEXT NOT NULL,
    table_name TEXT,
    operation TEXT CHECK (operation IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE')),
    record_id TEXT,
    activity_data JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for activity log
CREATE INDEX IF NOT EXISTS idx_universal_activity_user_id ON public.universal_user_activity(universal_user_id);
CREATE INDEX IF NOT EXISTS idx_universal_activity_auth_user_id ON public.universal_user_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_universal_activity_session_id ON public.universal_user_activity(session_id);
CREATE INDEX IF NOT EXISTS idx_universal_activity_type ON public.universal_user_activity(activity_type);
CREATE INDEX IF NOT EXISTS idx_universal_activity_table ON public.universal_user_activity(table_name);
CREATE INDEX IF NOT EXISTS idx_universal_activity_created_at ON public.universal_user_activity(created_at DESC);

-- =============================================================================
-- 3. CREATE UNIVERSAL USER FUNCTIONS
-- =============================================================================

-- Function to get or create universal user
CREATE OR REPLACE FUNCTION public.get_or_create_universal_user(
    p_user_id UUID DEFAULT NULL,
    p_display_name TEXT DEFAULT NULL,
    p_user_type TEXT DEFAULT 'anonymous',
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_session_id TEXT DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_universal_user_id UUID;
    v_final_display_name TEXT;
BEGIN
    -- Determine display name priority
    IF p_display_name IS NOT NULL AND p_display_name != '' THEN
        v_final_display_name := p_display_name;
    ELSIF p_email IS NOT NULL THEN
        v_final_display_name := split_part(p_email, '@', 1);
    ELSIF p_phone IS NOT NULL THEN
        v_final_display_name := 'مستخدم ' || right(p_phone, 4);
    ELSE
        v_final_display_name := 'مستخدم مجهول ' || substring(gen_random_uuid()::text from 1 for 8);
    END IF;

    -- Try to find existing user
    IF p_user_id IS NOT NULL THEN
        SELECT id INTO v_universal_user_id
        FROM public.universal_user_names
        WHERE user_id = p_user_id AND is_active = true
        LIMIT 1;
    ELSIF p_session_id IS NOT NULL THEN
        SELECT id INTO v_universal_user_id
        FROM public.universal_user_names
        WHERE session_id = p_session_id AND is_active = true
        LIMIT 1;
    ELSIF p_email IS NOT NULL THEN
        SELECT id INTO v_universal_user_id
        FROM public.universal_user_names
        WHERE email = p_email AND is_active = true
        LIMIT 1;
    END IF;

    -- Create new user if not found
    IF v_universal_user_id IS NULL THEN
        INSERT INTO public.universal_user_names (
            user_id,
            display_name,
            user_type,
            email,
            phone,
            session_id,
            ip_address,
            user_agent,
            is_active
        ) VALUES (
            p_user_id,
            v_final_display_name,
            p_user_type,
            p_email,
            p_phone,
            p_session_id,
            p_ip_address,
            p_user_agent,
            true
        ) RETURNING id INTO v_universal_user_id;
    ELSE
        -- Update existing user
        UPDATE public.universal_user_names
        SET 
            display_name = COALESCE(p_display_name, display_name),
            email = COALESCE(p_email, email),
            phone = COALESCE(p_phone, phone),
            last_seen = timezone('utc'::text, now()),
            updated_at = timezone('utc'::text, now())
        WHERE id = v_universal_user_id;
    END IF;

    RETURN v_universal_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user display name
CREATE OR REPLACE FUNCTION public.get_universal_user_name(
    p_user_id UUID DEFAULT NULL,
    p_session_id TEXT DEFAULT NULL,
    p_email TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_display_name TEXT;
BEGIN
    -- Try to find by user_id first
    IF p_user_id IS NOT NULL THEN
        SELECT display_name INTO v_display_name
        FROM public.universal_user_names
        WHERE user_id = p_user_id AND is_active = true
        ORDER BY updated_at DESC
        LIMIT 1;
        
        IF v_display_name IS NOT NULL THEN
            RETURN v_display_name;
        END IF;
    END IF;

    -- Try to find by session_id
    IF p_session_id IS NOT NULL THEN
        SELECT display_name INTO v_display_name
        FROM public.universal_user_names
        WHERE session_id = p_session_id AND is_active = true
        ORDER BY updated_at DESC
        LIMIT 1;
        
        IF v_display_name IS NOT NULL THEN
            RETURN v_display_name;
        END IF;
    END IF;

    -- Try to find by email
    IF p_email IS NOT NULL THEN
        SELECT display_name INTO v_display_name
        FROM public.universal_user_names
        WHERE email = p_email AND is_active = true
        ORDER BY updated_at DESC
        LIMIT 1;
        
        IF v_display_name IS NOT NULL THEN
            RETURN v_display_name;
        END IF;
    END IF;

    -- Fallback to authenticated user data
    IF p_user_id IS NOT NULL THEN
        SELECT full_name INTO v_display_name
        FROM public.users
        WHERE id = p_user_id AND is_active = true;
        
        IF v_display_name IS NOT NULL THEN
            RETURN v_display_name;
        END IF;
    END IF;

    -- Final fallback
    RETURN 'مستخدم غير معروف';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log user activity
CREATE OR REPLACE FUNCTION public.log_universal_user_activity(
    p_user_id UUID DEFAULT NULL,
    p_session_id TEXT DEFAULT NULL,
    p_activity_type TEXT DEFAULT 'general',
    p_table_name TEXT DEFAULT NULL,
    p_operation TEXT DEFAULT NULL,
    p_record_id TEXT DEFAULT NULL,
    p_activity_data JSONB DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_universal_user_id UUID;
    v_activity_id UUID;
BEGIN
    -- Get or create universal user
    SELECT public.get_or_create_universal_user(
        p_user_id,
        NULL,
        CASE WHEN p_user_id IS NOT NULL THEN 'authenticated' ELSE 'anonymous' END,
        NULL,
        NULL,
        p_session_id,
        p_ip_address,
        p_user_agent
    ) INTO v_universal_user_id;

    -- Log the activity
    INSERT INTO public.universal_user_activity (
        universal_user_id,
        user_id,
        session_id,
        activity_type,
        table_name,
        operation,
        record_id,
        activity_data,
        ip_address,
        user_agent
    ) VALUES (
        v_universal_user_id,
        p_user_id,
        p_session_id,
        p_activity_type,
        p_table_name,
        p_operation,
        p_record_id,
        p_activity_data,
        p_ip_address,
        p_user_agent
    ) RETURNING id INTO v_activity_id;

    RETURN v_activity_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all users (authenticated and anonymous)
CREATE OR REPLACE FUNCTION public.get_all_universal_users(
    p_limit INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0,
    p_user_type TEXT DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS TABLE (
    universal_id UUID,
    user_id UUID,
    display_name TEXT,
    user_type TEXT,
    email TEXT,
    phone TEXT,
    is_active BOOLEAN,
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    last_seen TIMESTAMP WITH TIME ZONE,
    activity_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as universal_id,
        u.user_id,
        u.display_name,
        u.user_type,
        u.email,
        u.phone,
        u.is_active,
        u.session_id,
        u.created_at,
        u.last_seen,
        COALESCE(a.activity_count, 0) as activity_count
    FROM public.universal_user_names u
    LEFT JOIN (
        SELECT 
            universal_user_id,
            COUNT(*) as activity_count
        FROM public.universal_user_activity
        GROUP BY universal_user_id
    ) a ON u.id = a.universal_user_id
    WHERE 
        (p_user_type IS NULL OR u.user_type = p_user_type)
        AND (p_is_active IS NULL OR u.is_active = p_is_active)
    ORDER BY u.last_seen DESC, u.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search users by name or identifier
CREATE OR REPLACE FUNCTION public.search_universal_users(
    p_search_term TEXT,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    universal_id UUID,
    user_id UUID,
    display_name TEXT,
    user_type TEXT,
    email TEXT,
    phone TEXT,
    match_score INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as universal_id,
        u.user_id,
        u.display_name,
        u.user_type,
        u.email,
        u.phone,
        CASE 
            WHEN u.display_name ILIKE '%' || p_search_term || '%' THEN 100
            WHEN u.email ILIKE '%' || p_search_term || '%' THEN 90
            WHEN u.phone ILIKE '%' || p_search_term || '%' THEN 80
            WHEN u.session_id ILIKE '%' || p_search_term || '%' THEN 70
            ELSE 50
        END as match_score
    FROM public.universal_user_names u
    WHERE 
        u.is_active = true
        AND (
            u.display_name ILIKE '%' || p_search_term || '%'
            OR u.email ILIKE '%' || p_search_term || '%'
            OR u.phone ILIKE '%' || p_search_term || '%'
            OR u.session_id ILIKE '%' || p_search_term || '%'
            OR u.user_id::text ILIKE '%' || p_search_term || '%'
        )
    ORDER BY match_score DESC, u.last_seen DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 4. ADD UNIVERSAL USER COLUMNS TO EXISTING TABLES
-- =============================================================================

-- Add universal user reference to transactions table
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS universal_user_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS user_display_name TEXT;

-- Add universal user reference to investments table
ALTER TABLE public.investments 
ADD COLUMN IF NOT EXISTS universal_user_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS user_display_name TEXT;

-- Add universal user reference to savings_goals table
ALTER TABLE public.savings_goals 
ADD COLUMN IF NOT EXISTS universal_user_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS user_display_name TEXT;

-- Add universal user reference to cards table
ALTER TABLE public.cards 
ADD COLUMN IF NOT EXISTS universal_user_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS user_display_name TEXT;

-- Add universal user reference to notifications table
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS universal_user_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS user_display_name TEXT;

-- Add universal user reference to referrals table
ALTER TABLE public.referrals 
ADD COLUMN IF NOT EXISTS referrer_universal_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS referred_universal_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS referrer_display_name TEXT,
ADD COLUMN IF NOT EXISTS referred_display_name TEXT;

-- Add universal user reference to support_messages table
ALTER TABLE public.support_messages 
ADD COLUMN IF NOT EXISTS universal_user_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS user_display_name TEXT;

-- Add universal user reference to instant_transfers table
ALTER TABLE public.instant_transfers 
ADD COLUMN IF NOT EXISTS sender_universal_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS recipient_universal_id UUID REFERENCES public.universal_user_names(id),
ADD COLUMN IF NOT EXISTS sender_display_name TEXT,
ADD COLUMN IF NOT EXISTS recipient_display_name TEXT;

-- =============================================================================
-- 5. CREATE TRIGGERS TO AUTO-POPULATE UNIVERSAL USER DATA
-- =============================================================================

-- Function to auto-populate universal user data
CREATE OR REPLACE FUNCTION public.auto_populate_universal_user()
RETURNS TRIGGER AS $$
DECLARE
    v_universal_user_id UUID;
    v_display_name TEXT;
BEGIN
    -- Get or create universal user
    IF NEW.user_id IS NOT NULL THEN
        SELECT public.get_or_create_universal_user(
            NEW.user_id,
            NULL,
            'authenticated',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
        ) INTO v_universal_user_id;
        
        -- Get display name
        SELECT public.get_universal_user_name(NEW.user_id, NULL, NULL) INTO v_display_name;
        
        -- Update the record
        NEW.universal_user_id := v_universal_user_id;
        NEW.user_display_name := v_display_name;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for all tables
CREATE TRIGGER trigger_auto_populate_universal_user_transactions
    BEFORE INSERT OR UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.auto_populate_universal_user();

CREATE TRIGGER trigger_auto_populate_universal_user_investments
    BEFORE INSERT OR UPDATE ON public.investments
    FOR EACH ROW EXECUTE FUNCTION public.auto_populate_universal_user();

CREATE TRIGGER trigger_auto_populate_universal_user_savings_goals
    BEFORE INSERT OR UPDATE ON public.savings_goals
    FOR EACH ROW EXECUTE FUNCTION public.auto_populate_universal_user();

CREATE TRIGGER trigger_auto_populate_universal_user_cards
    BEFORE INSERT OR UPDATE ON public.cards
    FOR EACH ROW EXECUTE FUNCTION public.auto_populate_universal_user();

CREATE TRIGGER trigger_auto_populate_universal_user_notifications
    BEFORE INSERT OR UPDATE ON public.notifications
    FOR EACH ROW EXECUTE FUNCTION public.auto_populate_universal_user();

CREATE TRIGGER trigger_auto_populate_universal_user_support_messages
    BEFORE INSERT OR UPDATE ON public.support_messages
    FOR EACH ROW EXECUTE FUNCTION public.auto_populate_universal_user();

-- Special trigger for referrals table (handles both referrer and referred)
CREATE OR REPLACE FUNCTION public.auto_populate_referral_universal_users()
RETURNS TRIGGER AS $$
DECLARE
    v_referrer_universal_id UUID;
    v_referred_universal_id UUID;
    v_referrer_display_name TEXT;
    v_referred_display_name TEXT;
BEGIN
    -- Handle referrer
    IF NEW.referrer_id IS NOT NULL THEN
        SELECT public.get_or_create_universal_user(
            NEW.referrer_id,
            NULL,
            'authenticated',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
        ) INTO v_referrer_universal_id;
        
        SELECT public.get_universal_user_name(NEW.referrer_id, NULL, NULL) INTO v_referrer_display_name;
        
        NEW.referrer_universal_id := v_referrer_universal_id;
        NEW.referrer_display_name := v_referrer_display_name;
    END IF;
    
    -- Handle referred
    IF NEW.referred_id IS NOT NULL THEN
        SELECT public.get_or_create_universal_user(
            NEW.referred_id,
            NULL,
            'authenticated',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
        ) INTO v_referred_universal_id;
        
        SELECT public.get_universal_user_name(NEW.referred_id, NULL, NULL) INTO v_referred_display_name;
        
        NEW.referred_universal_id := v_referred_universal_id;
        NEW.referred_display_name := v_referred_display_name;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_auto_populate_referral_universal_users
    BEFORE INSERT OR UPDATE ON public.referrals
    FOR EACH ROW EXECUTE FUNCTION public.auto_populate_referral_universal_users();

-- Special trigger for instant_transfers table (handles both sender and recipient)
CREATE OR REPLACE FUNCTION public.auto_populate_transfer_universal_users()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_universal_id UUID;
    v_recipient_universal_id UUID;
    v_sender_display_name TEXT;
    v_recipient_display_name TEXT;
BEGIN
    -- Handle sender
    IF NEW.sender_id IS NOT NULL THEN
        SELECT public.get_or_create_universal_user(
            NEW.sender_id,
            NULL,
            'authenticated',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
        ) INTO v_sender_universal_id;
        
        SELECT public.get_universal_user_name(NEW.sender_id, NULL, NULL) INTO v_sender_display_name;
        
        NEW.sender_universal_id := v_sender_universal_id;
        NEW.sender_display_name := v_sender_display_name;
    END IF;
    
    -- Handle recipient
    IF NEW.recipient_id IS NOT NULL THEN
        SELECT public.get_or_create_universal_user(
            NEW.recipient_id,
            NULL,
            'authenticated',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL
        ) INTO v_recipient_universal_id;
        
        SELECT public.get_universal_user_name(NEW.recipient_id, NULL, NULL) INTO v_recipient_display_name;
        
        NEW.recipient_universal_id := v_recipient_universal_id;
        NEW.recipient_display_name := v_recipient_display_name;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_auto_populate_transfer_universal_users
    BEFORE INSERT OR UPDATE ON public.instant_transfers
    FOR EACH ROW EXECUTE FUNCTION public.auto_populate_transfer_universal_users();

-- =============================================================================
-- 6. CREATE VIEWS FOR EASY ACCESS TO USER DATA
-- =============================================================================

-- View to show all transactions with user names
CREATE OR REPLACE VIEW public.transactions_with_users AS
SELECT 
    t.*,
    COALESCE(t.user_display_name, u.display_name, users.full_name, 'مستخدم غير معروف') as final_user_name,
    u.user_type as universal_user_type,
    u.session_id as user_session_id
FROM public.transactions t
LEFT JOIN public.universal_user_names u ON t.universal_user_id = u.id
LEFT JOIN public.users users ON t.user_id = users.id;

-- View to show all transfers with user names
CREATE OR REPLACE VIEW public.transfers_with_users AS
SELECT 
    it.*,
    COALESCE(it.sender_display_name, su.display_name, sender.full_name, 'مرسل غير معروف') as final_sender_name,
    COALESCE(it.recipient_display_name, ru.display_name, recipient.full_name, 'مستقبل غير معروف') as final_recipient_name,
    su.user_type as sender_user_type,
    ru.user_type as recipient_user_type
FROM public.instant_transfers it
LEFT JOIN public.universal_user_names su ON it.sender_universal_id = su.id
LEFT JOIN public.universal_user_names ru ON it.recipient_universal_id = ru.id
LEFT JOIN public.users sender ON it.sender_id = sender.id
LEFT JOIN public.users recipient ON it.recipient_id = recipient.id;

-- View to show all referrals with user names
CREATE OR REPLACE VIEW public.referrals_with_users AS
SELECT 
    r.*,
    COALESCE(r.referrer_display_name, ru.display_name, referrer.full_name, 'محيل غير معروف') as final_referrer_name,
    COALESCE(r.referred_display_name, rfu.display_name, referred.full_name, 'محال غير معروف') as final_referred_name,
    ru.user_type as referrer_user_type,
    rfu.user_type as referred_user_type
FROM public.referrals r
LEFT JOIN public.universal_user_names ru ON r.referrer_universal_id = ru.id
LEFT JOIN public.universal_user_names rfu ON r.referred_universal_id = rfu.id
LEFT JOIN public.users referrer ON r.referrer_id = referrer.id
LEFT JOIN public.users referred ON r.referred_id = referred.id;

-- =============================================================================
-- 7. ENABLE RLS AND CREATE POLICIES
-- =============================================================================

-- Enable RLS on new tables
ALTER TABLE public.universal_user_names ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.universal_user_activity ENABLE ROW LEVEL SECURITY;

-- Policies for universal_user_names
DROP POLICY IF EXISTS "Users can view all universal users" ON public.universal_user_names;
CREATE POLICY "Users can view all universal users" ON public.universal_user_names
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert own universal profile" ON public.universal_user_names;
CREATE POLICY "Users can insert own universal profile" ON public.universal_user_names
    FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can update own universal profile" ON public.universal_user_names;
CREATE POLICY "Users can update own universal profile" ON public.universal_user_names
    FOR UPDATE USING (auth.uid() = user_id OR user_id IS NULL);

-- Policies for universal_user_activity
DROP POLICY IF EXISTS "Users can view all activity" ON public.universal_user_activity;
CREATE POLICY "Users can view all activity" ON public.universal_user_activity
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert activity" ON public.universal_user_activity;
CREATE POLICY "Users can insert activity" ON public.universal_user_activity
    FOR INSERT WITH CHECK (true);

-- =============================================================================
-- 8. ENABLE REALTIME
-- =============================================================================

-- Enable realtime for new tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.universal_user_names;
ALTER PUBLICATION supabase_realtime ADD TABLE public.universal_user_activity;

-- =============================================================================
-- 9. POPULATE EXISTING DATA
-- =============================================================================

-- Populate universal users from existing authenticated users
INSERT INTO public.universal_user_names (
    user_id,
    display_name,
    user_type,
    email,
    phone,
    is_active
)
SELECT 
    u.id,
    u.full_name,
    'authenticated',
    u.email,
    u.phone,
    COALESCE(u.is_active, true)
FROM public.users u
WHERE NOT EXISTS (
    SELECT 1 FROM public.universal_user_names uu 
    WHERE uu.user_id = u.id
);

-- Update existing transactions with universal user data
UPDATE public.transactions t
SET 
    universal_user_id = uu.id,
    user_display_name = uu.display_name
FROM public.universal_user_names uu
WHERE t.user_id = uu.user_id AND t.universal_user_id IS NULL;

-- Update existing investments with universal user data
UPDATE public.investments i
SET 
    universal_user_id = uu.id,
    user_display_name = uu.display_name
FROM public.universal_user_names uu
WHERE i.user_id = uu.user_id AND i.universal_user_id IS NULL;

-- Update existing savings goals with universal user data
UPDATE public.savings_goals sg
SET 
    universal_user_id = uu.id,
    user_display_name = uu.display_name
FROM public.universal_user_names uu
WHERE sg.user_id = uu.user_id AND sg.universal_user_id IS NULL;

-- Update existing cards with universal user data
UPDATE public.cards c
SET 
    universal_user_id = uu.id,
    user_display_name = uu.display_name
FROM public.universal_user_names uu
WHERE c.user_id = uu.user_id AND c.universal_user_id IS NULL;

-- Update existing notifications with universal user data
UPDATE public.notifications n
SET 
    universal_user_id = uu.id,
    user_display_name = uu.display_name
FROM public.universal_user_names uu
WHERE n.user_id = uu.user_id AND n.universal_user_id IS NULL;

-- Update existing referrals with universal user data
UPDATE public.referrals r
SET 
    referrer_universal_id = ruu.id,
    referrer_display_name = ruu.display_name,
    referred_universal_id = rfuu.id,
    referred_display_name = rfuu.display_name
FROM public.universal_user_names ruu, public.universal_user_names rfuu
WHERE r.referrer_id = ruu.user_id 
    AND r.referred_id = rfuu.user_id 
    AND r.referrer_universal_id IS NULL;

-- Update existing support messages with universal user data
UPDATE public.support_messages sm
SET 
    universal_user_id = uu.id,
    user_display_name = uu.display_name
FROM public.universal_user_names uu
WHERE sm.user_id = uu.user_id AND sm.universal_user_id IS NULL;

-- Update existing instant transfers with universal user data
UPDATE public.instant_transfers it
SET 
    sender_universal_id = suu.id,
    sender_display_name = suu.display_name,
    recipient_universal_id = ruu.id,
    recipient_display_name = ruu.display_name
FROM public.universal_user_names suu, public.universal_user_names ruu
WHERE it.sender_id = suu.user_id 
    AND it.recipient_id = ruu.user_id 
    AND it.sender_universal_id IS NULL;

-- =============================================================================
-- MIGRATION COMPLETED SUCCESSFULLY
-- =============================================================================
-- Universal User Display System has been created and configured.
-- All tables now support displaying user names for authenticated and anonymous users.
-- =============================================================================
