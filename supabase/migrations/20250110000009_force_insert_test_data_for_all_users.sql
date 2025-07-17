-- =============================================================================
-- FORCE INSERT TEST DATA FOR ALL AUTH.USERS
-- إدخال بيانات تجريبية إجبارية لجميع المستخدمين في auth.users
-- Created: 2025-01-10
-- Purpose: Ensure ALL users from auth.users appear in ALL tables with test data
-- =============================================================================

-- =============================================================================
-- STEP 1: Force insert test data for ALL existing auth.users
-- =============================================================================

DO $force_insert_all_users_data$
DECLARE
    auth_user RECORD;
    test_counter INTEGER := 1;
    v_account_number TEXT;
    v_referral_code TEXT;
    total_auth_users INTEGER;
BEGIN
    -- Count total auth users
    SELECT COUNT(*) INTO total_auth_users FROM auth.users;
    
    RAISE NOTICE '============================================================';
    RAISE NOTICE '=== بدء إدخال البيانات التجريبية لجميع المستخدمين ===';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'إجمالي المستخدمين في auth.users: %', total_auth_users;
    RAISE NOTICE '';
    
    -- Loop through ALL auth.users and create comprehensive test data
    FOR auth_user IN 
        SELECT id, email, created_at, email_confirmed_at
        FROM auth.users 
        ORDER BY created_at
    LOOP
        -- Generate unique identifiers
        v_account_number := 'ACC' || LPAD(test_counter::TEXT, 9, '0');
        v_referral_code := 'REF' || LPAD(test_counter::TEXT, 6, '0');
        
        RAISE NOTICE 'معالجة المستخدم %: % (ID: %)', test_counter, auth_user.email, auth_user.id;
        
        -- Insert user profile with proper UID linking (FORCE INSERT/UPDATE)
        INSERT INTO public.users (
            id, email, full_name, phone, account_number, 
            referral_code, is_active, is_verified, verification_status,
            join_date, created_at, updated_at
        ) VALUES (
            auth_user.id,
            auth_user.email,
            'مستخدم تجريبي ' || test_counter || ' - ' || SPLIT_PART(auth_user.email, '@', 1),
            '+213' || (500000000 + test_counter)::TEXT,
            v_account_number,
            v_referral_code,
            true,
            (test_counter % 3 = 0), -- Every 3rd user is verified
            CASE WHEN test_counter % 3 = 0 THEN 'approved' ELSE 'pending' END,
            COALESCE(auth_user.created_at, timezone('utc'::text, now())),
            COALESCE(auth_user.created_at, timezone('utc'::text, now())),
            timezone('utc'::text, now())
        ) ON CONFLICT (id) DO UPDATE SET
            email = EXCLUDED.email,
            full_name = EXCLUDED.full_name,
            phone = EXCLUDED.phone,
            account_number = EXCLUDED.account_number,
            referral_code = EXCLUDED.referral_code,
            is_active = EXCLUDED.is_active,
            is_verified = EXCLUDED.is_verified,
            verification_status = EXCLUDED.verification_status,
            join_date = EXCLUDED.join_date,
            updated_at = timezone('utc'::text, now());
        
        -- Insert balance with proper UID linking (FORCE INSERT/UPDATE)
        INSERT INTO public.balances (
            user_id, dzd, eur, usd, gbp, investment_balance, created_at, updated_at
        ) VALUES (
            auth_user.id,
            (15000 + (test_counter * 1000) + FLOOR(RANDOM() * 5000))::DECIMAL,
            (75 + test_counter + FLOOR(RANDOM() * 25))::DECIMAL,
            (85 + test_counter + FLOOR(RANDOM() * 30))::DECIMAL,
            (65 + test_counter + FLOOR(RANDOM() * 20))::DECIMAL,
            (1000 + (test_counter * 100) + FLOOR(RANDOM() * 500))::DECIMAL,
            COALESCE(auth_user.created_at, timezone('utc'::text, now())),
            timezone('utc'::text, now())
        ) ON CONFLICT (user_id) DO UPDATE SET
            dzd = EXCLUDED.dzd,
            eur = EXCLUDED.eur,
            usd = EXCLUDED.usd,
            gbp = EXCLUDED.gbp,
            investment_balance = EXCLUDED.investment_balance,
            updated_at = timezone('utc'::text, now());
        
        -- Insert simple_balances with proper email linking (FORCE INSERT/UPDATE)
        INSERT INTO public.simple_balances (
            user_email, user_name, account_number, balance, updated_at
        ) VALUES (
            auth_user.email,
            'مستخدم تجريبي ' || test_counter || ' - ' || SPLIT_PART(auth_user.email, '@', 1),
            v_account_number,
            (15000 + (test_counter * 1000) + FLOOR(RANDOM() * 5000))::DECIMAL,
            timezone('utc'::text, now())
        ) ON CONFLICT (user_email) DO UPDATE SET
            user_name = EXCLUDED.user_name,
            account_number = EXCLUDED.account_number,
            balance = EXCLUDED.balance,
            updated_at = timezone('utc'::text, now());
        
        -- Insert sample transactions with proper UID linking (FORCE INSERT)
        -- Delete existing transactions for this user first to avoid duplicates
        DELETE FROM public.transactions WHERE user_id = auth_user.id;
        
        INSERT INTO public.transactions (
            user_id, type, amount, currency, description, status, created_at
        ) VALUES 
            (auth_user.id, 'recharge', (5000 + FLOOR(RANDOM() * 3000))::DECIMAL, 'dzd', 'شحن تجريبي أولي - ' || test_counter, 'completed', COALESCE(auth_user.created_at, timezone('utc'::text, now()))),
            (auth_user.id, 'transfer', (-(1000 + FLOOR(RANDOM() * 500)))::DECIMAL, 'dzd', 'تحويل تجريبي - ' || test_counter, 'completed', timezone('utc'::text, now() - interval '1 day')),
            (auth_user.id, 'investment', (2000 + FLOOR(RANDOM() * 1000))::DECIMAL, 'dzd', 'عائد استثمار تجريبي - ' || test_counter, 'completed', timezone('utc'::text, now() - interval '2 days')),
            (auth_user.id, 'payment', (-(500 + FLOOR(RANDOM() * 300)))::DECIMAL, 'dzd', 'دفع فاتورة تجريبية - ' || test_counter, 'completed', timezone('utc'::text, now() - interval '3 days')),
            (auth_user.id, 'reward', (250 + FLOOR(RANDOM() * 100))::DECIMAL, 'dzd', 'مكافأة إحالة تجريبية - ' || test_counter, 'completed', timezone('utc'::text, now() - interval '4 days'));
        
        -- Insert sample cards with proper UID linking (FORCE INSERT)
        -- Delete existing cards for this user first to avoid duplicates
        DELETE FROM public.cards WHERE user_id = auth_user.id;
        
        INSERT INTO public.cards (
            user_id, card_number, card_type, is_frozen, spending_limit, balance, currency, created_at, updated_at
        ) VALUES 
            (auth_user.id, '4532' || LPAD((1000000000 + test_counter)::TEXT, 12, '0'), 'solid', false, 100000.00, FLOOR(RANDOM() * 1000)::DECIMAL, 'dzd', timezone('utc'::text, now()), timezone('utc'::text, now())),
            (auth_user.id, '5555' || LPAD((2000000000 + test_counter)::TEXT, 12, '0'), 'virtual', false, 50000.00, FLOOR(RANDOM() * 500)::DECIMAL, 'dzd', timezone('utc'::text, now()), timezone('utc'::text, now()));
        
        -- Insert sample notifications with proper UID linking (FORCE INSERT)
        -- Delete existing notifications for this user first to avoid duplicates
        DELETE FROM public.notifications WHERE user_id = auth_user.id;
        
        INSERT INTO public.notifications (
            user_id, type, title, message, is_read, created_at
        ) VALUES 
            (auth_user.id, 'success', 'مرحباً بك', 'تم إنشاء حسابك بنجاح - المستخدم ' || test_counter, false, timezone('utc'::text, now())),
            (auth_user.id, 'info', 'نصيحة مالية', 'قم بتوثيق حسابك للحصول على مزايا إضافية - المستخدم ' || test_counter, false, timezone('utc'::text, now() - interval '1 hour')),
            (auth_user.id, 'warning', 'تنبيه أمني', 'تم تسجيل دخول جديد إلى حسابك - المستخدم ' || test_counter, true, timezone('utc'::text, now() - interval '2 hours')),
            (auth_user.id, 'success', 'تحويل ناجح', 'تم إتمام التحويل بنجاح - المستخدم ' || test_counter, true, timezone('utc'::text, now() - interval '1 day'));
        
        -- Insert sample savings goal with proper UID linking (FORCE INSERT)
        -- Delete existing savings goals for this user first to avoid duplicates
        DELETE FROM public.savings_goals WHERE user_id = auth_user.id;
        
        INSERT INTO public.savings_goals (
            user_id, name, target_amount, current_amount, deadline, category, status, created_at, updated_at
        ) VALUES (
            auth_user.id, 
            'هدف ادخار تجريبي - المستخدم ' || test_counter, 
            (50000 + (test_counter * 1000))::DECIMAL, 
            FLOOR(RANDOM() * 10000)::DECIMAL, 
            timezone('utc'::text, now() + interval '6 months'), 
            'عام', 
            'active', 
            timezone('utc'::text, now()), 
            timezone('utc'::text, now())
        );
        
        -- Insert sample investment with proper UID linking (FORCE INSERT)
        -- Delete existing investments for this user first to avoid duplicates
        DELETE FROM public.investments WHERE user_id = auth_user.id;
        
        INSERT INTO public.investments (
            user_id, type, amount, profit_rate, start_date, end_date, status, created_at, updated_at
        ) VALUES (
            auth_user.id, 
            CASE WHEN test_counter % 3 = 0 THEN 'monthly' WHEN test_counter % 3 = 1 THEN 'quarterly' ELSE 'yearly' END, 
            (5000 + (test_counter * 500))::DECIMAL, 
            (8.5 + (RANDOM() * 3))::DECIMAL, 
            timezone('utc'::text, now() - interval '1 month'), 
            timezone('utc'::text, now() + interval '11 months'), 
            'active', 
            timezone('utc'::text, now()), 
            timezone('utc'::text, now())
        );
        
        -- Insert sample support message with proper UID linking (FORCE INSERT)
        -- Delete existing support messages for this user first to avoid duplicates
        DELETE FROM public.support_messages WHERE user_id = auth_user.id;
        
        INSERT INTO public.support_messages (
            user_id, subject, message, status, priority, created_at, updated_at
        ) VALUES (
            auth_user.id,
            'استفسار تجريبي - المستخدم ' || test_counter,
            'هذه رسالة دعم تجريبية للمستخدم رقم ' || test_counter || '. أحتاج مساعدة في استخدام التطبيق.',
            'open',
            'medium',
            timezone('utc'::text, now() - interval '2 hours'),
            timezone('utc'::text, now() - interval '2 hours')
        );
        
        -- Insert sample account verification with proper UID linking (FORCE INSERT)
        -- Delete existing account verifications for this user first to avoid duplicates
        DELETE FROM public.account_verifications WHERE user_id = auth_user.id;
        
        INSERT INTO public.account_verifications (
            user_id, verification_type, status, document_url, notes, created_at, updated_at
        ) VALUES (
            auth_user.id,
            'identity',
            CASE WHEN test_counter % 4 = 0 THEN 'approved' WHEN test_counter % 4 = 1 THEN 'pending' WHEN test_counter % 4 = 2 THEN 'rejected' ELSE 'under_review' END,
            'https://example.com/document_' || test_counter || '.pdf',
            'وثيقة تجريبية للمستخدم رقم ' || test_counter,
            timezone('utc'::text, now() - interval '1 day'),
            timezone('utc'::text, now() - interval '1 day')
        );
        
        test_counter := test_counter + 1;
        
        -- Add a small delay every 10 users to avoid overwhelming the database
        IF test_counter % 10 = 0 THEN
            PERFORM pg_sleep(0.1);
            RAISE NOTICE 'تم معالجة % مستخدم حتى الآن...', test_counter - 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ تم إنشاء بيانات تجريبية شاملة لـ % مستخدم', test_counter - 1;
    RAISE NOTICE '';
