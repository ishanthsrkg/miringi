-- Legacy transfer function - replaced by comprehensive system
-- This function is kept for backward compatibility but should not be used
-- Use process_money_transfer instead

CREATE OR REPLACE FUNCTION process_transfer(
  p_sender_id UUID,
  p_recipient_identifier TEXT,
  p_amount DECIMAL
)
RETURNS TABLE(
  success BOOLEAN,
  message TEXT,
  new_sender_balance DECIMAL,
  new_recipient_balance DECIMAL
) AS $
BEGIN
  -- Redirect to the new comprehensive transfer function
  RETURN QUERY
  SELECT 
    t.success,
    t.message,
    t.sender_new_balance as new_sender_balance,
    t.recipient_new_balance as new_recipient_balance
  FROM process_money_transfer(
    p_sender_id,
    p_recipient_identifier,
    p_amount,
    'dzd',
    'تحويل أموال'
  ) t;
END;
$ LANGUAGE plpgsql;
