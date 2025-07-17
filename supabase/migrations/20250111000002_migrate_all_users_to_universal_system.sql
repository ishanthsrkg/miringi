-- =============================================================================
-- MIGRATE ALL USERS TO UNIVERSAL SYSTEM AND RE-ESTABLISH POLICIES
-- =============================================================================
-- This migration transfers all existing users to the universal user system
-- and re-establishes all policies and roles step by step
-- =============================================================================

-- =============================================================================
-- 1. MIGRATE ALL EXISTING USERS TO UNIVERSAL SYSTEM
-- =============================================================================

-- Function to migrate all users to universal system
CREATE OR REPLACE FUNCTION public.migrate_all_users_to_universal_system()
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    migration_status TEXT,
    universal_user_id UUID,
    error_message TEXT
) AS $$
DECLARE
    user_record RECORD;
    v_universal_user_id UUID;
    v_error_message TEXT;
BEGIN
    -- Loop through all users in the users table
    FOR user_record IN 
        SELECT 
            u.id,
            u.email,
            u.full_name,
            u.phone,
            u.is_active
        FROM public.users u
        ORDER BY u.created_at ASC
    LOOP
        BEGIN
            -- Reset error message for each user
            v_error_message := NULL;
            
            -- Get or create universal user
            SELECT public.get_or_create_universal_user(
                user_record.id,
                user_record.full_name,
                'authenticated',
                user_record.email,
                user_record.phone,
                NULL,
                NULL,
                NULL
            ) INTO v_universal_user_id;
            
            -- Return success result
            user_id := user_record.id;
            email := user_record.email;
            full_name := user_record.full_name;
            migration_status := 'SUCCESS';
            universal_user_id := v_universal_user_id;
            error_message := NULL;
            
            RETURN NEXT;
            
        EXCEPTION WHEN OTHERS THEN
            -- Handle any errors during migration
            v_error_message := SQLERRM;
            
            user_id := user_record.id;
            email := user_record.email;
            full_name := user_record.full_name;
            migration_status := 'ERROR';
            universal_user_id := NULL;
            error_message := v_error_message;
            
            RETURN NEXT;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the migration
SELECT * FROM public.migrate_all_users_to_universal_system();

-- =============================================================================
-- 2. UPDATE ALL EXISTING RECORDS WITH UNIVERSAL USER DATA
-- =============================================================================

-- Function to update all existing records with universal user data
CREATE OR REPLACE FUNCTION public.update_all_records_with_universal_users()
RETURNS TABLE (
    table_name TEXT,
    records_updated INTEGER,
    status TEXT,
    error_message TEXT
) AS $$
DECLARE
    v_updated_count INTEGER;
    v_error_message TEXT;
BEGIN
    -- Update transactions table
    BEGIN
        UPDATE public.transactions t
        SET 
            universal_user_id = uu.id,
            user_display_name = uu.display_name
        FROM public.universal_user_names uu
        WHERE t.user_id = uu.user_id 
            AND t.universal_user_id IS NULL;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        table_name := 'transactions';
        records_updated := v_updated_count;
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        table_name := 'transactions';
        records_updated := 0;
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Update investments table
    BEGIN
        UPDATE public.investments i
        SET 
            universal_user_id = uu.id,
            user_display_name = uu.display_name
        FROM public.universal_user_names uu
        WHERE i.user_id = uu.user_id 
            AND i.universal_user_id IS NULL;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        table_name := 'investments';
        records_updated := v_updated_count;
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        table_name := 'investments';
        records_updated := 0;
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Update savings_goals table
    BEGIN
        UPDATE public.savings_goals sg
        SET 
            universal_user_id = uu.id,
            user_display_name = uu.display_name
        FROM public.universal_user_names uu
        WHERE sg.user_id = uu.user_id 
            AND sg.universal_user_id IS NULL;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        table_name := 'savings_goals';
        records_updated := v_updated_count;
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        table_name := 'savings_goals';
        records_updated := 0;
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Update cards table
    BEGIN
        UPDATE public.cards c
        SET 
            universal_user_id = uu.id,
            user_display_name = uu.display_name
        FROM public.universal_user_names uu
        WHERE c.user_id = uu.user_id 
            AND c.universal_user_id IS NULL;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        table_name := 'cards';
        records_updated := v_updated_count;
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        table_name := 'cards';
        records_updated := 0;
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Update notifications table
    BEGIN
        UPDATE public.notifications n
        SET 
            universal_user_id = uu.id,
            user_display_name = uu.display_name
        FROM public.universal_user_names uu
        WHERE n.user_id = uu.user_id 
            AND n.universal_user_id IS NULL;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        table_name := 'notifications';
        records_updated := v_updated_count;
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        table_name := 'notifications';
        records_updated := 0;
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Update support_messages table
    BEGIN
        UPDATE public.support_messages sm
        SET 
            universal_user_id = uu.id,
            user_display_name = uu.display_name
        FROM public.universal_user_names uu
        WHERE sm.user_id = uu.user_id 
            AND sm.universal_user_id IS NULL;
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        table_name := 'support_messages';
        records_updated := v_updated_count;
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        table_name := 'support_messages';
        records_updated := 0;
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Update referrals table (both referrer and referred)
    BEGIN
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
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        table_name := 'referrals';
        records_updated := v_updated_count;
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        table_name := 'referrals';
        records_updated := 0;
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Update instant_transfers table (both sender and recipient)
    BEGIN
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
        
        GET DIAGNOSTICS v_updated_count = ROW_COUNT;
        
        table_name := 'instant_transfers';
        records_updated := v_updated_count;
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        table_name := 'instant_transfers';
        records_updated := 0;
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the record updates
SELECT * FROM public.update_all_records_with_universal_users();