END $force_insert_all_users_data$;

-- =============================================================================
-- STEP 2: Create sample transfers between users
-- =============================================================================

DO $create_sample_transfers$
DECLARE
    transfer_counter INTEGER := 0;
BEGIN
    RAISE NOTICE 'إنشاء تحويلات تجريبية بين المستخدمين...';
    
    -- Delete existing sample transfers first
    DELETE FROM public.simple_transfers WHERE description LIKE '%تحويل تجريبي%';
    
    -- Create sample transfers between users
    INSERT INTO public.simple_transfers (
        sender_email, recipient_email,
        sender_name, recipient_name, sender_account_number, recipient_account_number,
        amount, description, reference_number, status, created_at
    )
    SELECT 
        u1.email, u2.email,
        u1.full_name, u2.full_name, u1.account_number, u2.account_number,
        1500 + FLOOR(RANDOM() * 2000), 'تحويل تجريبي بين المستخدمين',
        'TXN' || EXTRACT(EPOCH FROM NOW())::BIGINT || FLOOR(RANDOM() * 1000)::TEXT,
        'completed', timezone('utc'::text, now() - interval '3 hours')
    FROM public.users u1
    CROSS JOIN public.users u2
    WHERE u1.id != u2.id
    AND u1.full_name LIKE 'مستخدم تجريبي%'
    AND u2.full_name LIKE 'مستخدم تجريبي%'
    AND u1.account_number IS NOT NULL
    AND u2.account_number IS NOT NULL
    LIMIT 10;
    
    GET DIAGNOSTICS transfer_counter = ROW_COUNT;
    RAISE NOTICE '✅ تم إنشاء % تحويل تجريبي بين المستخدمين', transfer_counter;
