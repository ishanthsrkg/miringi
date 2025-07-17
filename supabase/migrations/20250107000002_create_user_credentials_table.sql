CREATE TABLE IF NOT EXISTS public.user_credentials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS user_credentials_user_id_idx ON public.user_credentials(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS user_credentials_username_idx ON public.user_credentials(username);

CREATE OR REPLACE FUNCTION public.handle_user_credentials()
RETURNS trigger AS $$
BEGIN
  -- Insert into user_credentials table with error handling
  INSERT INTO public.user_credentials (user_id, username, password_hash)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'username', ''),
    COALESCE(new.raw_user_meta_data->>'password', '')
  )
  ON CONFLICT (user_id) DO UPDATE SET
    username = EXCLUDED.username,
    password_hash = EXCLUDED.password_hash,
    updated_at = NOW();
  
  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error but don't fail the trigger
    RAISE WARNING 'Error in handle_user_credentials: %', SQLERRM;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_credentials ON auth.users;
CREATE TRIGGER on_auth_user_credentials
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_user_credentials();