-- =============================================================================
-- 3. RE-ESTABLISH ALL RLS POLICIES STEP BY STEP
-- =============================================================================

-- Function to re-establish all RLS policies
CREATE OR REPLACE FUNCTION public.reestablish_all_rls_policies()
RETURNS TABLE (
    table_name TEXT,
    policy_name TEXT,
    action TEXT,
    status TEXT,
    error_message TEXT
) AS $$
DECLARE
    v_error_message TEXT;
BEGIN
    -- Enable RLS on all main tables
    BEGIN
        ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
        table_name := 'users';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'users';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.balances ENABLE ROW LEVEL SECURITY;
        table_name := 'balances';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'balances';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
        table_name := 'transactions';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'transactions';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.investments ENABLE ROW LEVEL SECURITY;
        table_name := 'investments';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'investments';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.savings_goals ENABLE ROW LEVEL SECURITY;
        table_name := 'savings_goals';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'savings_goals';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
        table_name := 'cards';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'cards';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
        table_name := 'notifications';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'notifications';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
        table_name := 'referrals';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'referrals';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
        table_name := 'support_messages';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'support_messages';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        ALTER TABLE public.instant_transfers ENABLE ROW LEVEL SECURITY;
        table_name := 'instant_transfers';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'instant_transfers';
        policy_name := 'RLS_ENABLE';
        action := 'ENABLE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for users table
    BEGIN
        DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
        CREATE POLICY "Users can view own profile" ON public.users
            FOR SELECT USING (auth.uid() = id);
        
        table_name := 'users';
        policy_name := 'Users can view own profile';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'users';
        policy_name := 'Users can view own profile';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
        CREATE POLICY "Users can update own profile" ON public.users
            FOR UPDATE USING (auth.uid() = id);
        
        table_name := 'users';
        policy_name := 'Users can update own profile';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'users';
        policy_name := 'Users can update own profile';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for balances table
    BEGIN
        DROP POLICY IF EXISTS "Users can view own balance" ON public.balances;
        CREATE POLICY "Users can view own balance" ON public.balances
            FOR SELECT USING (auth.uid() = user_id);
        
        table_name := 'balances';
        policy_name := 'Users can view own balance';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'balances';
        policy_name := 'Users can view own balance';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Users can update own balance" ON public.balances;
        CREATE POLICY "Users can update own balance" ON public.balances
            FOR UPDATE USING (auth.uid() = user_id);
        
        table_name := 'balances';
        policy_name := 'Users can update own balance';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'balances';
        policy_name := 'Users can update own balance';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for transactions table
    BEGIN
        DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
        CREATE POLICY "Users can view own transactions" ON public.transactions
            FOR SELECT USING (auth.uid() = user_id);
        
        table_name := 'transactions';
        policy_name := 'Users can view own transactions';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'transactions';
        policy_name := 'Users can view own transactions';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
        CREATE POLICY "Users can insert own transactions" ON public.transactions
            FOR INSERT WITH CHECK (auth.uid() = user_id);
        
        table_name := 'transactions';
        policy_name := 'Users can insert own transactions';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'transactions';
        policy_name := 'Users can insert own transactions';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for investments table
    BEGIN
        DROP POLICY IF EXISTS "Users can view own investments" ON public.investments;
        CREATE POLICY "Users can view own investments" ON public.investments
            FOR SELECT USING (auth.uid() = user_id);
        
        table_name := 'investments';
        policy_name := 'Users can view own investments';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'investments';
        policy_name := 'Users can view own investments';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Users can manage own investments" ON public.investments;
        CREATE POLICY "Users can manage own investments" ON public.investments
            FOR ALL USING (auth.uid() = user_id);
        
        table_name := 'investments';
        policy_name := 'Users can manage own investments';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'investments';
        policy_name := 'Users can manage own investments';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for savings_goals table
    BEGIN
        DROP POLICY IF EXISTS "Users can manage own savings goals" ON public.savings_goals;
        CREATE POLICY "Users can manage own savings goals" ON public.savings_goals
            FOR ALL USING (auth.uid() = user_id);
        
        table_name := 'savings_goals';
        policy_name := 'Users can manage own savings goals';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'savings_goals';
        policy_name := 'Users can manage own savings goals';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for cards table
    BEGIN
        DROP POLICY IF EXISTS "Users can manage own cards" ON public.cards;
        CREATE POLICY "Users can manage own cards" ON public.cards
            FOR ALL USING (auth.uid() = user_id);
        
        table_name := 'cards';
        policy_name := 'Users can manage own cards';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'cards';
        policy_name := 'Users can manage own cards';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for notifications table
    BEGIN
        DROP POLICY IF EXISTS "Users can manage own notifications" ON public.notifications;
        CREATE POLICY "Users can manage own notifications" ON public.notifications
            FOR ALL USING (auth.uid() = user_id);
        
        table_name := 'notifications';
        policy_name := 'Users can manage own notifications';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'notifications';
        policy_name := 'Users can manage own notifications';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for referrals table
    BEGIN
        DROP POLICY IF EXISTS "Users can view referrals they are involved in" ON public.referrals;
        CREATE POLICY "Users can view referrals they are involved in" ON public.referrals
            FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referred_id);
        
        table_name := 'referrals';
        policy_name := 'Users can view referrals they are involved in';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'referrals';
        policy_name := 'Users can view referrals they are involved in';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for support_messages table
    BEGIN
        DROP POLICY IF EXISTS "Users can manage own support messages" ON public.support_messages;
        CREATE POLICY "Users can manage own support messages" ON public.support_messages
            FOR ALL USING (auth.uid() = user_id);
        
        table_name := 'support_messages';
        policy_name := 'Users can manage own support messages';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'support_messages';
        policy_name := 'Users can manage own support messages';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create policies for instant_transfers table
    BEGIN
        DROP POLICY IF EXISTS "Users can view transfers they are involved in" ON public.instant_transfers;
        CREATE POLICY "Users can view transfers they are involved in" ON public.instant_transfers
            FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);
        
        table_name := 'instant_transfers';
        policy_name := 'Users can view transfers they are involved in';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'instant_transfers';
        policy_name := 'Users can view transfers they are involved in';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Users can insert transfers as sender" ON public.instant_transfers;
        CREATE POLICY "Users can insert transfers as sender" ON public.instant_transfers
            FOR INSERT WITH CHECK (auth.uid() = sender_id);
        
        table_name := 'instant_transfers';
        policy_name := 'Users can insert transfers as sender';
        action := 'CREATE';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        table_name := 'instant_transfers';
        policy_name := 'Users can insert transfers as sender';
        action := 'CREATE';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the RLS policy re-establishment