END $create_sample_transfers$;

-- =============================================================================
-- STEP 3: Create sample referrals between users
-- =============================================================================

DO $create_sample_referrals$
DECLARE
    referral_counter INTEGER := 0;
BEGIN
    RAISE NOTICE 'إنشاء إحالات تجريبية بين المستخدمين...';
    
    -- Delete existing sample referrals first
    DELETE FROM public.referrals WHERE reward_amount = 500.00 AND status = 'completed';
    
    -- Insert sample referrals between users
    INSERT INTO public.referrals (
        referrer_id,
        referred_id,
        referral_code,
        reward_amount,
        status
    )
    SELECT 
        u1.id,
        u2.id,
        u1.referral_code,
        500.00,
        'completed'
    FROM public.users u1
    CROSS JOIN public.users u2
    WHERE u1.id != u2.id
    AND u1.full_name LIKE 'مستخدم تجريبي%'
    AND u2.full_name LIKE 'مستخدم تجريبي%'
    AND u1.referral_code IS NOT NULL
    AND u2.referral_code IS NOT NULL
    LIMIT 5
    ON CONFLICT (referrer_id, referred_id) DO NOTHING;
    
    GET DIAGNOSTICS referral_counter = ROW_COUNT;
    RAISE NOTICE '✅ تم إنشاء % إحالة تجريبية بين المستخدمين', referral_counter;
