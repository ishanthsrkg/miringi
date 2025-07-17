-- Add Admin Users System for Account Verification Management
-- This migration creates admin functionality for managing user accounts and verifications

-- =============================================================================
-- Create admin_users table
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    admin_email TEXT NOT NULL UNIQUE,
    admin_name TEXT NOT NULL,
    admin_role TEXT NOT NULL DEFAULT 'moderator' CHECK (admin_role IN ('super_admin', 'admin', 'moderator', 'support')),
    permissions JSONB DEFAULT '{}',
    can_approve_verifications BOOLEAN DEFAULT true,
    can_reject_verifications BOOLEAN DEFAULT true,
    can_activate_accounts BOOLEAN DEFAULT true,
    can_deactivate_accounts BOOLEAN DEFAULT false,
    can_manage_admins BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.admin_users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    last_login TIMESTAMP WITH TIME ZONE,
    login_count INTEGER DEFAULT 0
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_admin_users_user_id ON public.admin_users(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON public.admin_users(admin_email);
CREATE INDEX IF NOT EXISTS idx_admin_users_role ON public.admin_users(admin_role);
CREATE INDEX IF NOT EXISTS idx_admin_users_active ON public.admin_users(is_active);

-- Enable realtime for admin_users
ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_users;

-- =============================================================================
-- Create admin activity log table
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.admin_activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL CHECK (action_type IN ('approve_verification', 'reject_verification', 'activate_account', 'deactivate_account', 'login', 'logout', 'create_admin', 'update_admin', 'delete_admin')),
    target_user_id UUID REFERENCES auth.users(id),
    target_verification_id UUID REFERENCES public.account_verifications(id),
    action_details JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Add indexes for admin activity log
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_admin_id ON public.admin_activity_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_action_type ON public.admin_activity_log(action_type);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_created_at ON public.admin_activity_log(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_target_user ON public.admin_activity_log(target_user_id);

-- Enable realtime for admin activity log
ALTER PUBLICATION supabase_realtime ADD TABLE public.admin_activity_log;

-- =============================================================================
-- Insert default admin users
-- =============================================================================

-- Insert super admin (you can change these details)
INSERT INTO public.admin_users (
    user_id,
    admin_email,
    admin_name,
    admin_role,
    can_approve_verifications,
    can_reject_verifications,
    can_activate_accounts,
    can_deactivate_accounts,
    can_manage_admins,
    is_active
)
SELECT 
    u.id,
    u.email,
    COALESCE(u.raw_user_meta_data->>'full_name', 'Super Admin'),
    'super_admin',
    true,
    true,
    true,
    true,
    true,
    true
FROM auth.users u
WHERE u.email IN ('admin@example.com', 'support@example.com')
AND NOT EXISTS (
    SELECT 1 FROM public.admin_users au WHERE au.user_id = u.id
)
LIMIT 2;

-- =============================================================================
-- Create helper functions for admin operations
-- =============================================================================

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin_user(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.admin_users 
        WHERE user_id = p_user_id 
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql;

-- Function to get admin permissions
CREATE OR REPLACE FUNCTION public.get_admin_permissions(p_user_id UUID)
RETURNS TABLE(
    admin_id UUID,
    admin_role TEXT,
    can_approve_verifications BOOLEAN,
    can_reject_verifications BOOLEAN,
    can_activate_accounts BOOLEAN,
    can_deactivate_accounts BOOLEAN,
    can_manage_admins BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        au.id,
        au.admin_role,
        au.can_approve_verifications,
        au.can_reject_verifications,
        au.can_activate_accounts,
        au.can_deactivate_accounts,
        au.can_manage_admins
    FROM public.admin_users au
    WHERE au.user_id = p_user_id AND au.is_active = true;
END;
$$ LANGUAGE plpgsql;

-- Function to log admin activity
CREATE OR REPLACE FUNCTION public.log_admin_activity(
    p_admin_user_id UUID,
    p_action_type TEXT,
    p_target_user_id UUID DEFAULT NULL,
    p_target_verification_id UUID DEFAULT NULL,
    p_action_details JSONB DEFAULT '{}',
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    admin_id UUID;
    log_id UUID;
BEGIN
    -- Get admin_id from user_id
    SELECT id INTO admin_id FROM public.admin_users WHERE user_id = p_admin_user_id AND is_active = true;
    
    IF admin_id IS NULL THEN
        RAISE EXCEPTION 'المستخدم ليس مدير';
    END IF;
    
    -- Insert activity log
    INSERT INTO public.admin_activity_log (
        admin_id,
        action_type,
        target_user_id,
        target_verification_id,
        action_details,
        ip_address,
        user_agent
    ) VALUES (
        admin_id,
        p_action_type,
        p_target_user_id,
        p_target_verification_id,
        p_action_details,
        p_ip_address,
        p_user_agent
    ) RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Update verification functions to use admin system
-- =============================================================================

-- Drop existing function first to avoid parameter name conflicts
DROP FUNCTION IF EXISTS public.approve_verification(UUID, TEXT, UUID);
DROP FUNCTION IF EXISTS public.approve_verification(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.approve_verification;

-- Updated approve_verification function with admin checks
CREATE OR REPLACE FUNCTION public.approve_verification(
    p_verification_id UUID,
    p_admin_notes TEXT DEFAULT NULL,
    p_admin_id UUID DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    verification_data JSONB
) AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB;
    v_admin_id UUID;
    v_can_approve BOOLEAN := false;
BEGIN
    -- Check if user is admin and has permission
    IF p_admin_id IS NOT NULL THEN
        SELECT id, can_approve_verifications 
        INTO v_admin_id, v_can_approve
        FROM public.admin_users 
        WHERE user_id = p_admin_id AND is_active = true;
        
        IF v_admin_id IS NULL THEN
            RETURN QUERY SELECT FALSE, 'المستخدم ليس مدير'::TEXT, '{}'::JSONB;
            RETURN;
        END IF;
        
        IF NOT v_can_approve THEN
            RETURN QUERY SELECT FALSE, 'ليس لديك صلاحية لقبول طلبات التوثيق'::TEXT, '{}'::JSONB;
            RETURN;
        END IF;
    END IF;
    
    -- Get user_id from verification request
    SELECT user_id INTO v_user_id
    FROM public.account_verifications
    WHERE id = p_verification_id;
    
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'طلب التوثيق غير موجود'::TEXT, '{}'::JSONB;
        RETURN;
    END IF;
    
    -- Update verification status
    UPDATE public.account_verifications
    SET 
        status = 'approved',
        admin_notes = p_admin_notes,
        reviewed_by = p_admin_id,
        reviewed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_verification_id;
    
    -- Update user verification status
    UPDATE public.users
    SET 
        verification_status = 'approved',
        is_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_user_id;
    
    -- Log admin activity
    IF p_admin_id IS NOT NULL THEN
        PERFORM public.log_admin_activity(
            p_admin_id,
            'approve_verification',
            v_user_id,
            p_verification_id,
            jsonb_build_object('admin_notes', p_admin_notes)
        );
    END IF;
    
    -- Get updated verification data
    SELECT to_jsonb(av.*) INTO v_result
    FROM public.account_verifications av
    WHERE av.id = p_verification_id;
    
    RETURN QUERY SELECT TRUE, 'تم قبول طلب التوثيق بنجاح'::TEXT, v_result;
END;
$$ LANGUAGE plpgsql;

-- Drop existing function first to avoid parameter name conflicts
DROP FUNCTION IF EXISTS public.reject_verification(UUID, TEXT, UUID);
DROP FUNCTION IF EXISTS public.reject_verification(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.reject_verification;

-- Updated reject_verification function with admin checks
CREATE OR REPLACE FUNCTION public.reject_verification(
    p_verification_id UUID,
    p_admin_notes TEXT DEFAULT NULL,
    p_admin_id UUID DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    verification_data JSONB
) AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB;
    v_admin_id UUID;
    v_can_reject BOOLEAN := false;
BEGIN
    -- Check if user is admin and has permission
    IF p_admin_id IS NOT NULL THEN
        SELECT id, can_reject_verifications 
        INTO v_admin_id, v_can_reject
        FROM public.admin_users 
        WHERE user_id = p_admin_id AND is_active = true;
        
        IF v_admin_id IS NULL THEN
            RETURN QUERY SELECT FALSE, 'المستخدم ليس مدير'::TEXT, '{}'::JSONB;
            RETURN;
        END IF;
        
        IF NOT v_can_reject THEN
            RETURN QUERY SELECT FALSE, 'ليس لديك صلاحية لرفض طلبات التوثيق'::TEXT, '{}'::JSONB;
            RETURN;
        END IF;
    END IF;
    
    -- Get user_id from verification request
    SELECT user_id INTO v_user_id
    FROM public.account_verifications
    WHERE id = p_verification_id;
    
    IF v_user_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'طلب التوثيق غير موجود'::TEXT, '{}'::JSONB;
        RETURN;
    END IF;
    
    -- Update verification status
    UPDATE public.account_verifications
    SET 
        status = 'rejected',
        admin_notes = p_admin_notes,
        reviewed_by = p_admin_id,
        reviewed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_verification_id;
    
    -- Update user verification status
    UPDATE public.users
    SET 
        verification_status = 'rejected',
        is_verified = false,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_user_id;
    
    -- Log admin activity
    IF p_admin_id IS NOT NULL THEN
        PERFORM public.log_admin_activity(
            p_admin_id,
            'reject_verification',
            v_user_id,
            p_verification_id,
            jsonb_build_object('admin_notes', p_admin_notes)
        );
    END IF;
    
    -- Get updated verification data
    SELECT to_jsonb(av.*) INTO v_result
    FROM public.account_verifications av
    WHERE av.id = p_verification_id;
    
    RETURN QUERY SELECT TRUE, 'تم رفض طلب التوثيق'::TEXT, v_result;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create account activation/deactivation functions
-- =============================================================================

-- Function to activate user account
CREATE OR REPLACE FUNCTION public.activate_user_account(
    p_target_user_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_admin_id UUID;
    v_can_activate BOOLEAN := false;
BEGIN
    -- Check if user is admin and has permission
    SELECT id, can_activate_accounts 
    INTO v_admin_id, v_can_activate
    FROM public.admin_users 
    WHERE user_id = p_admin_user_id AND is_active = true;
    
    IF v_admin_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المستخدم ليس مدير'::TEXT;
        RETURN;
    END IF;
    
    IF NOT v_can_activate THEN
        RETURN QUERY SELECT FALSE, 'ليس لديك صلاحية لتفعيل الحسابات'::TEXT;
        RETURN;
    END IF;
    
    -- Check if target user exists
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_target_user_id) THEN
        RETURN QUERY SELECT FALSE, 'المستخدم المستهدف غير موجود'::TEXT;
        RETURN;
    END IF;
    
    -- Activate user account
    UPDATE public.users
    SET 
        is_active = true,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_target_user_id;
    
    -- Log admin activity
    PERFORM public.log_admin_activity(
        p_admin_user_id,
        'activate_account',
        p_target_user_id,
        NULL,
        jsonb_build_object('reason', p_reason)
    );
    
    RETURN QUERY SELECT TRUE, 'تم تفعيل الحساب بنجاح'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function to deactivate user account
CREATE OR REPLACE FUNCTION public.deactivate_user_account(
    p_target_user_id UUID,
    p_admin_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_admin_id UUID;
    v_can_deactivate BOOLEAN := false;
BEGIN
    -- Check if user is admin and has permission
    SELECT id, can_deactivate_accounts 
    INTO v_admin_id, v_can_deactivate
    FROM public.admin_users 
    WHERE user_id = p_admin_user_id AND is_active = true;
    
    IF v_admin_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المستخدم ليس مدير'::TEXT;
        RETURN;
    END IF;
    
    IF NOT v_can_deactivate THEN
        RETURN QUERY SELECT FALSE, 'ليس لديك صلاحية لإلغاء تفعيل الحسابات'::TEXT;
        RETURN;
    END IF;
    
    -- Check if target user exists
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_target_user_id) THEN
        RETURN QUERY SELECT FALSE, 'المستخدم المستهدف غير موجود'::TEXT;
        RETURN;
    END IF;
    
    -- Deactivate user account
    UPDATE public.users
    SET 
        is_active = false,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_target_user_id;
    
    -- Log admin activity
    PERFORM public.log_admin_activity(
        p_admin_user_id,
        'deactivate_account',
        p_target_user_id,
        NULL,
        jsonb_build_object('reason', p_reason)
    );
    
    RETURN QUERY SELECT TRUE, 'تم إلغاء تفعيل الحساب بنجاح'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Create admin management functions
-- =============================================================================

-- Function to create new admin
CREATE OR REPLACE FUNCTION public.create_admin_user(
    p_target_user_id UUID,
    p_admin_email TEXT,
    p_admin_name TEXT,
    p_creator_user_id UUID,
    p_admin_role TEXT DEFAULT 'moderator',
    p_permissions JSONB DEFAULT '{}'
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    admin_id UUID
) AS $$
DECLARE
    v_creator_admin_id UUID;
    v_can_manage BOOLEAN := false;
    v_new_admin_id UUID;
BEGIN
    -- Check if creator is admin and has permission
    SELECT id, can_manage_admins 
    INTO v_creator_admin_id, v_can_manage
    FROM public.admin_users 
    WHERE user_id = p_creator_user_id AND is_active = true;
    
    IF v_creator_admin_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المستخدم ليس مدير'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    IF NOT v_can_manage THEN
        RETURN QUERY SELECT FALSE, 'ليس لديك صلاحية لإدارة المديرين'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    -- Check if target user exists
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_target_user_id) THEN
        RETURN QUERY SELECT FALSE, 'المستخدم المستهدف غير موجود'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    -- Check if user is already admin
    IF EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = p_target_user_id) THEN
        RETURN QUERY SELECT FALSE, 'المستخدم مدير بالفعل'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    -- Create admin user
    INSERT INTO public.admin_users (
        user_id,
        admin_email,
        admin_name,
        admin_role,
        permissions,
        created_by
    ) VALUES (
        p_target_user_id,
        p_admin_email,
        p_admin_name,
        p_admin_role,
        p_permissions,
        v_creator_admin_id
    ) RETURNING id INTO v_new_admin_id;
    
    -- Log admin activity
    PERFORM public.log_admin_activity(
        p_creator_user_id,
        'create_admin',
        p_target_user_id,
        NULL,
        jsonb_build_object(
            'new_admin_role', p_admin_role,
            'new_admin_email', p_admin_email
        )
    );
    
    RETURN QUERY SELECT TRUE, 'تم إنشاء المدير بنجاح'::TEXT, v_new_admin_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Update RLS policies for admin access
-- =============================================================================

-- Enable RLS on admin tables
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_activity_log ENABLE ROW LEVEL SECURITY;

-- Admin users policies
DROP POLICY IF EXISTS "Admins can view admin users" ON public.admin_users;
CREATE POLICY "Admins can view admin users" ON public.admin_users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.user_id = auth.uid() AND au.is_active = true
        )
    );

DROP POLICY IF EXISTS "Super admins can manage admin users" ON public.admin_users;
CREATE POLICY "Super admins can manage admin users" ON public.admin_users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.user_id = auth.uid() 
            AND au.is_active = true 
            AND au.can_manage_admins = true
        )
    );

-- Admin activity log policies
DROP POLICY IF EXISTS "Admins can view activity logs" ON public.admin_activity_log;
CREATE POLICY "Admins can view activity logs" ON public.admin_activity_log
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.user_id = auth.uid() AND au.is_active = true
        )
    );

