CREATE TABLE IF NOT EXISTS support_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  category TEXT DEFAULT 'general' CHECK (category IN ('general', 'technical', 'billing', 'cards', 'transfers', 'investments')),
  admin_response TEXT,
  admin_id UUID,
  responded_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON support_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_status ON support_messages(status);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON support_messages(created_at DESC);

CREATE OR REPLACE FUNCTION create_support_message(
  p_user_id UUID,
  p_subject TEXT,
  p_message TEXT,
  p_category TEXT DEFAULT 'general',
  p_priority TEXT DEFAULT 'normal'
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  ticket_id UUID,
  reference_number TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_ticket_id UUID;
  v_reference_number TEXT;
BEGIN
  -- Generate ticket ID
  v_ticket_id := gen_random_uuid();
  
  -- Generate reference number (SUP + timestamp + random)
  v_reference_number := 'SUP' || EXTRACT(EPOCH FROM NOW())::BIGINT || LPAD((RANDOM() * 999)::INT::TEXT, 3, '0');
  
  -- Insert support message
  INSERT INTO support_messages (
    id,
    user_id,
    subject,
    message,
    category,
    priority,
    status
  ) VALUES (
    v_ticket_id,
    p_user_id,
    p_subject,
    p_message,
    p_category,
    p_priority,
    'open'
  );
  
  -- Return success response
  RETURN QUERY SELECT 
    TRUE as success,
    'تم إرسال رسالة الدعم بنجاح' as message,
    v_ticket_id as ticket_id,
    v_reference_number as reference_number;
    
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      FALSE as success,
      'فشل في إرسال رسالة الدعم: ' || SQLERRM as message,
      NULL::UUID as ticket_id,
      NULL::TEXT as reference_number;
END;
$$;

CREATE OR REPLACE FUNCTION get_user_support_messages(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
  id UUID,
  subject TEXT,
  message TEXT,
  status TEXT,
  priority TEXT,
  category TEXT,
  admin_response TEXT,
  responded_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sm.id,
    sm.subject,
    sm.message,
    sm.status,
    sm.priority,
    sm.category,
    sm.admin_response,
    sm.responded_at,
    sm.created_at,
    sm.updated_at
  FROM support_messages sm
  WHERE sm.user_id = p_user_id
  ORDER BY sm.created_at DESC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION update_support_message_status(
  p_message_id UUID,
  p_status TEXT,
  p_admin_response TEXT DEFAULT NULL,
  p_admin_id UUID DEFAULT NULL
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE support_messages 
  SET 
    status = p_status,
    admin_response = COALESCE(p_admin_response, admin_response),
    admin_id = COALESCE(p_admin_id, admin_id),
    responded_at = CASE WHEN p_admin_response IS NOT NULL THEN NOW() ELSE responded_at END,
    updated_at = NOW()
  WHERE id = p_message_id;
  
  IF FOUND THEN
    RETURN QUERY SELECT 
      TRUE as success,
      'تم تحديث حالة الرسالة بنجاح' as message;
  ELSE
    RETURN QUERY SELECT 
      FALSE as success,
      'لم يتم العثور على الرسالة' as message;
  END IF;
END;
$$;

alter publication supabase_realtime add table support_messages;