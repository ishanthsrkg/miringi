-- =============================================================================
-- UNIFIED TRANSFER SYSTEM - CONSOLIDATION
-- توحيد نظام التحويلات - إزالة الجداول غير الضرورية وإنشاء نظام موحد
-- Created: 2025-01-08
-- تاريخ الإنشاء: 2025-01-08
-- Purpose: Create a simple and unified transfer system
-- الهدف: إنشاء نظام تحويل بسيط وموحد
-- =============================================================================

-- CLEANUP: Remove unused tables and functions
-- حذف الجداول والدوال القديمة غير المستخدمة
DROP TABLE IF EXISTS public.transfer_requests CASCADE;
DROP TABLE IF EXISTS public.completed_transfers CASCADE;
DROP TABLE IF EXISTS public.user_directory CASCADE;
DROP TABLE IF EXISTS public.transfer_limits CASCADE;

-- CLEANUP: Remove old functions
-- حذف الدوال القديمة
DROP FUNCTION IF EXISTS public.process_money_transfer CASCADE;
DROP FUNCTION IF EXISTS public.find_user_by_identifier CASCADE;
DROP FUNCTION IF EXISTS public.check_transfer_limits CASCADE;
DROP FUNCTION IF EXISTS public.normalize_email CASCADE;
DROP FUNCTION IF EXISTS public.generate_transfer_reference CASCADE;
DROP FUNCTION IF EXISTS public.sync_user_directory CASCADE;

-- CORE TABLES: Create simplified system tables
-- الاحتفاظ بالنظام المبسط فقط - التأكد من وجود الجداول المبسطة

