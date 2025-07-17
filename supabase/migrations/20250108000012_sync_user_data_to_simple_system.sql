-- =============================================================================
-- USER DATA SYNCHRONIZATION WITH SIMPLIFIED SYSTEM
-- مزامنة بيانات المستخدمين مع النظام المبسط
-- Created: 2025-01-08
-- تاريخ الإنشاء: 2025-01-08
-- Purpose: Transfer existing user data to the simplified system
-- الهدف: نقل بيانات المستخدمين الحاليين إلى النظام المبسط
-- =============================================================================

-- DATA SYNC: Migrate user data from users table to simple_balances
-- مزامنة بيانات المستخدمين من جدول users إلى simple_balances
INSERT INTO public.simple_balances (user_email, user_name, account_number, balance)
SELECT 
    u.email as user_email,
    u.full_name as user_name,
    u.account_number,
    COALESCE(b.dzd, 15000) as balance
FROM public.users u
LEFT JOIN public.balances b ON u.id = b.user_id
WHERE u.email IS NOT NULL 
  AND u.full_name IS NOT NULL 
  AND u.account_number IS NOT NULL
ON CONFLICT (user_email) DO UPDATE SET
    user_name = EXCLUDED.user_name,
    account_number = EXCLUDED.account_number,
    balance = EXCLUDED.balance,
    updated_at = NOW();

-- TRIGGER FUNCTION: Auto-sync data to simple_balances
-- إنشاء محفز لمزامنة البيانات تلقائياً
CREATE OR REPLACE FUNCTION public.sync_to_simple_balances()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $
BEGIN
    -- عند إدراج مستخدم جديد
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.simple_balances (user_email, user_name, account_number, balance)
        VALUES (
            NEW.email,
            NEW.full_name,
            NEW.account_number,
            15000 -- رصيد افتراضي
        )
        ON CONFLICT (user_email) DO UPDATE SET
            user_name = EXCLUDED.user_name,
            account_number = EXCLUDED.account_number,
            updated_at = NOW();
        RETURN NEW;
    END IF;
    
    -- عند تحديث مستخدم
    IF TG_OP = 'UPDATE' THEN
        UPDATE public.simple_balances
        SET user_name = NEW.full_name,
            account_number = NEW.account_number,
            updated_at = NOW()
        WHERE user_email = NEW.email;
        RETURN NEW;
    END IF;
    
    -- عند حذف مستخدم
    IF TG_OP = 'DELETE' THEN
        DELETE FROM public.simple_balances WHERE user_email = OLD.email;
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- TRIGGER: Create sync trigger for users table
-- إنشاء المحفز
DROP TRIGGER IF EXISTS trigger_sync_to_simple_balances ON public.users;
CREATE TRIGGER trigger_sync_to_simple_balances
    AFTER INSERT OR UPDATE OR DELETE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_to_simple_balances();

-- TRIGGER FUNCTION: Sync balance updates to simple system
-- محفز لمزامنة تحديثات الرصيد
CREATE OR REPLACE FUNCTION public.sync_balance_to_simple()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $
DECLARE
    v_user_email TEXT;
BEGIN
    -- الحصول على البريد الإلكتروني للمستخدم
    SELECT email INTO v_user_email
    FROM public.users
    WHERE id = COALESCE(NEW.user_id, OLD.user_id);
    
    IF v_user_email IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- عند إدراج أو تحديث رصيد
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE public.simple_balances
        SET balance = NEW.dzd,
            updated_at = NOW()
        WHERE user_email = v_user_email;
        RETURN NEW;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- TRIGGER: Create sync trigger for balances table
-- إنشاء المحفز للأرصدة
DROP TRIGGER IF EXISTS trigger_sync_balance_to_simple ON public.balances;
CREATE TRIGGER trigger_sync_balance_to_simple
    AFTER INSERT OR UPDATE ON public.balances
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_balance_to_simple();

-- اختبار النظام الموحد
DO $$
DECLARE
    test_result RECORD;
    user_count INTEGER;
    balance_count INTEGER;
BEGIN
    -- عد المستخدمين في النظام المبسط
    SELECT COUNT(*) INTO user_count FROM public.simple_balances;
    RAISE NOTICE '👥 عدد المستخدمين في النظام المبسط: %', user_count;
    
    -- عرض بعض المستخدمين للاختبار
    FOR test_result IN 
        SELECT user_email, user_name, account_number, balance 
        FROM public.simple_balances 
        LIMIT 5
    LOOP
        RAISE NOTICE '👤 مستخدم: % (%) - الرصيد: % دج', 
            test_result.user_name, 
            test_result.user_email, 
            test_result.balance;
    END LOOP;
    
    -- اختبار البحث
    RAISE NOTICE '🔍 اختبار البحث:';
    FOR test_result IN 
        SELECT * FROM public.find_user_simple('user')
    LOOP
        RAISE NOTICE '🔍 نتيجة البحث: % (%) - %', 
            test_result.user_name, 
            test_result.user_email, 
            test_result.account_number;
    END LOOP;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ خطأ في الاختبار: %', SQLERRM;
END $$;

-- =============================================================================
-- انتهاء مزامنة بيانات المستخدمين
-- =============================================================================