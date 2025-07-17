// أدوات التحقق من صحة البيانات
// تحتوي على دوال للتحقق من صحة البيانات المالية والمصرفية

// التحقق من صحة مبلغ مالي
export const validateAmount = (
  amount: number | string,
): { isValid: boolean; value: number; error?: string } => {
  const numAmount = typeof amount === "string" ? parseFloat(amount) : amount;

  if (isNaN(numAmount)) {
    return {
      isValid: false,
      value: 0,
      error: "المبلغ يجب أن يكون رقماً صحيحاً",
    };
  }

  if (numAmount < 0) {
    return { isValid: false, value: 0, error: "المبلغ لا يمكن أن يكون سالباً" };
  }

  if (numAmount === 0) {
    return {
      isValid: false,
      value: 0,
      error: "المبلغ يجب أن يكون أكبر من صفر",
    };
  }

  // التحقق من أن المبلغ لا يتجاوز الحد الأقصى المسموح
  const maxAmount = 1000000000; // مليار
  if (numAmount > maxAmount) {
    return {
      isValid: false,
      value: 0,
      error: "المبلغ يتجاوز الحد الأقصى المسموح",
    };
  }

  return { isValid: true, value: numAmount };
};

// التحقق من صحة رمز العملة
export const validateCurrency = (
  currency: string,
): { isValid: boolean; value: string; error?: string } => {
  const validCurrencies = ["dzd", "eur", "usd", "gbp"];
  const normalizedCurrency = currency.toLowerCase().trim();

  if (!validCurrencies.includes(normalizedCurrency)) {
    return { isValid: false, value: "", error: "رمز العملة غير صحيح" };
  }

  return { isValid: true, value: normalizedCurrency };
};

// التحقق من صحة نوع المعاملة
export const validateTransactionType = (
  type: string,
): { isValid: boolean; value: string; error?: string } => {
  const validTypes = [
    "recharge",
    "transfer",
    "bill",
    "investment",
    "conversion",
    "withdrawal",
  ];
  const normalizedType = type.toLowerCase().trim();

  if (!validTypes.includes(normalizedType)) {
    return { isValid: false, value: "", error: "نوع المعاملة غير صحيح" };
  }

  return { isValid: true, value: normalizedType };
};

// التحقق من صحة نوع الاستثمار
export const validateInvestmentType = (
  type: string,
): { isValid: boolean; value: string; error?: string } => {
  const validTypes = ["weekly", "monthly", "quarterly", "yearly"];
  const normalizedType = type.toLowerCase().trim();

  if (!validTypes.includes(normalizedType)) {
    return { isValid: false, value: "", error: "نوع الاستثمار غير صحيح" };
  }

  return { isValid: true, value: normalizedType };
};

// التحقق من صحة معدل الربح
export const validateProfitRate = (
  rate: number | string,
): { isValid: boolean; value: number; error?: string } => {
  const numRate = typeof rate === "string" ? parseFloat(rate) : rate;

  if (isNaN(numRate)) {
    return {
      isValid: false,
      value: 0,
      error: "معدل الربح يجب أن يكون رقماً صحيحاً",
    };
  }

  if (numRate < 0) {
    return {
      isValid: false,
      value: 0,
      error: "معدل الربح لا يمكن أن يكون سالباً",
    };
  }

  if (numRate > 100) {
    return {
      isValid: false,
      value: 0,
      error: "معدل الربح لا يمكن أن يتجاوز 100%",
    };
  }

  return { isValid: true, value: numRate };
};

// التحقق من صحة التواريخ
export const validateDateRange = (
  startDate: string | Date,
  endDate: string | Date,
): { isValid: boolean; error?: string } => {
  const start = new Date(startDate);
  const end = new Date(endDate);

  if (isNaN(start.getTime())) {
    return { isValid: false, error: "تاريخ البداية غير صحيح" };
  }

  if (isNaN(end.getTime())) {
    return { isValid: false, error: "تاريخ النهاية غير صحيح" };
  }

  if (end <= start) {
    return {
      isValid: false,
      error: "تاريخ النهاية يجب أن يكون بعد تاريخ البداية",
    };
  }

  return { isValid: true };
};

// التحقق من صحة رقم الحساب
export const validateAccountNumber = (
  accountNumber: string,
): { isValid: boolean; value: string; error?: string } => {
  const trimmed = accountNumber.trim();

  if (!trimmed) {
    return { isValid: false, value: "", error: "رقم الحساب مطلوب" };
  }

  // التحقق من تنسيق رقم الحساب (يبدأ بـ ACC ويتبعه 9 أرقام)
  const accountPattern = /^ACC\d{9}$/;
  if (!accountPattern.test(trimmed)) {
    return {
      isValid: false,
      value: "",
      error: "تنسيق رقم الحساب غير صحيح (يجب أن يكون ACC متبوعاً بـ 9 أرقام)",
    };
  }

  return { isValid: true, value: trimmed };
};

