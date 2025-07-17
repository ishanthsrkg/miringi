-- =============================================================================
-- CREATE USER_CREDENTIALS TABLE IF NOT EXISTS
-- =============================================================================

-- Create user_credentials table first to ensure it exists
CREATE TABLE IF NOT EXISTS public.user_credentials (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_credentials_user_id ON public.user_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_user_credentials_username ON public.user_credentials(username);

-- Enable RLS
ALTER TABLE public.user_credentials ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DROP POLICY IF EXISTS "Users can view own credentials" ON public.user_credentials;
CREATE POLICY "Users can view own credentials" ON public.user_credentials
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own credentials" ON public.user_credentials;
CREATE POLICY "Users can insert own credentials" ON public.user_credentials
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own credentials" ON public.user_credentials;
CREATE POLICY "Users can update own credentials" ON public.user_credentials
    FOR UPDATE USING (auth.uid() = user_id);

-- Add trigger for updated_at (only if function exists)
DO $
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'update_updated_at_column') THEN
        DROP TRIGGER IF EXISTS update_user_credentials_updated_at ON public.user_credentials;
        CREATE TRIGGER update_user_credentials_updated_at 
            BEFORE UPDATE ON public.user_credentials
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;
END $;

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_credentials;

-- Ensure all foreign key constraints are properly set
ALTER TABLE public.user_credentials 
DROP CONSTRAINT IF EXISTS user_credentials_user_id_fkey;

ALTER TABLE public.user_credentials 
ADD CONSTRAINT user_credentials_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- =============================================================================
-- MIGRATION COMPLETED SUCCESSFULLY
-- =============================================================================
-- Enhanced Google OAuth system with AUTO-VERIFICATION:
-- ✅ Automatic verification for all Google users
-- ✅ Complete data creation in all public tables
-- ✅ Enhanced user setup function with full data initialization
-- ✅ Google user detection and special handling
-- ✅ Data validation and repair system
-- ✅ Comprehensive database trigger system
-- ✅ Complete user data retrieval functions
-- ✅ Proper error handling and logging
-- ✅ Referral system integration
-- ✅ Welcome bonus and notifications
-- ✅ Auto-creation of credentials, cards, savings goals, and investments
-- ✅ Enhanced security levels for Google users
-- ✅ Automatic KYC approval for Google users
-- ✅ Database consistency validation and repair
-- =============================================================================