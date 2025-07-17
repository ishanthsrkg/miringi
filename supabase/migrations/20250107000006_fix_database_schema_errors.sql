-- إصلاح أخطاء قاعدة البيانات وتحسين التنسيق
-- تاريخ الإنشاء: 2025-01-07
-- الهدف: إصلاح جميع المشاكل المكتشفة في قاعدة البيانات

-- =============================================================================
-- إزالة الجداول غير المستخدمة
-- =============================================================================

-- إزالة جدول AMIN غير المستخدم
DROP TABLE IF EXISTS public.AMIN CASCADE;

-- =============================================================================
-- إصلاح جدول المستخدمين
-- =============================================================================

-- إضافة قيود افتراضية مفقودة
ALTER TABLE public.users 
ALTER COLUMN language SET DEFAULT 'ar',
ALTER COLUMN currency SET DEFAULT 'dzd',
ALTER COLUMN is_active SET DEFAULT true;

-- إضافة قيود NOT NULL للحقول المهمة
ALTER TABLE public.users 
ALTER COLUMN email SET NOT NULL,
ALTER COLUMN full_name SET NOT NULL,
ALTER COLUMN account_number SET NOT NULL,
ALTER COLUMN join_date SET NOT NULL;

-- =============================================================================
-- إصلاح جدول الأرصدة
-- =============================================================================

-- إضافة قيود افتراضية وNOT NULL للأرصدة
ALTER TABLE public.balances 
ALTER COLUMN dzd SET DEFAULT 0.00,
ALTER COLUMN dzd SET NOT NULL,
ALTER COLUMN eur SET DEFAULT 0.00,
ALTER COLUMN eur SET NOT NULL,
ALTER COLUMN usd SET DEFAULT 0.00,
ALTER COLUMN usd SET NOT NULL,
ALTER COLUMN gbp SET DEFAULT 0.00,
ALTER COLUMN gbp SET NOT NULL;

-- إضافة قيود للتحقق من صحة الأرصدة
ALTER TABLE public.balances 
ADD CONSTRAINT check_positive_dzd CHECK (dzd >= 0),
ADD CONSTRAINT check_positive_eur CHECK (eur >= 0),
ADD CONSTRAINT check_positive_usd CHECK (usd >= 0),
ADD CONSTRAINT check_positive_gbp CHECK (gbp >= 0);

-- =============================================================================
-- إصلاح جدول الاستثمارات
-- =============================================================================

-- إضافة قيود افتراضية مفقودة
ALTER TABLE public.investments 
ALTER COLUMN profit SET DEFAULT 0.00,
ALTER COLUMN profit SET NOT NULL,
ALTER COLUMN status SET DEFAULT 'active';

-- إضافة قيود للتحقق من صحة البيانات
ALTER TABLE public.investments 
ADD CONSTRAINT check_positive_amount CHECK (amount > 0),
ADD CONSTRAINT check_valid_profit_rate CHECK (profit_rate >= 0 AND profit_rate <= 100),
ADD CONSTRAINT check_positive_profit CHECK (profit >= 0);

-- =============================================================================
-- إصلاح جدول البطاقات
-- =============================================================================

-- إضافة قيود افتراضية مفقودة
ALTER TABLE public.cards 
ALTER COLUMN is_frozen SET DEFAULT false,
ALTER COLUMN is_frozen SET NOT NULL,
ALTER COLUMN spending_limit SET DEFAULT 0.00,
ALTER COLUMN spending_limit SET NOT NULL;

-- إضافة قيود للتحقق من صحة البيانات
ALTER TABLE public.cards 
ADD CONSTRAINT check_positive_spending_limit CHECK (spending_limit >= 0);

-- =============================================================================
-- إصلاح جدول الإشعارات
-- =============================================================================

-- إضافة قيود افتراضية مفقودة
ALTER TABLE public.notifications 
ALTER COLUMN is_read SET DEFAULT false,
ALTER COLUMN is_read SET NOT NULL;

-- إضافة قيود NOT NULL للحقول المهمة
ALTER TABLE public.notifications 
ALTER COLUMN type SET NOT NULL,
ALTER COLUMN title SET NOT NULL,
ALTER COLUMN message SET NOT NULL;

