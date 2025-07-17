-- نظام التحويل الفوري المبسط
-- Simplified Instant Transfer System

-- جدول التحويلات المبسط
CREATE TABLE IF NOT EXISTS simple_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_email TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    sender_account_number TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    recipient_name TEXT NOT NULL,
    recipient_account_number TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    description TEXT DEFAULT 'تحويل فوري',
    reference_number TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'completed' CHECK (status IN ('completed', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_simple_transfers_sender_email ON simple_transfers(sender_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_recipient_email ON simple_transfers(recipient_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_created_at ON simple_transfers(created_at DESC);

-- جدول الأرصدة المبسط
CREATE TABLE IF NOT EXISTS simple_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT UNIQUE NOT NULL,
    user_name TEXT NOT NULL,
    account_number TEXT UNIQUE NOT NULL,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- فهرس للأرصدة
CREATE INDEX IF NOT EXISTS idx_simple_balances_email ON simple_balances(user_email);
CREATE INDEX IF NOT EXISTS idx_simple_balances_account ON simple_balances(account_number);

-- دالة توليد رقم مرجعي بسيط
CREATE OR REPLACE FUNCTION generate_simple_reference()
RETURNS TEXT AS $$
DECLARE
    ref_number TEXT;
BEGIN
    ref_number := 'TR' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    RETURN ref_number;
END;
$$ LANGUAGE plpgsql;

-- دالة البحث عن المستخدم
CREATE OR REPLACE FUNCTION find_user_simple(p_identifier TEXT)
RETURNS TABLE(
    user_email TEXT,
    user_name TEXT,
    account_number TEXT,
    balance DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sb.user_email,
        sb.user_name,
        sb.account_number,
        sb.balance
    FROM simple_balances sb
    WHERE sb.user_email ILIKE '%' || p_identifier || '%'
       OR sb.account_number ILIKE '%' || p_identifier || '%'
       OR sb.user_name ILIKE '%' || p_identifier || '%'
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- دالة عرض الرصيد
CREATE OR REPLACE FUNCTION get_user_balance_simple(p_identifier TEXT)
RETURNS TABLE(
    user_email TEXT,
    user_name TEXT,
    account_number TEXT,
    balance DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sb.user_email,
        sb.user_name,
        sb.account_number,
        sb.balance
    FROM simple_balances sb
    WHERE sb.user_email = p_identifier
       OR sb.account_number = p_identifier
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- دالة تحديث الرصيد
CREATE OR REPLACE FUNCTION update_user_balance_simple(
    p_identifier TEXT,
    p_new_balance DECIMAL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    new_balance DECIMAL
) AS $$
DECLARE
    v_user RECORD;
BEGIN
    -- البحث عن المستخدم
    SELECT * INTO v_user
    FROM simple_balances
    WHERE user_email = p_identifier OR account_number = p_identifier;
    
    IF v_user IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المستخدم غير موجود', 0::DECIMAL;
        RETURN;
    END IF;
    
    -- تحديث الرصيد
    UPDATE simple_balances
    SET balance = p_new_balance, updated_at = NOW()
    WHERE user_email = v_user.user_email;
    
    RETURN QUERY SELECT TRUE, 'تم تحديث الرصيد بنجاح', p_new_balance;
END;
$$ LANGUAGE plpgsql;

-- دالة التحويل المبسط
CREATE OR REPLACE FUNCTION process_simple_transfer(
    p_sender_email TEXT,
    p_recipient_identifier TEXT,
    p_amount DECIMAL,
    p_description TEXT DEFAULT 'تحويل فوري'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    reference_number TEXT,
    sender_new_balance DECIMAL,
    recipient_new_balance DECIMAL
) AS $$
DECLARE
    v_sender RECORD;
    v_recipient RECORD;
    v_reference TEXT;
BEGIN
    -- التحقق من المبلغ
    IF p_amount <= 0 THEN
        RETURN QUERY SELECT FALSE, 'المبلغ يجب أن يكون أكبر من صفر', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- البحث عن المرسل
    SELECT * INTO v_sender
    FROM simple_balances
    WHERE user_email = p_sender_email;
    
    IF v_sender IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المرسل غير موجود', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- التحقق من الرصيد
    IF v_sender.balance < p_amount THEN
        RETURN QUERY SELECT FALSE, 'الرصيد غير كافي', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- البحث عن المستلم
    SELECT * INTO v_recipient
    FROM simple_balances
    WHERE user_email = p_recipient_identifier OR account_number = p_recipient_identifier;
    
    IF v_recipient IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المستلم غير موجود', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- توليد رقم مرجعي
    v_reference := generate_simple_reference();
    
    -- تحديث رصيد المرسل
    UPDATE simple_balances
    SET balance = balance - p_amount, updated_at = NOW()
    WHERE user_email = v_sender.user_email;
    
    -- تحديث رصيد المستلم
    UPDATE simple_balances
    SET balance = balance + p_amount, updated_at = NOW()
    WHERE user_email = v_recipient.user_email;
    
    -- إضافة سجل التحويل
    INSERT INTO simple_transfers (
        sender_email, sender_name, sender_account_number,
        recipient_email, recipient_name, recipient_account_number,
        amount, description, reference_number, status
    ) VALUES (
        v_sender.user_email, v_sender.user_name, v_sender.account_number,
        v_recipient.user_email, v_recipient.user_name, v_recipient.account_number,
        p_amount, p_description, v_reference, 'completed'
    );
    
    RETURN QUERY SELECT 
        TRUE,
        'تم التحويل بنجاح',
        v_reference,
        v_sender.balance - p_amount,
        v_recipient.balance + p_amount;
END;
$$ LANGUAGE plpgsql;

-- دالة عرض تاريخ التحويلات
CREATE OR REPLACE FUNCTION get_transfer_history_simple(p_user_email TEXT)
RETURNS TABLE(
    id UUID,
    sender_email TEXT,
    sender_name TEXT,
    recipient_email TEXT,
    recipient_name TEXT,
    amount DECIMAL,
    description TEXT,
    reference_number TEXT,
    status TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    is_sender BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        st.id,
        st.sender_email,
        st.sender_name,
        st.recipient_email,
        st.recipient_name,
        st.amount,
        st.description,
        st.reference_number,
        st.status,
        st.created_at,
        (st.sender_email = p_user_email) as is_sender
    FROM simple_transfers st
    WHERE st.sender_email = p_user_email OR st.recipient_email = p_user_email
    ORDER BY st.created_at DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- إضافة بيانات تجريبية
INSERT INTO simple_balances (user_email, user_name, account_number, balance)
VALUES 
    ('user1@example.com', 'أحمد محمد', 'ACC001', 50000),
    ('user2@example.com', 'فاطمة علي', 'ACC002', 30000),
    ('user3@example.com', 'محمد حسن', 'ACC003', 75000),
    ('test@example.com', 'مستخدم تجريبي', 'ACC999', 100000)
ON CONFLICT (user_email) DO NOTHING;

-- تمكين الوقت الفعلي
ALTER PUBLICATION supabase_realtime ADD TABLE simple_transfers;
ALTER PUBLICATION supabase_realtime ADD TABLE simple_balances;