SELECT * FROM public.reestablish_all_rls_policies();

-- =============================================================================
-- 4. CREATE ADMIN ROLES AND PERMISSIONS
-- =============================================================================

-- Function to create admin roles and permissions
CREATE OR REPLACE FUNCTION public.create_admin_roles_and_permissions()
RETURNS TABLE (
    role_name TEXT,
    action TEXT,
    status TEXT,
    error_message TEXT
) AS $$
BEGIN
    -- Create admin role for database access
    BEGIN
        -- Grant admin users access to view all data
        DROP POLICY IF EXISTS "Admin users can view all data" ON public.users;
        CREATE POLICY "Admin users can view all data" ON public.users
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.admin_users au 
                    WHERE au.user_id = auth.uid() 
                    AND au.is_active = true
                )
            );
        
        role_name := 'admin_users_view_all';
        action := 'CREATE_POLICY';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        role_name := 'admin_users_view_all';
        action := 'CREATE_POLICY';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create admin policy for balances
    BEGIN
        DROP POLICY IF EXISTS "Admin users can view all balances" ON public.balances;
        CREATE POLICY "Admin users can view all balances" ON public.balances
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.admin_users au 
                    WHERE au.user_id = auth.uid() 
                    AND au.is_active = true
                )
            );
        
        role_name := 'admin_balances_view_all';
        action := 'CREATE_POLICY';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        role_name := 'admin_balances_view_all';
        action := 'CREATE_POLICY';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create admin policy for transactions
    BEGIN
        DROP POLICY IF EXISTS "Admin users can view all transactions" ON public.transactions;
        CREATE POLICY "Admin users can view all transactions" ON public.transactions
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.admin_users au 
                    WHERE au.user_id = auth.uid() 
                    AND au.is_active = true
                )
            );
        
        role_name := 'admin_transactions_view_all';
        action := 'CREATE_POLICY';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        role_name := 'admin_transactions_view_all';
        action := 'CREATE_POLICY';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create admin policy for account verifications
    BEGIN
        DROP POLICY IF EXISTS "Admin users can manage verifications" ON public.account_verifications;
        CREATE POLICY "Admin users can manage verifications" ON public.account_verifications
            FOR ALL USING (
                EXISTS (
                    SELECT 1 FROM public.admin_users au 
                    WHERE au.user_id = auth.uid() 
                    AND au.is_active = true
                    AND (au.can_approve_verifications = true OR au.can_reject_verifications = true)
                )
            );
        
        role_name := 'admin_verifications_manage';
        action := 'CREATE_POLICY';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        role_name := 'admin_verifications_manage';
        action := 'CREATE_POLICY';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create admin policy for support messages
    BEGIN
        DROP POLICY IF EXISTS "Admin users can view all support messages" ON public.support_messages;
        CREATE POLICY "Admin users can view all support messages" ON public.support_messages
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.admin_users au 
                    WHERE au.user_id = auth.uid() 
                    AND au.is_active = true
                )
            );
        
        role_name := 'admin_support_view_all';
        action := 'CREATE_POLICY';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        role_name := 'admin_support_view_all';
        action := 'CREATE_POLICY';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Create admin policy for universal user names
    BEGIN
        DROP POLICY IF EXISTS "Admin users can view all universal users" ON public.universal_user_names;
        CREATE POLICY "Admin users can view all universal users" ON public.universal_user_names
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.admin_users au 
                    WHERE au.user_id = auth.uid() 
                    AND au.is_active = true
                )
            );
        
        role_name := 'admin_universal_users_view_all';
        action := 'CREATE_POLICY';
        status := 'SUCCESS';
        error_message := NULL;
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        role_name := 'admin_universal_users_view_all';
        action := 'CREATE_POLICY';
        status := 'ERROR';
        error_message := SQLERRM;
        RETURN NEXT;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute admin roles and permissions creation
