INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    invited_at,
    confirmation_token,
    confirmation_sent_at,
    recovery_token,
    recovery_sent_at,
    email_change_token_new,
    email_change,
    email_change_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    created_at,
    updated_at,
    phone,
    phone_confirmed_at,
    phone_change,
    phone_change_token,
    phone_change_sent_at,
    email_change_token_current,
    email_change_confirm_status,
    banned_until,
    reauthentication_token,
    reauthentication_sent_at,
    is_sso_user,
    deleted_at
) VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'test@example.com',
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    NOW(),
    NULL,
    '',
    NULL,
    '',
    NULL,
    '',
    '',
    NULL,
    NULL,
    '{"provider": "email", "providers": ["email"]}',
    '{"full_name": "أحمد محمد", "phone": "+213555123456"}',
    false,
    NOW(),
    NOW(),
    NULL,
    NULL,
    '',
    '',
    NULL,
    '',
    0,
    NULL,
    '',
    NULL,
    false,
    NULL
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.users (
    id,
    email,
    full_name,
    phone,
    account_number,
    join_date,
    location,
    language,
    currency,
    profile_image,
    is_active
) VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    'test@example.com',
    'أحمد محمد',
    '+213555123456',
    'ACC123456789',
    '2024-01-01',
    'الجزائر العاصمة',
    'ar',
    'dzd',
    'https://api.dicebear.com/7.x/avataaars/svg?seed=ahmed',
    true
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.balances (
    user_id,
    dzd,
    eur,
    usd,
    gbp
) VALUES (
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    25000.00,
    120.50,
    135.75,
    95.25
) ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.transactions (
    user_id,
    type,
    amount,
    currency,
    description,
    reference,
    recipient,
    status
) VALUES 
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    'recharge',
    5000.00,
    'dzd',
    'إيداع نقدي',
    'REF001',
    NULL,
    'completed'
),
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    'transfer',
    1500.00,
    'dzd',
    'تحويل إلى صديق',
    'REF002',
    'محمد علي',
    'completed'
),
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    'bill',
    800.00,
    'dzd',
    'فاتورة الكهرباء',
    'REF003',
    'سونلغاز',
    'completed'
);

INSERT INTO public.savings_goals (
    user_id,
    name,
    target_amount,
    current_amount,
    deadline,
    category,
    icon,
    color,
    status
) VALUES 
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    'سيارة جديدة',
    500000.00,
    125000.00,
    '2024-12-31',
    'transportation',
    'car',
    '#3B82F6',
    'active'
),
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    'عطلة صيفية',
    80000.00,
    45000.00,
    '2024-06-30',
    'travel',
    'plane',
    '#10B981',
    'active'
);

INSERT INTO public.cards (
    user_id,
    card_number,
    card_type,
    is_frozen,
    spending_limit
) VALUES 
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    '4532 1234 5678 9012',
    'solid',
    false,
    50000.00
),
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    '5555 4444 3333 2222',
    'virtual',
    false,
    25000.00
);

INSERT INTO public.notifications (
    user_id,
    type,
    title,
    message,
    is_read
) VALUES 
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    'success',
    'تم الإيداع بنجاح',
    'تم إيداع 5000 دج في حسابك',
    false
),
(
    'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    'info',
    'تذكير الهدف',
    'أنت على بعد 25% من تحقيق هدف السيارة الجديدة',
    false
);