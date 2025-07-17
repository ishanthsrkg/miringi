-- Create user_credentials table for storing username and password hash
CREATE TABLE IF NOT EXISTS public.user_credentials (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Create index for username lookups
CREATE INDEX IF NOT EXISTS idx_user_credentials_username ON public.user_credentials(username);
CREATE INDEX IF NOT EXISTS idx_user_credentials_user_id ON public.user_credentials(user_id);

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

-- Add trigger for updated_at
CREATE TRIGGER update_user_credentials_updated_at 
    BEFORE UPDATE ON public.user_credentials
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_credentials;