-- =============================================================================
-- إصلاح جدول الإحالات
-- =============================================================================

-- إضافة قيود افتراضية مفقودة
ALTER TABLE public.referrals 
ALTER COLUMN reward_amount SET DEFAULT 500.00,
ALTER COLUMN status SET DEFAULT 'pending';

-- إضافة قيود للتحقق من صحة البيانات
ALTER TABLE public.referrals 
ADD CONSTRAINT check_positive_reward CHECK (reward_amount >= 0);

-- =============================================================================
-- إصلاح جدول المعاملات
-- =============================================================================

-- إضافة قيود افتراضية مفقودة
ALTER TABLE public.transactions 
ALTER COLUMN currency SET DEFAULT 'dzd',
ALTER COLUMN status SET DEFAULT 'completed';

-- إضافة قيود NOT NULL للحقول المهمة
ALTER TABLE public.transactions 
ALTER COLUMN type SET NOT NULL,
ALTER COLUMN amount SET NOT NULL,
ALTER COLUMN description SET NOT NULL;

-- إضافة قيود للتحقق من صحة البيانات
ALTER TABLE public.transactions 
ADD CONSTRAINT check_positive_transaction_amount CHECK (amount > 0);

-- =============================================================================
-- إصلاح جدول أهداف الادخار
-- =============================================================================

-- إضافة قيود افتراضية مفقودة
ALTER TABLE public.savings_goals 
ALTER COLUMN current_amount SET DEFAULT 0.00,
ALTER COLUMN current_amount SET NOT NULL,
ALTER COLUMN status SET DEFAULT 'active';

-- إضافة قيود NOT NULL للحقول المهمة
ALTER TABLE public.savings_goals 
ALTER COLUMN name SET NOT NULL,
ALTER COLUMN target_amount SET NOT NULL,
ALTER COLUMN deadline SET NOT NULL,
ALTER COLUMN category SET NOT NULL,
ALTER COLUMN icon SET NOT NULL,
ALTER COLUMN color SET NOT NULL;

-- إضافة قيود للتحقق من صحة البيانات
ALTER TABLE public.savings_goals 
ADD CONSTRAINT check_positive_target_amount CHECK (target_amount > 0),
ADD CONSTRAINT check_positive_current_amount CHECK (current_amount >= 0),
ADD CONSTRAINT check_current_not_exceed_target CHECK (current_amount <= target_amount);

-- =============================================================================
-- إضافة فهارس للأداء
-- =============================================================================