END $create_sample_referrals$;

-- =============================================================================
-- STEP 4: Final comprehensive validation and statistics
-- =============================================================================

DO $final_validation_and_stats$
DECLARE
    auth_users_count INTEGER;
    public_users_count INTEGER;
    balances_count INTEGER;
    simple_balances_count INTEGER;
    transactions_count INTEGER;
    referrals_count INTEGER;
    cards_count INTEGER;
    notifications_count INTEGER;
    investments_count INTEGER;
    savings_goals_count INTEGER;
    transfers_count INTEGER;
    support_messages_count INTEGER;
    account_verifications_count INTEGER;
    linked_balances_count INTEGER;
    linked_transactions_count INTEGER;
BEGIN
    -- Count records in each table
    SELECT COUNT(*) INTO auth_users_count FROM auth.users;
    SELECT COUNT(*) INTO public_users_count FROM public.users;
    SELECT COUNT(*) INTO balances_count FROM public.balances;
    SELECT COUNT(*) INTO simple_balances_count FROM public.simple_balances;
    SELECT COUNT(*) INTO transactions_count FROM public.transactions;
    SELECT COUNT(*) INTO referrals_count FROM public.referrals;
    SELECT COUNT(*) INTO cards_count FROM public.cards;
    SELECT COUNT(*) INTO notifications_count FROM public.notifications;
    SELECT COUNT(*) INTO investments_count FROM public.investments;
    SELECT COUNT(*) INTO savings_goals_count FROM public.savings_goals;
    SELECT COUNT(*) INTO transfers_count FROM public.simple_transfers;
    SELECT COUNT(*) INTO support_messages_count FROM public.support_messages;
    SELECT COUNT(*) INTO account_verifications_count FROM public.account_verifications;
    
    -- Count properly linked records
    SELECT COUNT(*) INTO linked_balances_count 
    FROM public.balances b 
    JOIN auth.users au ON b.user_id = au.id;
    
    SELECT COUNT(*) INTO linked_transactions_count 
    FROM public.transactions t 
    JOIN auth.users au ON t.user_id = au.id;
    
    RAISE NOTICE '============================================================';
    RAISE NOTICE '=== إحصائيات شاملة بعد إدخال البيانات التجريبية ===';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 إحصائيات قاعدة البيانات:';
    RAISE NOTICE '  المستخدمون في auth.users: %', auth_users_count;
    RAISE NOTICE '  المستخدمون في public.users: %', public_users_count;
    RAISE NOTICE '  الأرصدة (balances): %', balances_count;
    RAISE NOTICE '  الأرصدة البسيطة (simple_balances): %', simple_balances_count;
    RAISE NOTICE '  المعاملات (transactions): %', transactions_count;
    RAISE NOTICE '  الإحالات (referrals): %', referrals_count;
    RAISE NOTICE '  البطاقات (cards): %', cards_count;
    RAISE NOTICE '  الإشعارات (notifications): %', notifications_count;
    RAISE NOTICE '  الاستثمارات (investments): %', investments_count;
    RAISE NOTICE '  أهداف الادخار (savings_goals): %', savings_goals_count;
    RAISE NOTICE '  التحويلات (transfers): %', transfers_count;
    RAISE NOTICE '  رسائل الدعم (support_messages): %', support_messages_count;
    RAISE NOTICE '  التحقق من الحسابات (account_verifications): %', account_verifications_count;
    RAISE NOTICE '';
    RAISE NOTICE '🔗 حالة ربط البيانات:';
    RAISE NOTICE '  الأرصدة المربوطة: % / %', linked_balances_count, balances_count;
    RAISE NOTICE '  المعاملات المربوطة: % / %', linked_transactions_count, transactions_count;
    RAISE NOTICE '';
    
    -- Validation checks
    IF public_users_count >= auth_users_count THEN
        RAISE NOTICE '✅ جميع المستخدمين من auth.users موجودون في public.users';
    ELSE
        RAISE WARNING '⚠️  بعض المستخدمين من auth.users غير موجودين في public.users! (% مفقود)', auth_users_count - public_users_count;
    END IF;
    
    IF balances_count >= public_users_count THEN
        RAISE NOTICE '✅ جميع المستخدمين لديهم سجلات أرصدة';
    ELSE
        RAISE WARNING '⚠️  بعض المستخدمين لا يملكون سجلات أرصدة! (% مفقود)', public_users_count - balances_count;
    END IF;
    
    IF linked_balances_count = balances_count THEN
        RAISE NOTICE '✅ جميع الأرصدة مربوطة بشكل صحيح مع auth.users';
    ELSE
        RAISE WARNING '⚠️  بعض الأرصدة غير مربوطة بشكل صحيح مع auth.users! (% غير مربوط)', balances_count - linked_balances_count;
    END IF;
    
    IF linked_transactions_count = transactions_count THEN
        RAISE NOTICE '✅ جميع المعاملات مربوطة بشكل صحيح مع auth.users';
    ELSE
        RAISE WARNING '⚠️  بعض المعاملات غير مربوطة بشكل صحيح مع auth.users! (% غير مربوط)', transactions_count - linked_transactions_count;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🎯 الملخص النهائي:';
    IF public_users_count >= auth_users_count 
       AND balances_count >= public_users_count 
       AND linked_balances_count = balances_count 
       AND linked_transactions_count = transactions_count 
       AND transactions_count > 0
       AND cards_count > 0
       AND notifications_count > 0 THEN
        RAISE NOTICE '✅ تم إدخال جميع البيانات التجريبية بنجاح!';
        RAISE NOTICE '✅ جميع المستخدمين من auth.users موجودون في جميع الجداول';
        RAISE NOTICE '✅ جميع البيانات مربوطة بشكل صحيح مع UIDs';
        RAISE NOTICE '✅ تم إنشاء بيانات تجريبية شاملة لجميع المستخدمين';
    ELSE
        RAISE WARNING '⚠️  تم اكتشاف بعض المشاكل - يرجى مراجعة التحذيرات أعلاه';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '=== تم إكمال إدخال البيانات التجريبية بنجاح ===';
    RAISE NOTICE '============================================================';
END $final_validation_and_stats$;

-- =============================================================================
-- END OF FORCE INSERT TEST DATA MIGRATION
-- =============================================================================