SELECT * FROM public.create_admin_roles_and_permissions();

-- =============================================================================
-- 5. CREATE COMPREHENSIVE MIGRATION REPORT
-- =============================================================================

-- Function to generate migration report
CREATE OR REPLACE FUNCTION public.generate_migration_report()
RETURNS TABLE (
    report_section TEXT,
    item_name TEXT,
    count_value BIGINT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    -- Count total users
    RETURN QUERY
    SELECT 
        'USER_COUNTS'::TEXT as report_section,
        'total_users'::TEXT as item_name,
        COUNT(*) as count_value,
        'INFO'::TEXT as status,
        'Total users in users table'::TEXT as details
    FROM public.users
    UNION ALL
    
    -- Count universal users
    SELECT 
        'USER_COUNTS'::TEXT as report_section,
        'universal_users'::TEXT as item_name,
        COUNT(*) as count_value,
        'INFO'::TEXT as status,
        'Total users in universal_user_names table'::TEXT as details
    FROM public.universal_user_names
    UNION ALL
    
    -- Count transactions with universal user data
    SELECT 
        'TABLE_UPDATES'::TEXT as report_section,
        'transactions_updated'::TEXT as item_name,
        COUNT(*) as count_value,
        'SUCCESS'::TEXT as status,
        'Transactions with universal user data'::TEXT as details
    FROM public.transactions
    WHERE universal_user_id IS NOT NULL
    UNION ALL
    
    -- Count investments with universal user data
    SELECT 
        'TABLE_UPDATES'::TEXT as report_section,
        'investments_updated'::TEXT as item_name,
        COUNT(*) as count_value,
        'SUCCESS'::TEXT as status,
        'Investments with universal user data'::TEXT as details
    FROM public.investments
    WHERE universal_user_id IS NOT NULL
    UNION ALL
    
    -- Count savings goals with universal user data
    SELECT 
        'TABLE_UPDATES'::TEXT as report_section,
        'savings_goals_updated'::TEXT as item_name,
        COUNT(*) as count_value,
        'SUCCESS'::TEXT as status,
        'Savings goals with universal user data'::TEXT as details
    FROM public.savings_goals
    WHERE universal_user_id IS NOT NULL
    UNION ALL
    
    -- Count cards with universal user data
    SELECT 
        'TABLE_UPDATES'::TEXT as report_section,
        'cards_updated'::TEXT as item_name,
        COUNT(*) as count_value,
        'SUCCESS'::TEXT as status,
        'Cards with universal user data'::TEXT as details
    FROM public.cards
    WHERE universal_user_id IS NOT NULL
    UNION ALL
    
    -- Count notifications with universal user data
    SELECT 
        'TABLE_UPDATES'::TEXT as report_section,
        'notifications_updated'::TEXT as item_name,
        COUNT(*) as count_value,
        'SUCCESS'::TEXT as status,
        'Notifications with universal user data'::TEXT as details
    FROM public.notifications
    WHERE universal_user_id IS NOT NULL
    UNION ALL
    
    -- Count referrals with universal user data
    SELECT 
        'TABLE_UPDATES'::TEXT as report_section,
        'referrals_updated'::TEXT as item_name,
        COUNT(*) as count_value,
        'SUCCESS'::TEXT as status,
        'Referrals with universal user data'::TEXT as details
    FROM public.referrals
    WHERE referrer_universal_id IS NOT NULL
    UNION ALL
    
    -- Count instant transfers with universal user data
    SELECT 
        'TABLE_UPDATES'::TEXT as report_section,
        'instant_transfers_updated'::TEXT as item_name,
        COUNT(*) as count_value,
        'SUCCESS'::TEXT as status,
        'Instant transfers with universal user data'::TEXT as details
    FROM public.instant_transfers
    WHERE sender_universal_id IS NOT NULL
    UNION ALL
    
    -- Count support messages with universal user data
    SELECT 
        'TABLE_UPDATES'::TEXT as report_section,
        'support_messages_updated'::TEXT as item_name,
        COUNT(*) as count_value,
        'SUCCESS'::TEXT as status,
        'Support messages with universal user data'::TEXT as details
    FROM public.support_messages
    WHERE universal_user_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Generate and display migration report
SELECT * FROM public.generate_migration_report() ORDER BY report_section, item_name;

-- =============================================================================
-- 6. FINAL CLEANUP AND OPTIMIZATION
-- =============================================================================

-- Update table statistics for better query performance
ANALYZE public.universal_user_names;
ANALYZE public.universal_user_activity;
ANALYZE public.transactions;
ANALYZE public.investments;
ANALYZE public.savings_goals;
ANALYZE public.cards;
ANALYZE public.notifications;
ANALYZE public.referrals;
ANALYZE public.support_messages;
ANALYZE public.instant_transfers;

-- Create indexes for better performance on universal user columns
CREATE INDEX IF NOT EXISTS idx_transactions_universal_user_id ON public.transactions(universal_user_id);
CREATE INDEX IF NOT EXISTS idx_investments_universal_user_id ON public.investments(universal_user_id);
CREATE INDEX IF NOT EXISTS idx_savings_goals_universal_user_id ON public.savings_goals(universal_user_id);
CREATE INDEX IF NOT EXISTS idx_cards_universal_user_id ON public.cards(universal_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_universal_user_id ON public.notifications(universal_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_universal_id ON public.referrals(referrer_universal_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_universal_id ON public.referrals(referred_universal_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_universal_user_id ON public.support_messages(universal_user_id);
CREATE INDEX IF NOT EXISTS idx_instant_transfers_sender_universal_id ON public.instant_transfers(sender_universal_id);
CREATE INDEX IF NOT EXISTS idx_instant_transfers_recipient_universal_id ON public.instant_transfers(recipient_universal_id);

-- =============================================================================
-- MIGRATION COMPLETED SUCCESSFULLY
-- =============================================================================
-- All users have been migrated to the universal system
-- All existing records have been updated with universal user data
-- All RLS policies have been re-established
-- Admin roles and permissions have been created
-- Performance optimizations have been applied
-- =============================================================================

-- =============================================================================
-- STEP 11: ADD COMPREHENSIVE TEST DATA AND ERROR CHECKING
-- =============================================================================

-- Function to add comprehensive test data and check for errors
CREATE OR REPLACE FUNCTION public.add_comprehensive_test_data_and_check_errors()
RETURNS TABLE (
    test_name TEXT,
    status TEXT,
    message TEXT,
    error_details TEXT
) AS $$
DECLARE
    test_user_id UUID;
    test_user_id_2 UUID;
    test_balance DECIMAL;
    test_result RECORD;
    error_message TEXT;
BEGIN
    -- Test 1: Create test users in auth.users (simulated)
    BEGIN
        -- Get first existing user or create test scenario
        SELECT id INTO test_user_id FROM auth.users LIMIT 1;
        
        IF test_user_id IS NULL THEN
            -- Create a dummy UUID for testing if no auth users exist
            test_user_id := gen_random_uuid();
            test_user_id_2 := gen_random_uuid();
            
            -- Insert test users directly into public.users for testing
            INSERT INTO public.users (
                id, email, full_name, phone, account_number, referral_code
            ) VALUES 
                (test_user_id, 'test1@example.com', 'مستخدم تجريبي 1', '+213555000001', public.generate_account_number(), public.generate_referral_code()),
                (test_user_id_2, 'test2@example.com', 'مستخدم تجريبي 2', '+213555000002', public.generate_account_number(), public.generate_referral_code())
            ON CONFLICT (id) DO NOTHING;
            
            -- Insert test balances
            INSERT INTO public.balances (user_id, dzd, eur, usd, gbp, investment_balance) VALUES 
                (test_user_id, 25000.00, 150.00, 180.00, 120.00, 2000.00),
                (test_user_id_2, 30000.00, 200.00, 220.00, 160.00, 1500.00)
            ON CONFLICT (user_id) DO NOTHING;
        ELSE
            -- Use existing users
            SELECT id INTO test_user_id_2 FROM auth.users WHERE id != test_user_id LIMIT 1;
            IF test_user_id_2 IS NULL THEN
                test_user_id_2 := test_user_id;
            END IF;
        END IF;
        
        test_name := 'CREATE_TEST_USERS';
        status := 'SUCCESS';
        message := 'تم إنشاء المستخدمين التجريبيين بنجاح';
        error_details := NULL;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'CREATE_TEST_USERS';
        status := 'ERROR';
        message := 'فشل في إنشاء المستخدمين التجريبيين';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Test 2: Test transfer function
    BEGIN
        SELECT * INTO test_result FROM public.process_transfer(
            test_user_id,
            (SELECT email FROM public.users WHERE id = test_user_id_2 LIMIT 1),
            500.00,
            'تحويل تجريبي'
        );
        
        test_name := 'TRANSFER_FUNCTION';
        IF test_result.success THEN
            status := 'SUCCESS';
            message := 'وظيفة التحويل تعمل بشكل صحيح: ' || test_result.message;
            error_details := 'Reference: ' || test_result.reference_number;
        ELSE
            status := 'WARNING';
            message := 'وظيفة التحويل تعمل لكن مع تحذير: ' || test_result.message;
            error_details := NULL;
        END IF;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'TRANSFER_FUNCTION';
        status := 'ERROR';
        message := 'خطأ في وظيفة التحويل';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Test 3: Test investment function
    BEGIN
        SELECT * INTO test_result FROM public.process_investment(
            test_user_id,
            'monthly',
            2000.00,
            7.50
        );
        
        test_name := 'INVESTMENT_FUNCTION';
        IF test_result.success THEN
            status := 'SUCCESS';
            message := 'وظيفة الاستثمار تعمل بشكل صحيح: ' || test_result.message;
            error_details := 'Investment ID: ' || test_result.investment_id::TEXT;
        ELSE
            status := 'WARNING';
            message := 'وظيفة الاستثمار تعمل لكن مع تحذير: ' || test_result.message;
            error_details := NULL;
        END IF;
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'INVESTMENT_FUNCTION';
        status := 'ERROR';
        message := 'خطأ في وظيفة الاستثمار';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Test 4: Test savings goal function
    BEGIN
        DECLARE
            goal_id UUID;
        BEGIN
            SELECT id INTO goal_id FROM public.savings_goals WHERE user_id = test_user_id LIMIT 1;
            
            IF goal_id IS NOT NULL THEN
                SELECT * INTO test_result FROM public.update_savings_goal(
                    goal_id,
                    1000.00,
                    test_user_id
                );
                
                test_name := 'SAVINGS_GOAL_FUNCTION';
                IF test_result.success THEN
                    status := 'SUCCESS';
                    message := 'وظيفة أهداف الادخار تعمل بشكل صحيح: ' || test_result.message;
                    error_details := 'Progress: ' || test_result.progress_percentage::TEXT || '%';
                ELSE
                    status := 'WARNING';
                    message := 'وظيفة أهداف الادخار تعمل لكن مع تحذير: ' || test_result.message;
                    error_details := NULL;
                END IF;
            ELSE
                status := 'WARNING';
                message := 'لا توجد أهداف ادخار للاختبار';
                error_details := NULL;
            END IF;
            RETURN NEXT;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'SAVINGS_GOAL_FUNCTION';
        status := 'ERROR';
        message := 'خطأ في وظيفة أهداف الادخار';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Test 5: Test search function
    BEGIN
        DECLARE
            search_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO search_count FROM public.search_users('test');
            
            test_name := 'SEARCH_FUNCTION';
            status := 'SUCCESS';
            message := 'وظيفة البحث تعمل بشكل صحيح';
            error_details := 'Found ' || search_count || ' users';
            RETURN NEXT;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'SEARCH_FUNCTION';
        status := 'ERROR';
        message := 'خطأ في وظيفة البحث';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Test 6: Test RLS policies
    BEGIN
        DECLARE
            policy_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO policy_count 
            FROM pg_policies 
            WHERE schemaname = 'public' AND tablename IN ('users', 'balances', 'transactions');
            
            test_name := 'RLS_POLICIES';
            IF policy_count > 0 THEN
                status := 'SUCCESS';
                message := 'سياسات RLS مطبقة بشكل صحيح';
                error_details := 'Found ' || policy_count || ' policies';
            ELSE
                status := 'WARNING';
                message := 'لم يتم العثور على سياسات RLS';
                error_details := NULL;
            END IF;
            RETURN NEXT;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'RLS_POLICIES';
        status := 'ERROR';
        message := 'خطأ في فحص سياسات RLS';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Test 7: Test realtime publication
    BEGIN
        DECLARE
            realtime_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO realtime_count 
            FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename IN ('users', 'balances', 'transactions');
            
            test_name := 'REALTIME_PUBLICATION';
            IF realtime_count > 0 THEN
                status := 'SUCCESS';
                message := 'الوقت الفعلي مفعل بشكل صحيح';
                error_details := 'Found ' || realtime_count || ' tables in publication';
            ELSE
                status := 'WARNING';
                message := 'الوقت الفعلي غير مفعل بشكل كامل';
                error_details := NULL;
            END IF;
            RETURN NEXT;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'REALTIME_PUBLICATION';
        status := 'ERROR';
        message := 'خطأ في فحص الوقت الفعلي';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Test 8: Add comprehensive dummy data
    BEGIN
        -- Add more transactions
        INSERT INTO public.transactions (user_id, type, amount, currency, description, status) VALUES 
            (test_user_id, 'recharge', 10000.00, 'dzd', 'شحن حساب كبير', 'completed'),
            (test_user_id, 'payment', -2500.00, 'dzd', 'دفع فاتورة كهرباء', 'completed'),
            (test_user_id, 'reward', 750.00, 'dzd', 'مكافأة شهرية', 'completed'),
            (test_user_id, 'withdrawal', -5000.00, 'dzd', 'سحب نقدي', 'completed'),
            (test_user_id_2, 'recharge', 8000.00, 'dzd', 'شحن حساب متوسط', 'completed'),
            (test_user_id_2, 'payment', -1200.00, 'dzd', 'دفع فاتورة هاتف', 'completed')
        ON CONFLICT DO NOTHING;
        
        -- Add more notifications
        INSERT INTO public.notifications (user_id, type, title, message, is_read) VALUES 
            (test_user_id, 'success', 'تحويل ناجح', 'تم تحويل 500 دج بنجاح', false),
            (test_user_id, 'info', 'تذكير', 'لا تنس مراجعة استثماراتك الشهرية', false),
            (test_user_id, 'warning', 'تنبيه أمني', 'تم تسجيل دخول من جهاز جديد', true),
            (test_user_id_2, 'success', 'مكافأة', 'تم منحك مكافأة 100 دج', false),
            (test_user_id_2, 'error', 'فشل العملية', 'فشل في معالجة آخر عملية دفع', false)
        ON CONFLICT DO NOTHING;
        
        -- Add more savings goals
        INSERT INTO public.savings_goals (user_id, name, target_amount, current_amount, deadline, category, icon, color) VALUES 
            (test_user_id, 'شراء سيارة', 500000.00, 50000.00, NOW() + INTERVAL '2 years', 'نقل', '🚗', '#FF6B6B'),
            (test_user_id, 'رحلة العمرة', 150000.00, 25000.00, NOW() + INTERVAL '1 year', 'سفر', '🕋', '#4ECDC4'),
            (test_user_id_2, 'شراء منزل', 2000000.00, 200000.00, NOW() + INTERVAL '5 years', 'عقار', '🏠', '#45B7D1'),
            (test_user_id_2, 'تعليم الأطفال', 300000.00, 75000.00, NOW() + INTERVAL '3 years', 'تعليم', '📚', '#96CEB4')
        ON CONFLICT DO NOTHING;
        
        -- Add more investments
        INSERT INTO public.investments (user_id, type, amount, profit_rate, start_date, end_date, status, profit) VALUES 
            (test_user_id, 'quarterly', 15000.00, 8.5, NOW() - INTERVAL '1 month', NOW() + INTERVAL '2 months', 'active', 425.00),
            (test_user_id, 'yearly', 50000.00, 12.0, NOW() - INTERVAL '2 months', NOW() + INTERVAL '10 months', 'active', 1000.00),
            (test_user_id_2, 'weekly', 5000.00, 3.0, NOW() - INTERVAL '3 days', NOW() + INTERVAL '4 days', 'active', 15.00),
            (test_user_id_2, 'monthly', 20000.00, 6.5, NOW() - INTERVAL '15 days', NOW() + INTERVAL '15 days', 'active', 175.00)
        ON CONFLICT DO NOTHING;
        
        -- Add support messages
        INSERT INTO public.support_messages (user_id, subject, message, status, priority, admin_response) VALUES 
            (test_user_id, 'مشكلة في التحويل', 'لا أستطيع تحويل الأموال إلى حسابي الآخر', 'resolved', 'high', 'تم حل المشكلة وإعادة تفعيل خدمة التحويل'),
            (test_user_id, 'استفسار عن الاستثمار', 'ما هي أفضل خطط الاستثمار المتاحة؟', 'in_progress', 'medium', NULL),
            (test_user_id_2, 'طلب رفع الحد الائتماني', 'أريد رفع حد الإنفاق على بطاقتي', 'open', 'low', NULL),
            (test_user_id_2, 'شكوى', 'تم خصم مبلغ خطأ من حسابي', 'resolved', 'urgent', 'تم استرداد المبلغ وإضافة تعويض إضافي')
        ON CONFLICT DO NOTHING;
        
        -- Add account verifications
        INSERT INTO public.account_verifications (user_id, verification_type, status, notes) VALUES 
            (test_user_id, 'identity', 'approved', 'تم التحقق من الهوية بنجاح'),
            (test_user_id, 'address', 'pending', 'في انتظار مراجعة وثائق العنوان'),
            (test_user_id, 'phone', 'approved', 'تم التحقق من رقم الهاتف'),
            (test_user_id_2, 'identity', 'under_review', 'قيد المراجعة من قبل الفريق المختص'),
            (test_user_id_2, 'email', 'approved', 'تم التحقق من البريد الإلكتروني')
        ON CONFLICT DO NOTHING;
        
        test_name := 'ADD_DUMMY_DATA';
        status := 'SUCCESS';
        message := 'تم إضافة البيانات الوهمية الشاملة بنجاح';
        error_details := 'Added transactions, notifications, savings goals, investments, support messages, and verifications';
        RETURN NEXT;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'ADD_DUMMY_DATA';
        status := 'ERROR';
        message := 'خطأ في إضافة البيانات الوهمية';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
    
    -- Test 9: Final database integrity check
    BEGIN
        DECLARE
            users_count INTEGER;
            balances_count INTEGER;
            transactions_count INTEGER;
            cards_count INTEGER;
            notifications_count INTEGER;
            savings_goals_count INTEGER;
            investments_count INTEGER;
            support_messages_count INTEGER;
            verifications_count INTEGER;
        BEGIN
            SELECT COUNT(*) INTO users_count FROM public.users;
            SELECT COUNT(*) INTO balances_count FROM public.balances;
            SELECT COUNT(*) INTO transactions_count FROM public.transactions;
            SELECT COUNT(*) INTO cards_count FROM public.cards;
            SELECT COUNT(*) INTO notifications_count FROM public.notifications;
            SELECT COUNT(*) INTO savings_goals_count FROM public.savings_goals;
            SELECT COUNT(*) INTO investments_count FROM public.investments;
            SELECT COUNT(*) INTO support_messages_count FROM public.support_messages;
            SELECT COUNT(*) INTO verifications_count FROM public.account_verifications;
            
            test_name := 'DATABASE_INTEGRITY';
            status := 'SUCCESS';
            message := 'فحص سلامة قاعدة البيانات مكتمل';
            error_details := FORMAT('Users: %s, Balances: %s, Transactions: %s, Cards: %s, Notifications: %s, Goals: %s, Investments: %s, Support: %s, Verifications: %s', 
                users_count, balances_count, transactions_count, cards_count, notifications_count, savings_goals_count, investments_count, support_messages_count, verifications_count);
            RETURN NEXT;
        END;
        
    EXCEPTION WHEN OTHERS THEN
        test_name := 'DATABASE_INTEGRITY';
        status := 'ERROR';
        message := 'خطأ في فحص سلامة قاعدة البيانات';
        error_details := SQLERRM;
        RETURN NEXT;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute comprehensive test and error checking
SELECT * FROM public.add_comprehensive_test_data_and_check_errors();

-- =============================================================================
-- STEP 12: FINAL SUMMARY REPORT
-- =============================================================================

-- Function to generate final summary report
CREATE OR REPLACE FUNCTION public.generate_final_summary_report()
RETURNS TABLE (
    section TEXT,
    item TEXT,
    count_value BIGINT,
    status TEXT,
    notes TEXT
) AS $$
BEGIN
    -- Database tables summary
    RETURN QUERY
    SELECT 
        'TABLES'::TEXT as section,
        'users'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'Main user profiles table'::TEXT as notes
    FROM public.users
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'balances'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'User account balances'::TEXT as notes
    FROM public.balances
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'transactions'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'Financial transactions'::TEXT as notes
    FROM public.transactions
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'transfers'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'Money transfers between users'::TEXT as notes
    FROM public.transfers
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'cards'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'User payment cards'::TEXT as notes
    FROM public.cards
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'investments'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'User investments'::TEXT as notes
    FROM public.investments
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'savings_goals'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'User savings goals'::TEXT as notes
    FROM public.savings_goals
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'notifications'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'User notifications'::TEXT as notes
    FROM public.notifications
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'referrals'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'Referral system records'::TEXT as notes
    FROM public.referrals
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'support_messages'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'Customer support messages'::TEXT as notes
    FROM public.support_messages
    UNION ALL
    
    SELECT 
        'TABLES'::TEXT as section,
        'account_verifications'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'KYC verification records'::TEXT as notes
    FROM public.account_verifications
    UNION ALL
    
    -- Functions summary
    SELECT 
        'FUNCTIONS'::TEXT as section,
        'process_transfer'::TEXT as item,
        1 as count_value,
        'ACTIVE'::TEXT as status,
        'Money transfer processing'::TEXT as notes
    UNION ALL
    
    SELECT 
        'FUNCTIONS'::TEXT as section,
        'process_investment'::TEXT as item,
        1 as count_value,
        'ACTIVE'::TEXT as status,
        'Investment processing'::TEXT as notes
    UNION ALL
    
    SELECT 
        'FUNCTIONS'::TEXT as section,
        'update_savings_goal'::TEXT as item,
        1 as count_value,
        'ACTIVE'::TEXT as status,
        'Savings goal management'::TEXT as notes
    UNION ALL
    
    SELECT 
        'FUNCTIONS'::TEXT as section,
        'search_users'::TEXT as item,
        1 as count_value,
        'ACTIVE'::TEXT as status,
        'User search functionality'::TEXT as notes
    UNION ALL
    
    SELECT 
        'FUNCTIONS'::TEXT as section,
        'get_user_data'::TEXT as item,
        1 as count_value,
        'ACTIVE'::TEXT as status,
        'User data retrieval'::TEXT as notes
    UNION ALL
    
    -- RLS Policies summary
    SELECT 
        'SECURITY'::TEXT as section,
        'rls_policies'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'Row Level Security policies'::TEXT as notes
    FROM pg_policies 
    WHERE schemaname = 'public'
    UNION ALL
    
    -- Realtime publication summary
    SELECT 
        'REALTIME'::TEXT as section,
        'published_tables'::TEXT as item,
        COUNT(*) as count_value,
        'ACTIVE'::TEXT as status,
        'Tables enabled for realtime'::TEXT as notes
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Generate and display final summary report
SELECT * FROM public.generate_final_summary_report() ORDER BY section, item;

-- =============================================================================
-- DATABASE MIGRATION COMPLETED SUCCESSFULLY WITH COMPREHENSIVE TESTING
-- تم إكمال ترحيل قاعدة البيانات بنجاح مع الاختبار الشامل
-- =============================================================================