-- فهارس إضافية لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_balances_updated_at ON public.balances(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_investments_user_status ON public.investments(user_id, status);
CREATE INDEX IF NOT EXISTS idx_savings_goals_user_status ON public.savings_goals(user_id, status);
CREATE INDEX IF NOT EXISTS idx_cards_user_type ON public.cards(user_id, card_type);
CREATE INDEX IF NOT EXISTS idx_transactions_type_status ON public.transactions(type, status);

-- =============================================================================
-- إصلاح دالة handle_new_user
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_account_number TEXT;
BEGIN
    -- إنشاء رقم حساب فريد
    new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
    
    -- التأكد من عدم تكرار رقم الحساب
    WHILE EXISTS (SELECT 1 FROM public.users WHERE account_number = new_account_number) LOOP
        new_account_number := 'ACC' || LPAD(FLOOR(RANDOM() * 1000000000)::TEXT, 9, '0');
    END LOOP;
    
    -- إدراج ملف المستخدم
    INSERT INTO public.users (
        id, 
        email, 
        full_name, 
        phone, 
        account_number, 
        join_date,
        language,
        currency,
        is_active
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        new_account_number,
        timezone('utc'::text, now()),
        'ar',
        'dzd',
        true
    );
    
    -- إنشاء سجل رصيد أولي
    INSERT INTO public.balances (user_id, dzd, eur, usd, gbp)
    VALUES (NEW.id, 15000.00, 75.00, 85.00, 65.50);
    
    RETURN NEW;
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- إضافة دوال للتحقق من صحة البيانات
-- =============================================================================

-- دالة للتحقق من صحة رموز العملات
CREATE OR REPLACE FUNCTION public.validate_currency_code(currency_code TEXT)
RETURNS BOOLEAN AS $
BEGIN
    RETURN currency_code IN ('dzd', 'eur', 'usd', 'gbp');
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- دالة للتحقق من صحة أنواع المعاملات
CREATE OR REPLACE FUNCTION public.validate_transaction_type(transaction_type TEXT)
RETURNS BOOLEAN AS $
BEGIN
    RETURN transaction_type IN ('recharge', 'transfer', 'bill', 'investment', 'conversion', 'withdrawal');
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- =============================================================================
-- إضافة دوال لحساب أرباح الاستثمار
-- =============================================================================

-- دالة لحساب ربح الاستثمار
CREATE OR REPLACE FUNCTION public.calculate_investment_profit(investment_id UUID)
RETURNS DECIMAL AS $
DECLARE
    investment_record RECORD;
    days_passed INTEGER;
    profit_amount DECIMAL;
BEGIN
    -- جلب بيانات الاستثمار
    SELECT * INTO investment_record 
    FROM public.investments 
    WHERE id = investment_id;
    
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    
    -- حساب عدد الأيام المنقضية
    days_passed := EXTRACT(DAY FROM (NOW() - investment_record.start_date));
    
    -- حساب الربح بناءً على النوع
    CASE investment_record.type
        WHEN 'weekly' THEN
            profit_amount := investment_record.amount * (investment_record.profit_rate / 100) * (days_passed / 7.0);
        WHEN 'monthly' THEN
            profit_amount := investment_record.amount * (investment_record.profit_rate / 100) * (days_passed / 30.0);
        WHEN 'quarterly' THEN
            profit_amount := investment_record.amount * (investment_record.profit_rate / 100) * (days_passed / 90.0);
        WHEN 'yearly' THEN
            profit_amount := investment_record.amount * (investment_record.profit_rate / 100) * (days_passed / 365.0);
        ELSE
            profit_amount := 0;
    END CASE;
    
    RETURN GREATEST(profit_amount, 0);
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- دالة لتحديث أرباح الاستثمار
CREATE OR REPLACE FUNCTION public.update_investment_profit()
RETURNS TRIGGER AS $
BEGIN
    NEW.profit := public.calculate_investment_profit(NEW.id);
    RETURN NEW;
END;
$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- إنشاء محفز لتحديث أرباح الاستثمار تلقائياً
DROP TRIGGER IF EXISTS trigger_update_investment_profit ON public.investments;
CREATE TRIGGER trigger_update_investment_profit
    BEFORE UPDATE ON public.investments
    FOR EACH ROW
    EXECUTE FUNCTION public.update_investment_profit();

-- =============================================================================
-- تحديث الأنواع في TypeScript
-- =============================================================================

-- تحديث أنواع البيانات لتتماشى مع التغييرات
COMMENT ON TABLE public.users IS 'جدول المستخدمين - يحتوي على معلومات الملف الشخصي';
COMMENT ON TABLE public.balances IS 'جدول الأرصدة - يحتوي على أرصدة العملات المختلفة';
COMMENT ON TABLE public.transactions IS 'جدول المعاملات - يسجل جميع العمليات المالية';
COMMENT ON TABLE public.investments IS 'جدول الاستثمارات - يتتبع المنتجات الاستثمارية';
COMMENT ON TABLE public.savings_goals IS 'جدول أهداف الادخار - أهداف الادخار المحددة من المستخدم';
COMMENT ON TABLE public.cards IS 'جدول البطاقات - البطاقات المادية والافتراضية';
COMMENT ON TABLE public.notifications IS 'جدول الإشعارات - إشعارات النظام والمستخدم';
COMMENT ON TABLE public.referrals IS 'جدول الإحالات - نظام إحالة المستخدمين';

-- =============================================================================
-- إنهاء الإصلاحات
-- =============================================================================

-- تم إصلاح جميع المشاكل المكتشفة في قاعدة البيانات
-- تم إضافة القيود والفهارس اللازمة لضمان سلامة البيانات والأداء