DROP POLICY IF EXISTS "System can insert activity logs" ON public.admin_activity_log;
CREATE POLICY "System can insert activity logs" ON public.admin_activity_log
    FOR INSERT WITH CHECK (true);

-- Update account_verifications policies for admin access
DROP POLICY IF EXISTS "Admins can view all verification requests" ON public.account_verifications;
CREATE POLICY "Admins can view all verification requests" ON public.account_verifications
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.user_id = auth.uid() AND au.is_active = true
        )
    );

DROP POLICY IF EXISTS "Admins can update verification requests" ON public.account_verifications;
CREATE POLICY "Admins can update verification requests" ON public.account_verifications
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.admin_users au 
            WHERE au.user_id = auth.uid() 
            AND au.is_active = true 
            AND (au.can_approve_verifications = true OR au.can_reject_verifications = true)
        )
    );

-- =============================================================================
-- Create functions for getting verification statistics
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_verification_stats()
RETURNS TABLE (
    total_requests BIGINT,
    pending_requests BIGINT,
    approved_requests BIGINT,
    rejected_requests BIGINT,
    under_review_requests BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_requests,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_requests,
        COUNT(*) FILTER (WHERE status = 'approved') as approved_requests,
        COUNT(*) FILTER (WHERE status = 'rejected') as rejected_requests,
        COUNT(*) FILTER (WHERE status = 'under_review') as under_review_requests
    FROM public.account_verifications;
END;
$$ LANGUAGE plpgsql;

-- Function to get pending verifications for admin dashboard
DROP FUNCTION IF EXISTS public.get_pending_verifications(INTEGER, INTEGER);
CREATE OR REPLACE FUNCTION public.get_pending_verifications(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    verification_id UUID,
    user_id UUID,
    user_email TEXT,
    user_name TEXT,
    country TEXT,
    date_of_birth DATE,
    full_address TEXT,
    postal_code TEXT,
    document_type TEXT,
    document_number TEXT,
    documents JSONB,
    additional_notes TEXT,
    status TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    days_pending INTEGER,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    admin_notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        av.id as verification_id,
        av.user_id,
        u.email as user_email,
        u.full_name as user_name,
        av.country,
        av.date_of_birth,
        av.full_address,
        av.postal_code,
        av.document_type,
        av.document_number,
        av.documents,
        av.additional_notes,
        av.status,
        av.submitted_at,
        EXTRACT(DAY FROM timezone('utc'::text, now()) - av.submitted_at)::INTEGER as days_pending,
        av.reviewed_at,
        av.admin_notes
    FROM public.account_verifications av
    JOIN public.users u ON av.user_id = u.id
    ORDER BY 
        CASE 
            WHEN av.status = 'pending' THEN 1
            WHEN av.status = 'under_review' THEN 2
            ELSE 3
        END,
        av.submitted_at ASC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Grant permissions to authenticated users
-- =============================================================================

-- Grant permissions for admin functions
GRANT EXECUTE ON FUNCTION public.is_admin_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_permissions TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_admin_activity TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_verification TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_verification TO authenticated;
GRANT EXECUTE ON FUNCTION public.activate_user_account TO authenticated;
GRANT EXECUTE ON FUNCTION public.deactivate_user_account TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_admin_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_verification_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_verifications TO authenticated;

-- Grant table permissions
GRANT SELECT ON public.admin_users TO authenticated;
GRANT SELECT ON public.admin_activity_log TO authenticated;

COMMIT;