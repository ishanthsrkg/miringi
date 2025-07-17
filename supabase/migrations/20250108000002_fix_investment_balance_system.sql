-- إصلاح نظام رصيد الاستثمار وضمان التحديث الصحيح للأرصدة
-- تاريخ الإنشاء: 2025-01-08
-- الهدف: ضمان عمل نظام الاستثمار بشكل صحيح مع قاعدة البيانات

-- =============================================================================
-- التأكد من وجود عمود investment_balance في جدول balances
-- =============================================================================

ALTER TABLE public.balances 
ADD COLUMN IF NOT EXISTS investment_balance DECIMAL(15,2) DEFAULT 0.00 NOT NULL;

-- تحديث القيم الفارغة إلى صفر
UPDATE public.balances 
SET investment_balance = 0.00 
WHERE investment_balance IS NULL;

-- إضافة قيد للتحقق من أن رصيد الاستثمار لا يكون سالباً
DO $$
BEGIN
    -- حذف القيد إذا كان موجوداً
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
               WHERE constraint_name = 'check_positive_investment_balance' 
               AND table_name = 'balances') THEN
        ALTER TABLE public.balances DROP CONSTRAINT check_positive_investment_balance;
    END IF;
    
    -- إضافة القيد الجديد
    ALTER TABLE public.balances ADD CONSTRAINT check_positive_investment_balance CHECK (investment_balance >= 0);
END $$;

-- =============================================================================
-- إنشاء دالة لتحديث الأرصدة بشكل آمن
-- =============================================================================