-- Table: simple_transfers - جدول التحويلات المبسط
CREATE TABLE IF NOT EXISTS public.simple_transfers (
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

-- Table: simple_balances - جدول الأرصدة المبسط
CREATE TABLE IF NOT EXISTS public.simple_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT UNIQUE NOT NULL,
    user_name TEXT NOT NULL,
    account_number TEXT UNIQUE NOT NULL,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- INDEXES: Performance optimization indexes
-- فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_simple_transfers_sender_email 
    ON public.simple_transfers(sender_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_recipient_email 
    ON public.simple_transfers(recipient_email);
CREATE INDEX IF NOT EXISTS idx_simple_transfers_created_at 
    ON public.simple_transfers(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_simple_balances_email 
    ON public.simple_balances(user_email);
CREATE INDEX IF NOT EXISTS idx_simple_balances_account 
    ON public.simple_balances(account_number);

-- FUNCTION: Generate simple reference number
-- دالة توليد رقم مرجعي بسيط
CREATE OR REPLACE FUNCTION public.generate_simple_reference()
RETURNS TEXT 
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    ref_number TEXT;
BEGIN
    ref_number := 'TR' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    RETURN ref_number;
END;
$;

-- دالة البحث عن المستخدم
CREATE OR REPLACE FUNCTION public.find_user_simple(p_identifier TEXT)
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
    FROM public.simple_balances sb
    WHERE sb.user_email ILIKE '%' || p_identifier || '%'
       OR sb.account_number ILIKE '%' || p_identifier || '%'
       OR sb.user_name ILIKE '%' || p_identifier || '%'
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- دالة عرض الرصيد
CREATE OR REPLACE FUNCTION public.get_user_balance_simple(p_identifier TEXT)
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
    FROM public.simple_balances sb
    WHERE sb.user_email = p_identifier
       OR sb.account_number = p_identifier
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- دالة تحديث الرصيد
CREATE OR REPLACE FUNCTION public.update_user_balance_simple(
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
    FROM public.simple_balances
    WHERE user_email = p_identifier OR account_number = p_identifier;
    
    IF v_user IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المستخدم غير موجود', 0::DECIMAL;
        RETURN;
    END IF;
    
    -- تحديث الرصيد
    UPDATE public.simple_balances
    SET balance = p_new_balance, updated_at = NOW()
    WHERE user_email = v_user.user_email;
    
    RETURN QUERY SELECT TRUE, 'تم تحديث الرصيد بنجاح', p_new_balance;
END;
$$ LANGUAGE plpgsql;

-- دالة التحويل المبسط الرئيسية
CREATE OR REPLACE FUNCTION public.process_simple_transfer(
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
    
    IF p_amount < 100 THEN
        RETURN QUERY SELECT FALSE, 'الحد الأدنى للتحويل هو 100 دج', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- البحث عن المرسل
    SELECT * INTO v_sender
    FROM public.simple_balances
    WHERE user_email = p_sender_email;
    
    IF v_sender IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المرسل غير موجود', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- التحقق من الرصيد
    IF v_sender.balance < p_amount THEN
        RETURN QUERY SELECT FALSE, 'الرصيد غير كافي (الرصيد الحالي: ' || v_sender.balance || ' دج)', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- البحث عن المستلم
    SELECT * INTO v_recipient
    FROM public.simple_balances
    WHERE user_email = p_recipient_identifier OR account_number = p_recipient_identifier;
    
    IF v_recipient IS NULL THEN
        RETURN QUERY SELECT FALSE, 'المستلم غير موجود: "' || p_recipient_identifier || '"', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- منع التحويل للنفس
    IF v_sender.user_email = v_recipient.user_email THEN
        RETURN QUERY SELECT FALSE, 'لا يمكن تحويل الأموال إلى نفس الحساب', NULL::TEXT, NULL::DECIMAL, NULL::DECIMAL;
        RETURN;
    END IF;
    
    -- توليد رقم مرجعي
    v_reference := public.generate_simple_reference();
    
    -- تحديث رصيد المرسل
    UPDATE public.simple_balances
    SET balance = balance - p_amount, updated_at = NOW()
    WHERE user_email = v_sender.user_email;
    
    -- تحديث رصيد المستلم
    UPDATE public.simple_balances
    SET balance = balance + p_amount, updated_at = NOW()
    WHERE user_email = v_recipient.user_email;
    
    -- إضافة سجل التحويل
    INSERT INTO public.simple_transfers (
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
CREATE OR REPLACE FUNCTION public.get_transfer_history_simple(p_user_email TEXT)
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
    FROM public.simple_transfers st
    WHERE st.sender_email = p_user_email OR st.recipient_email = p_user_email
    ORDER BY st.created_at DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- إضافة بيانات تجريبية للاختبار
INSERT INTO public.simple_balances (user_email, user_name, account_number, balance)
VALUES 
    ('user1@example.com', 'أحمد محمد', 'ACC001', 50000),
    ('user2@example.com', 'فاطمة علي', 'ACC002', 30000),
    ('user3@example.com', 'محمد حسن', 'ACC003', 75000),
    ('test@example.com', 'مستخدم تجريبي', 'ACC999', 100000)
ON CONFLICT (user_email) DO UPDATE SET
    user_name = EXCLUDED.user_name,
    account_number = EXCLUDED.account_number,
    balance = EXCLUDED.balance,
    updated_at = NOW();

-- تمكين الوقت الفعلي
DO $$
BEGIN
    -- Add simple_transfers if not already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'simple_transfers'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.simple_transfers;
    END IF;
    
    -- Add simple_balances if not already in publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'simple_balances'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.simple_balances;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'تم تجاهل خطأ في إضافة الجداول للوقت الفعلي: %', SQLERRM;
END $$;

-- إجراء تحويل تجريبي للاختبار
DO $$
DECLARE
    test_result RECORD;
BEGIN
    -- اختبار التحويل من user1 إلى user2
    SELECT * INTO test_result
    FROM public.process_simple_transfer(
        'user1@example.com',
        'user2@example.com', 
        1000,
        'تحويل تجريبي للاختبار'
    );
    
    IF test_result.success THEN
        RAISE NOTICE '✅ نجح التحويل التجريبي: %', test_result.message;
        RAISE NOTICE '📋 رقم المرجع: %', test_result.reference_number;
        RAISE NOTICE '💰 رصيد المرسل الجديد: %', test_result.sender_new_balance;
        RAISE NOTICE '💰 رصيد المستلم الجديد: %', test_result.recipient_new_balance;
    ELSE
        RAISE NOTICE '❌ فشل التحويل التجريبي: %', test_result.message;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '💥 خطأ في التحويل التجريبي: %', SQLERRM;
END $$;

-- =============================================================================
-- انتهاء توحيد نظام التحويلات
-- =============================================================================