// التحقق من صحة رقم الهاتف مع دعم الجزائر (+213)
export const validatePhoneNumber = (
  phone: string,
  countryCode: string = "+213",
): { isValid: boolean; value: string; error?: string } => {
  const trimmed = phone.trim();

  if (!trimmed) {
    return { isValid: true, value: "" }; // رقم الهاتف اختياري
  }

  // إزالة المسافات والشرطات
  const cleanPhone = trimmed.replace(/[\s-]/g, "");

  // التحقق من رمز الدولة الجزائر (+213)
  if (countryCode === "+213") {
    // يجب أن يكون الرقم 10 أرقام بعد رمز الدولة
    const algerianPattern = /^\+213[567]\d{8}$/;
    const fullNumber = cleanPhone.startsWith("+213")
      ? cleanPhone
      : `+213${cleanPhone}`;

    if (!algerianPattern.test(fullNumber)) {
      return {
        isValid: false,
        value: "",
        error:
          "رقم الهاتف يجب أن يكون 10 أرقام ويبدأ بـ 5 أو 6 أو 7 (مثال: +213555123456)",
      };
    }

    return { isValid: true, value: fullNumber };
  }

  // التحقق العام لأرقام الهواتف الأخرى
  const generalPattern = /^\+\d{10,15}$/;
  if (!generalPattern.test(cleanPhone)) {
    return {
      isValid: false,
      value: "",
      error: "تنسيق رقم الهاتف غير صحيح (يجب أن يبدأ بـ + ويتبعه 10-15 رقماً)",
    };
  }

  return { isValid: true, value: cleanPhone };
};

// التحقق من صحة رقم الهاتف الجزائري فقط
export const validateAlgerianPhoneNumber = (
  phone: string,
): { isValid: boolean; value: string; error?: string } => {
  const trimmed = phone.trim();

  if (!trimmed) {
    return { isValid: false, value: "", error: "رقم الهاتف مطلوب" };
  }

  // إزالة جميع الرموز غير الرقمية عدا علامة +
  const cleanPhone = trimmed.replace(/[^\d+]/g, "");

  // إضافة رمز الدولة إذا لم يكن موجوداً
  let fullNumber = cleanPhone;
  if (!cleanPhone.startsWith("+213")) {
    // إزالة الصفر الأول إذا كان موجوداً
    let phoneDigits = cleanPhone.startsWith("0")
      ? cleanPhone.substring(1)
      : cleanPhone;

    // التأكد من أن الرقم يبدأ بـ 5 أو 6 أو 7
    if (phoneDigits.length === 9 && /^[567]/.test(phoneDigits)) {
      fullNumber = `+213${phoneDigits}`;
    } else if (phoneDigits.length === 8 && /^[567]/.test(phoneDigits)) {
      // في حالة كان الرقم 8 أرقام فقط
      fullNumber = `+213${phoneDigits}`;
    } else {
      // محاولة إضافة رمز الدولة للأرقام الأخرى
      fullNumber = `+213${phoneDigits}`;
    }
  }

  // التحقق من التنسيق النهائي - السماح بأرقام تبدأ بـ 5 أو 6 أو 7
  const algerianPattern = /^\+213[567]\d{8}$/;
  if (!algerianPattern.test(fullNumber)) {
    return {
      isValid: false,
      value: "",
      error:
        "رقم الهاتف يجب أن يكون 9 أرقام ويبدأ بـ 5 أو 6 أو 7 (مثال: 555123456)",
    };
  }

  return { isValid: true, value: fullNumber };
};

