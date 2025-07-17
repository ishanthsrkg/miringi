-- إضافة مستخدمين تجريبيين مع كلمات مرور صحيحة
-- كلمة المرور لجميع الحسابات: 123456

INSERT INTO auth.users (
  instance_id,
  id,
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
) VALUES 
(
  '00000000-0000-0000-0000-000000000000',
  '11223344-5566-7788-99aa-bbccddeeff00',
  'authenticated',
  'authenticated',
  'user1@example.com',
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
  '{"full_name": "مستخدم تجريبي 1", "phone": "+966501234567", "username": "user1"}',
  FALSE,
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
  FALSE,
  NULL
),
(
  '00000000-0000-0000-0000-000000000000',
  '22334455-6677-8899-aabb-ccddeeff0011',
  'authenticated',
  'authenticated',
  'user2@example.com',
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
  '{"full_name": "مستخدم تجريبي 2", "phone": "+966501234568", "username": "user2"}',
  FALSE,
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
  FALSE,
  NULL
),
(
  '00000000-0000-0000-0000-000000000000',
  '33445566-7788-99aa-bbcc-ddeeff001122',
  'authenticated',
  'authenticated',
  'admin@example.com',
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
  '{"full_name": "المدير", "phone": "+966501234569", "username": "admin"}',
  FALSE,
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
  FALSE,
  NULL
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  provider_id,
  id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES 
(
  '11223344-5566-7788-99aa-bbccddeeff00',
  '11223344-5566-7788-99aa-bbccddeeff00',
  '11223344-5566-7788-99aa-bbccddeeff00',
  '{"sub": "11223344-5566-7788-99aa-bbccddeeff00", "email": "user1@example.com"}',
  'email',
  NOW(),
  NOW(),
  NOW()
),
(
  '22334455-6677-8899-aabb-ccddeeff0011',
  '22334455-6677-8899-aabb-ccddeeff0011',
  '22334455-6677-8899-aabb-ccddeeff0011',
  '{"sub": "22334455-6677-8899-aabb-ccddeeff0011", "email": "user2@example.com"}',
  'email',
  NOW(),
  NOW(),
  NOW()
),
(
  '33445566-7788-99aa-bbcc-ddeeff001122',
  '33445566-7788-99aa-bbcc-ddeeff001122',
  '33445566-7788-99aa-bbcc-ddeeff001122',
  '{"sub": "33445566-7788-99aa-bbcc-ddeeff001122", "email": "admin@example.com"}',
  'email',
  NOW(),
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.users (
  id,
  email,
  full_name,
  phone,
  account_number,
  join_date,
  created_at,
  updated_at
) VALUES 
(
  '11223344-5566-7788-99aa-bbccddeeff00',
  'user1@example.com',
  'مستخدم تجريبي 1',
  '+966501234567',
  'ACC123456',
  NOW(),
  NOW(),
  NOW()
),
(
  '22334455-6677-8899-aabb-ccddeeff0011',
  'user2@example.com',
  'مستخدم تجريبي 2',
  '+966501234568',
  'ACC123457',
  NOW(),
  NOW(),
  NOW()
),
(
  '33445566-7788-99aa-bbcc-ddeeff001122',
  'admin@example.com',
  'المدير',
  '+966501234569',
  'ACC123458',
  NOW(),
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_credentials (
  user_id,
  username,
  password_hash,
  created_at,
  updated_at
) VALUES 
(
  '11223344-5566-7788-99aa-bbccddeeff00',
  'user1',
  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  NOW(),
  NOW()
),
(
  '22334455-6677-8899-aabb-ccddeeff0011',
  'user2',
  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  NOW(),
  NOW()
),
(
  '33445566-7788-99aa-bbcc-ddeeff001122',
  'admin',
  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
  NOW(),
  NOW()
)
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.balances (
  user_id,
  dzd,
  eur,
  usd,
  gbp,
  created_at,
  updated_at
) VALUES 
(
  '11223344-5566-7788-99aa-bbccddeeff00',
  5625.00,
  1350.00,
  1500.00,
  1200.00,
  NOW(),
  NOW()
),
(
  '22334455-6677-8899-aabb-ccddeeff0011',
  7500.00,
  1800.00,
  2000.00,
  1600.00,
  NOW(),
  NOW()
),
(
  '33445566-7788-99aa-bbcc-ddeeff001122',
  37500.00,
  9000.00,
  10000.00,
  8000.00,
  NOW(),
  NOW()
)
ON CONFLICT (user_id) DO NOTHING;
