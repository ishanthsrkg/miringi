// Security utilities for the e-wallet application

// Generate a secure random card number (for demo purposes)
export const generateSecureCardNumber = (): string => {
  const prefix = "4532"; // Visa prefix
  let number = prefix;

  // Generate 12 random digits
  for (let i = 0; i < 12; i++) {
    number += Math.floor(Math.random() * 10).toString();
  }

  return number;
};

// Generate a secure RIB number
export const generateSecureRIB = (): string => {
  let rib = "";
  for (let i = 0; i < 20; i++) {
    rib += Math.floor(Math.random() * 10).toString();
  }
  return rib;
};

// Mask sensitive data for display
export const maskCardNumber = (cardNumber: string): string => {
  if (cardNumber.length < 4) return "";
  const lastFour = cardNumber.slice(-4);
  const masked = "**** **** **** " + lastFour;
  return masked;
};

// Mask numerical values for display before data is loaded
export const maskNumber = (
  value: number | string,
  showLast: number = 2,
): string => {
  const str = value.toString();
  if (str.length <= showLast) return "*".repeat(str.length);
  const lastDigits = str.slice(-showLast);
  const maskedPart = "*".repeat(str.length - showLast);
  return maskedPart + lastDigits;
};

// Mask balance amounts
export const maskBalance = (amount: number): string => {
  return "";
};

// Check if data is considered "loaded" and ready to display
export const isDataLoaded = (data: any, loading: boolean): boolean => {
  return !loading && data !== null && data !== undefined;
};

export const maskRIB = (rib: string): string => {
  if (rib.length < 4) return rib;
  const lastFour = rib.slice(-4);
  const masked = "*".repeat(rib.length - 4) + lastFour;
  return masked;
};

// Validate input data
export const validateAmount = (
  value: string,
  minAmount = 1000,
  maxAmount = 100000,
): string => {
  if (!value || parseFloat(value) <= 0) {
    return "يرجى إدخال مبلغ صحيح";
  }
  const amount = parseFloat(value);
  if (amount < minAmount) {
    return `الحد الأدنى هو ${minAmount.toLocaleString()} دج`;
  }
  if (amount > maxAmount) {
    return `الحد الأقصى هو ${maxAmount.toLocaleString()} دج`;
  }
  return "";
};

// Validate bill reference based on type
export const validateBillReference = (
  value: string,
  pattern: RegExp,
  hint: string,
): string => {
  if (!value.trim()) {
    return "يرجى إدخال رقم المرجع";
  }
  if (!pattern.test(value.trim())) {
    return `تنسيق رقم المرجع غير صحيح (${hint})`;
  }
  return "";
};

// Rate limiting for transactions
export const checkTransactionRateLimit = (
  lastTransactionTime: Date | null,
  maxAttempts: number,
  currentAttempts: number,
): string | null => {
  const now = new Date();
  if (
    lastTransactionTime &&
    now.getTime() - lastTransactionTime.getTime() < 30000
  ) {
    return "يرجى الانتظار 30 ثانية بين كل معاملة";
  }
  if (currentAttempts >= maxAttempts) {
    return `تم تجاوز الحد الأقصى للمحاولات (${maxAttempts} محاولات)`;
  }
  return null;
};

// Generate secure transaction ID
export const generateTransactionId = (prefix = "TXN"): string => {
  const timestamp = Date.now().toString();
  const random = Math.random().toString(36).substr(2, 9);
  return `${prefix}-${timestamp}-${random}`.toUpperCase();
};

export const validateRib = (value: string): string => {
  if (!value) {
    return "يرجى إدخال رقم RIB";
  }
  if (value.length < 10) {
    return "رقم RIB يجب أن يكون 10 أرقام على الأقل";
  }
  if (!/^[0-9]+$/.test(value)) {
    return "رقم RIB يجب أن يحتوي على أرقام فقط";
  }
  return "";
};

// Simple encryption for demo (in production, use proper encryption)
export const encryptData = (data: string): string => {
  return btoa(data); // Base64 encoding for demo
};

export const decryptData = (encryptedData: string): string => {
  try {
    return atob(encryptedData); // Base64 decoding for demo
  } catch {
    return "";
  }
};