// دالة مساعدة للتحقق من صحة البيانات قبل الإرسال
export const validateSignupData = (data: {
  fullName: string;
  email: string;
  phone: string;
  username: string;
  password: string;
  confirmPassword: string;
  address: string;
  referralCode?: string;
}): { isValid: boolean; errors: { [key: string]: string } } => {
  const errors: { [key: string]: string } = {};

  // التحقق من الاسم الكامل
  if (!data.fullName.trim()) {
    errors.fullName = "الاسم الكامل مطلوب";
  } else if (data.fullName.trim().length < 2) {
    errors.fullName = "الاسم الكامل يجب أن يكون حرفين على الأقل";
  }

  // التحقق من البريد الإلكتروني
  const emailValidation = validateEmail(data.email);
  if (!emailValidation.isValid) {
    errors.email = emailValidation.error!;
  }

  // التحقق من رقم الهاتف
  const phoneValidation = validateAlgerianPhoneNumber(data.phone);
  if (!phoneValidation.isValid) {
    errors.phone = phoneValidation.error!;
  }

  // التحقق من اسم المستخدم
  if (!data.username.trim()) {
    errors.username = "اسم المستخدم مطلوب";
  } else if (data.username.trim().length < 3) {
    errors.username = "اسم المستخدم يجب أن يكون 3 أحرف على الأقل";
  } else if (!/^[a-zA-Z0-9_]+$/.test(data.username.trim())) {
    errors.username = "اسم المستخدم يجب أن يحتوي على أحرف وأرقام فقط";
  }

  // التحقق من كلمة المرور
  const passwordValidation = validatePassword(data.password);
  if (!passwordValidation.isValid) {
    errors.password = passwordValidation.error!;
  }

  // التحقق من تطابق كلمة المرور
  if (data.password !== data.confirmPassword) {
    errors.confirmPassword = "كلمات المرور غير متطابقة";
  }

  // التحقق من العنوان
  if (!data.address.trim()) {
    errors.address = "العنوان مطلوب";
  }

  // التحقق من كود الإحالة (اختياري)
  if (data.referralCode && data.referralCode.trim()) {
    if (data.referralCode.trim().length < 6) {
      errors.referralCode = "كود الإحالة يجب أن يكون 6 أحرف على الأقل";
    }
  }

  return { isValid: Object.keys(errors).length === 0, errors };
};

// التحقق من صحة البريد الإلكتروني
export const validateEmail = (
  email: string,
): { isValid: boolean; value: string; error?: string } => {
  const trimmed = email.trim().toLowerCase();

  if (!trimmed) {
    return { isValid: false, value: "", error: "البريد الإلكتروني مطلوب" };
  }

  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailPattern.test(trimmed)) {
    return {
      isValid: false,
      value: "",
      error: "تنسيق البريد الإلكتروني غير صحيح",
    };
  }

  return { isValid: true, value: trimmed };
};

// التحقق من صحة كلمة المرور
export const validatePassword = (
  password: string,
): { isValid: boolean; error?: string } => {
  if (!password) {
    return { isValid: false, error: "كلمة المرور مطلوبة" };
  }

  if (password.length < 6) {
    return {
      isValid: false,
      error: "كلمة المرور يجب أن تكون 6 أحرف على الأقل",
    };
  }

  if (password.length > 128) {
    return {
      isValid: false,
      error: "كلمة المرور طويلة جداً (الحد الأقصى 128 حرف)",
    };
  }

  return { isValid: true };
};

// التحقق الشامل من بيانات المعاملة
export const validateTransactionData = (
  transaction: any,
): { isValid: boolean; errors: string[] } => {
  const errors: string[] = [];

  // التحقق من المبلغ
  const amountValidation = validateAmount(transaction.amount);
  if (!amountValidation.isValid) {
    errors.push(amountValidation.error!);
  }

  // التحقق من العملة
  const currencyValidation = validateCurrency(transaction.currency || "dzd");
  if (!currencyValidation.isValid) {
    errors.push(currencyValidation.error!);
  }

  // التحقق من نوع المعاملة
  const typeValidation = validateTransactionType(transaction.type);
  if (!typeValidation.isValid) {
    errors.push(typeValidation.error!);
  }

  // التحقق من الوصف
  if (!transaction.description || transaction.description.trim().length === 0) {
    errors.push("وصف المعاملة مطلوب");
  }

  return { isValid: errors.length === 0, errors };
};

// التحقق الشامل من بيانات الاستثمار
export const validateInvestmentData = (
  investment: any,
): { isValid: boolean; errors: string[] } => {
  const errors: string[] = [];

  // التحقق من المبلغ
  const amountValidation = validateAmount(investment.amount);
  if (!amountValidation.isValid) {
    errors.push(amountValidation.error!);
  }

  // التحقق من نوع الاستثمار
  const typeValidation = validateInvestmentType(investment.type);
  if (!typeValidation.isValid) {
    errors.push(typeValidation.error!);
  }

  // التحقق من معدل الربح
  const profitRateValidation = validateProfitRate(investment.profit_rate);
  if (!profitRateValidation.isValid) {
    errors.push(profitRateValidation.error!);
  }

  // التحقق من التواريخ
  const dateValidation = validateDateRange(
    investment.start_date,
    investment.end_date,
  );
  if (!dateValidation.isValid) {
    errors.push(dateValidation.error!);
  }

  return { isValid: errors.length === 0, errors };
};
