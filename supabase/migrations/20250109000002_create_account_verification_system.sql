-- Create account_verifications table
CREATE TABLE IF NOT EXISTS account_verifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  country TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  full_address TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  document_type TEXT NOT NULL CHECK (document_type IN ('national_id', 'passport', 'driving_license')),
  document_number TEXT NOT NULL,
  documents JSONB NOT NULL DEFAULT '[]'::jsonb,
  additional_notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'under_review')),
  admin_notes TEXT,
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  submitted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add verification columns to users table if they don't exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'not_submitted' CHECK (verification_status IN ('not_submitted', 'pending', 'approved', 'rejected', 'under_review')),
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_account_verifications_user_id ON account_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_account_verifications_status ON account_verifications(status);
CREATE INDEX IF NOT EXISTS idx_account_verifications_submitted_at ON account_verifications(submitted_at);
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON users(verification_status);
CREATE INDEX IF NOT EXISTS idx_users_is_verified ON users(is_verified);

-- Enable RLS
ALTER TABLE account_verifications ENABLE ROW LEVEL SECURITY;

-- Admin RLS Policies (allow admins to view all verification requests)
DROP POLICY IF EXISTS "Admins can view all verification requests" ON account_verifications;
CREATE POLICY "Admins can view all verification requests"
ON account_verifications FOR SELECT
USING (EXISTS (
  SELECT 1 FROM users 
  WHERE users.id = auth.uid() 
  AND users.email IN ('admin@example.com', 'support@example.com')
));

DROP POLICY IF EXISTS "Admins can update verification requests" ON account_verifications;
CREATE POLICY "Admins can update verification requests"
ON account_verifications FOR UPDATE
USING (EXISTS (
  SELECT 1 FROM users 
  WHERE users.id = auth.uid() 
  AND users.email IN ('admin@example.com', 'support@example.com')
));

-- RLS Policies for account_verifications
DROP POLICY IF EXISTS "Users can view their own verification requests" ON account_verifications;
CREATE POLICY "Users can view their own verification requests"
ON account_verifications FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own verification requests" ON account_verifications;
CREATE POLICY "Users can insert their own verification requests"
ON account_verifications FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own pending verification requests" ON account_verifications;
CREATE POLICY "Users can update their own pending verification requests"
ON account_verifications FOR UPDATE
USING (auth.uid() = user_id AND status = 'pending');

-- Function to automatically update user verification status
CREATE OR REPLACE FUNCTION update_user_verification_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the users table with the new verification status
  UPDATE users 
  SET 
    verification_status = NEW.status,
    is_verified = (NEW.status = 'approved'),
    updated_at = NOW()
  WHERE id = NEW.user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update user verification status
DROP TRIGGER IF EXISTS trigger_update_user_verification_status ON account_verifications;
CREATE TRIGGER trigger_update_user_verification_status
  AFTER INSERT OR UPDATE ON account_verifications
  FOR EACH ROW
  EXECUTE FUNCTION update_user_verification_status();

-- Function to get verification statistics (for admin dashboard)
CREATE OR REPLACE FUNCTION get_verification_stats()
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
  FROM account_verifications;
END;
$$ LANGUAGE plpgsql;