CREATE OR REPLACE FUNCTION public.update_user_balance(
    p_user_id UUID,
    p_dzd DECIMAL DEFAULT NULL,
    p_eur DECIMAL DEFAULT NULL,
    p_usd DECIMAL DEFAULT NULL,
    p_gbp DECIMAL DEFAULT NULL,
    p_investment_balance DECIMAL DEFAULT NULL
)
RETURNS TABLE(
    user_id UUID,
    dzd DECIMAL,
    eur DECIMAL,
    usd DECIMAL,
    gbp DECIMAL,
    investment_balance DECIMAL,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    -- تحديث الأرصدة مع الحفاظ على القيم الحالية للحقول غير المحددة
    UPDATE public.balances 
    SET 
        dzd = COALESCE(p_dzd, balances.dzd),
        eur = COALESCE(p_eur, balances.eur),
        usd = COALESCE(p_usd, balances.usd),
        gbp = COALESCE(p_gbp, balances.gbp),
        investment_balance = COALESCE(p_investment_balance, balances.investment_balance),
        updated_at = NOW()
    WHERE balances.user_id = p_user_id;
    
    -- إرجاع البيانات المحدثة
    RETURN QUERY
    SELECT 
        balances.user_id,
        balances.dzd,
        balances.eur,
        balances.usd,
        balances.gbp,
        balances.investment_balance,
        balances.updated_at
    FROM public.balances
    WHERE balances.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- إنشاء دالة لإدارة الاستثمارات
-- =============================================================================

CREATE OR REPLACE FUNCTION public.process_investment(
    p_user_id UUID,
    p_amount DECIMAL,
    p_operation TEXT -- 'invest' أو 'return'
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    new_dzd_balance DECIMAL,
    new_investment_balance DECIMAL
) AS $$
DECLARE
    current_dzd DECIMAL;
    current_investment DECIMAL;
    new_dzd DECIMAL;
    new_investment DECIMAL;
BEGIN
    -- جلب الأرصدة الحالية
    SELECT dzd, investment_balance 
    INTO current_dzd, current_investment
    FROM public.balances 
    WHERE user_id = p_user_id;
    
    -- التحقق من وجود المستخدم
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'المستخدم غير موجود'::TEXT, 0::DECIMAL, 0::DECIMAL;
        RETURN;
    END IF;
    
    -- معالجة العملية حسب النوع
    IF p_operation = 'invest' THEN
        -- التحقق من كفاية الرصيد
        IF current_dzd < p_amount THEN
            RETURN QUERY SELECT FALSE, 'رصيد غير كافي'::TEXT, current_dzd, current_investment;
            RETURN;
        END IF;
        
        -- خصم من الرصيد الأساسي وإضافة لرصيد الاستثمار
        new_dzd := current_dzd - p_amount;
        new_investment := current_investment + p_amount;
        
    ELSIF p_operation = 'return' THEN
        -- إضافة للرصيد الأساسي وخصم من رصيد الاستثمار
        new_dzd := current_dzd + p_amount;
        new_investment := GREATEST(current_investment - p_amount, 0);
        
    ELSE
        RETURN QUERY SELECT FALSE, 'نوع العملية غير صحيح'::TEXT, current_dzd, current_investment;
        RETURN;
    END IF;
    
    -- تحديث الأرصدة
    UPDATE public.balances 
    SET 
        dzd = new_dzd,
        investment_balance = new_investment,
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    -- إرجاع النتيجة
    RETURN QUERY SELECT TRUE, 'تم بنجاح'::TEXT, new_dzd, new_investment;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- إنشاء دالة لحساب إجمالي الاستثمارات النشطة
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_user_investment_summary(p_user_id UUID)
RETURNS TABLE(
    total_invested DECIMAL,
    total_profit DECIMAL,
    active_investments INTEGER,
    completed_investments INTEGER,
    investment_balance DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(CASE WHEN i.status = 'active' THEN i.amount ELSE 0 END), 0) as total_invested,
        COALESCE(SUM(CASE WHEN i.status = 'completed' THEN i.profit ELSE 0 END), 0) as total_profit,
        COUNT(CASE WHEN i.status = 'active' THEN 1 END)::INTEGER as active_investments,
        COUNT(CASE WHEN i.status = 'completed' THEN 1 END)::INTEGER as completed_investments,
        COALESCE(b.investment_balance, 0) as investment_balance
    FROM public.investments i
    RIGHT JOIN public.balances b ON b.user_id = p_user_id
    WHERE i.user_id = p_user_id OR i.user_id IS NULL
    GROUP BY b.investment_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- إنشاء محفز لتحديث رصيد الاستثمار عند تغيير حالة الاستثمار
-- =============================================================================

CREATE OR REPLACE FUNCTION public.update_investment_balance_on_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- عند إكمال الاستثمار، إرجاع المبلغ + الأرباح للرصيد الأساسي
    IF OLD.status = 'active' AND NEW.status = 'completed' THEN
        -- إضافة المبلغ الأصلي + الأرباح للرصيد الأساسي
        UPDATE public.balances 
        SET 
            dzd = dzd + NEW.amount + NEW.profit,
            investment_balance = GREATEST(investment_balance - NEW.amount, 0),
            updated_at = NOW()
        WHERE user_id = NEW.user_id;
        
        -- إضافة معاملة لتسجيل عائد الاستثمار
        INSERT INTO public.transactions (
            user_id,
            type,
            amount,
            currency,
            description,
            status,
            created_at
        ) VALUES (
            NEW.user_id,
            'investment',
            NEW.amount + NEW.profit,
            'dzd',
            'عائد استثمار - ' || NEW.type,
            'completed',
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- إنشاء المحفز
DROP TRIGGER IF EXISTS trigger_investment_status_change ON public.investments;
CREATE TRIGGER trigger_investment_status_change
    AFTER UPDATE ON public.investments
    FOR EACH ROW
    EXECUTE FUNCTION public.update_investment_balance_on_status_change();

-- =============================================================================
-- إضافة فهارس لتحسين الأداء
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_balances_user_investment ON public.balances(user_id, investment_balance);
CREATE INDEX IF NOT EXISTS idx_investments_user_status_amount ON public.investments(user_id, status, amount);

-- =============================================================================
-- منح الصلاحيات اللازمة
-- =============================================================================

-- منح صلاحيات تنفيذ الدوال للمستخدمين المصرح لهم
GRANT EXECUTE ON FUNCTION public.update_user_balance TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_investment TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_investment_summary TO authenticated;

-- =============================================================================
-- تحديث البيانات الموجودة
-- =============================================================================

-- التأكد من أن جميع المستخدمين لديهم رصيد استثمار
UPDATE public.balances 
SET investment_balance = 0.00 
WHERE investment_balance IS NULL;

-- تحديث أرصدة الاستثمار بناءً على الاستثمارات النشطة
UPDATE public.balances 
SET investment_balance = (
    SELECT COALESCE(SUM(amount), 0)
    FROM public.investments 
    WHERE investments.user_id = balances.user_id 
    AND investments.status = 'active'
)
WHERE EXISTS (
    SELECT 1 FROM public.investments 
    WHERE investments.user_id = balances.user_id
);

-- =============================================================================
-- إضافة تعليقات للتوثيق
-- =============================================================================

COMMENT ON FUNCTION public.update_user_balance IS 'دالة لتحديث أرصدة المستخدم بشكل آمن مع الحفاظ على القيم الحالية';
COMMENT ON FUNCTION public.process_investment IS 'دالة لمعالجة عمليات الاستثمار (استثمار أو إرجاع)';
COMMENT ON FUNCTION public.get_user_investment_summary IS 'دالة لجلب ملخص استثمارات المستخدم';
COMMENT ON COLUMN public.balances.investment_balance IS 'رصيد الاستثمار - المبلغ المستثمر حالياً';