-- Function to get pending verification requests (for admin)
CREATE OR REPLACE FUNCTION get_pending_verifications(
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
  days_pending INTEGER
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
    EXTRACT(DAY FROM NOW() - av.submitted_at)::INTEGER as days_pending
  FROM account_verifications av
  JOIN users u ON av.user_id = u.id
  WHERE av.status IN ('pending', 'under_review')
  ORDER BY av.submitted_at ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function to get all verification requests (for admin dashboard)
CREATE OR REPLACE FUNCTION get_all_verifications(
  p_limit INTEGER DEFAULT 100,
  p_offset INTEGER DEFAULT 0,
  p_status TEXT DEFAULT NULL
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
  reviewed_at TIMESTAMP WITH TIME ZONE,
  admin_notes TEXT,
  days_since_submission INTEGER
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
    av.reviewed_at,
    av.admin_notes,
    EXTRACT(DAY FROM NOW() - av.submitted_at)::INTEGER as days_since_submission
  FROM account_verifications av
  JOIN users u ON av.user_id = u.id
  WHERE (p_status IS NULL OR av.status = p_status)
  ORDER BY 
    CASE 
      WHEN av.status = 'pending' THEN 1
      WHEN av.status = 'under_review' THEN 2
      ELSE 3
    END,
    av.submitted_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Function to view verification documents (for admin)
CREATE OR REPLACE FUNCTION get_verification_documents(
  p_verification_id UUID
)
RETURNS TABLE (
  verification_id UUID,
  user_email TEXT,
  user_name TEXT,
  documents JSONB,
  document_type TEXT,
  document_number TEXT,
  status TEXT,
  submitted_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    av.id as verification_id,
    u.email as user_email,
    u.full_name as user_name,
    av.documents,
    av.document_type,
    av.document_number,
    av.status,
    av.submitted_at
  FROM account_verifications av
  JOIN users u ON av.user_id = u.id
  WHERE av.id = p_verification_id;
END;
$$ LANGUAGE plpgsql;

-- Function to approve verification
CREATE OR REPLACE FUNCTION approve_verification(
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
BEGIN
  -- Get user_id from verification request
  SELECT user_id INTO v_user_id
  FROM account_verifications
  WHERE id = p_verification_id;
  
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'طلب التوثيق غير موجود'::TEXT, '{}'::JSONB;
    RETURN;
  END IF;
  
  -- Update verification status
  UPDATE account_verifications
  SET 
    status = 'approved',
    admin_notes = p_admin_notes,
    reviewed_by = p_admin_id,
    reviewed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_verification_id;
  
  -- Get updated verification data
  SELECT to_jsonb(av.*) INTO v_result
  FROM account_verifications av
  WHERE av.id = p_verification_id;
  
  RETURN QUERY SELECT TRUE, 'تم قبول طلب التوثيق بنجاح'::TEXT, v_result;
END;
$$ LANGUAGE plpgsql;

-- Function to reject verification
CREATE OR REPLACE FUNCTION reject_verification(
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
BEGIN
  -- Get user_id from verification request
  SELECT user_id INTO v_user_id
  FROM account_verifications
  WHERE id = p_verification_id;
  
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'طلب التوثيق غير موجود'::TEXT, '{}'::JSONB;
    RETURN;
  END IF;
  
  -- Update verification status
  UPDATE account_verifications
  SET 
    status = 'rejected',
    admin_notes = p_admin_notes,
    reviewed_by = p_admin_id,
    reviewed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_verification_id;
  
  -- Get updated verification data
  SELECT to_jsonb(av.*) INTO v_result
  FROM account_verifications av
  WHERE av.id = p_verification_id;
  
  RETURN QUERY SELECT TRUE, 'تم رفض طلب التوثيق'::TEXT, v_result;
END;
$$ LANGUAGE plpgsql;

-- Enable realtime for account_verifications (only if not already added)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND tablename = 'account_verifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE account_verifications;
  END IF;
END $$;

-- Insert some sample data for testing (optional)
-- This will be removed in production
INSERT INTO account_verifications (
  user_id,
  country,
  date_of_birth,
  full_address,
  postal_code,
  document_type,
  document_number,
  documents,
  additional_notes,
  status
) 
SELECT 
  u.id,
  'الجزائر',
  '1990-01-01'::DATE,
  'شارع الاستقلال، الجزائر العاصمة',
  '16000',
  'national_id',
  '123456789',
  '[{"name": "id_card.jpg", "type": "image/jpeg", "size": 1024000}]'::JSONB,
  'طلب توثيق تجريبي',
  'pending'
FROM users u
WHERE u.email = 'test@example.com'
AND NOT EXISTS (
  SELECT 1 FROM account_verifications av WHERE av.user_id = u.id
)
LIMIT 1;