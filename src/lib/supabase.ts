import { createClient } from "@supabase/supabase-js";
import { Database } from "../types/supabase";

// Use environment variables for Supabase configuration
const supabaseUrl =
  import.meta.env.VITE_SUPABASE_URL || import.meta.env.SUPABASE_URL;
const supabaseAnonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY || import.meta.env.SUPABASE_ANON_KEY;

console.log("🔧 Supabase Configuration:", {
  url: supabaseUrl ? "✅ Set" : "❌ Missing",
  key: supabaseAnonKey ? "✅ Set" : "❌ Missing",
  urlValue: supabaseUrl,
  keyLength: supabaseAnonKey?.length || 0,
});

if (!supabaseUrl || !supabaseAnonKey) {
  console.error("❌ Missing Supabase environment variables:", {
    VITE_SUPABASE_URL: import.meta.env.VITE_SUPABASE_URL,
    SUPABASE_URL: import.meta.env.SUPABASE_URL,
    VITE_SUPABASE_ANON_KEY: import.meta.env.VITE_SUPABASE_ANON_KEY
      ? "[SET]"
      : "[MISSING]",
    SUPABASE_ANON_KEY: import.meta.env.SUPABASE_ANON_KEY
      ? "[SET]"
      : "[MISSING]",
  });
  throw new Error(
    "Missing Supabase environment variables. Please ensure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY (or SUPABASE_URL and SUPABASE_ANON_KEY) are set.",
  );
}

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
    flowType: "pkce",
  },
});

// Auth helpers
export const signUp = async (
  email: string,
  password: string,
  userData: any,
) => {
  try {
    // Validate inputs
    if (!email || !password) {
      return {
        data: null,
        error: { message: "البريد الإلكتروني وكلمة المرور مطلوبان" },
      };
    }

    if (password.length < 6) {
      return {
        data: null,
        error: { message: "كلمة المرور يجب أن تكون 6 أحرف على الأقل" },
      };
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      return {
        data: null,
        error: { message: "تنسيق البريد الإلكتروني غير صحيح" },
      };
    }

    console.log("🔐 محاولة إنشاء حساب جديد:", {
      email: email.trim(),
      hasUserData: !!userData,
      username: userData?.username,
      fullName: userData?.full_name || userData?.fullName,
      timestamp: new Date().toISOString(),
      supabaseUrl: supabaseUrl,
      hasAnonKey: !!supabaseAnonKey,
    });

    // Prepare user metadata with safe defaults and validation
    const userMetadata = {
      full_name: (userData?.full_name || userData?.fullName || "مستخدم جديد")
        .toString()
        .trim(),
      phone: (userData?.phone || "").toString().trim(),
      username: (userData?.username || "")
        .toString()
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9_]/g, ""), // Only allow alphanumeric and underscore
      address: (userData?.address || "").toString().trim(),
      referral_code: userData?.referralCode
        ? userData.referralCode.toString().trim().toUpperCase()
        : null, // Use null instead of empty string - matches database schema
    };

    // Validate required fields
    if (!userMetadata.full_name || userMetadata.full_name.length < 2) {
      return {
        data: null,
        error: { message: "الاسم الكامل يجب أن يكون حرفين على الأقل" },
      };
    }

    if (!userMetadata.username || userMetadata.username.length < 3) {
      return {
        data: null,
        error: { message: "اسم المستخدم يجب أن يكون 3 أحرف على الأقل" },
      };
    }

    // Validate phone number format if provided
    if (userMetadata.phone) {
      const phonePattern = /^\+213[567]\d{8}$/;
      if (!phonePattern.test(userMetadata.phone)) {
        return {
          data: null,
          error: {
            message: "رقم الهاتف يجب أن يكون بالتنسيق الصحيح (+213xxxxxxxxx)",
          },
        };
      }
    }

    console.log("📝 بيانات المستخدم المرسلة:", userMetadata);

    // إنشاء حساب جديد مع إرسال كود الإحالة إلى قاعدة البيانات
    const { data, error } = await supabase.auth.signUp({
      email: email.trim(),
      password,
      options: {
        data: userMetadata,
        emailRedirectTo: `${window.location.origin}/verify-email`,
      },
    });

    if (error) {
      console.error("❌ خطأ Supabase في إنشاء الحساب:", {
        message: error.message,
        status: error.status,
        statusText: error.statusText,
        name: error.name,
        details: error,
      });

      let errorMessage = "حدث خطأ في إنشاء الحساب";

      // More specific error handling
      if (
        error.message.includes("AuthSessionMissingError") ||
        error.message.includes("Auth session missing")
      ) {
        errorMessage =
          "خطأ في إعدادات المصادقة. يرجى إعادة تحميل الصفحة والمحاولة مرة أخرى";
      } else if (
        error.message.includes("User already registered") ||
        error.message.includes("already registered") ||
        error.message.includes("already exists")
      ) {
        errorMessage =
          "هذا البريد الإلكتروني مسجل بالفعل. يرجى استخدام بريد إلكتروني آخر أو تسجيل الدخول";
      } else if (
        error.message.includes("Password should be at least") ||
        error.message.includes("Password")
      ) {
        errorMessage = "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
      } else if (
        error.message.includes("Invalid email") ||
        error.message.includes("email")
      ) {
        errorMessage = "البريد الإلكتروني غير صحيح";
      } else if (
        error.message.includes("Signup is disabled") ||
        error.message.includes("signup is disabled")
      ) {
        errorMessage =
          "نظام التسجيل معطل مؤقتاً. يرجى المحاولة لاحقاً أو التواصل مع الدعم الفني";
      } else if (
        error.message.includes("Email logins are disabled") ||
        error.message.includes("logins are disabled")
      ) {
        errorMessage =
          "تسجيل الدخول بالبريد الإلكتروني معطل. يرجى التواصل مع الدعم الفني";
      } else if (error.message.includes("disabled")) {
        errorMessage = "الخدمة معطلة مؤقتاً. يرجى المحاولة لاحقاً";
      } else if (
        error.message.includes("Database error") ||
        error.message.includes("database") ||
        error.message.includes("trigger") ||
        error.message.includes("function")
      ) {
        errorMessage =
          "خطأ في قاعدة البيانات. يرجى المحاولة مرة أخرى أو التواصل مع الدعم الفني";
      } else if (
        error.message.includes("Network") ||
        error.message.includes("network") ||
        error.message.includes("fetch")
      ) {
        errorMessage =
          "مشكلة في الاتصال بالإنترنت. تأكد من اتصالك وحاول مرة أخرى";
      } else if (error.message.includes("timeout")) {
        errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
      } else if (error.status === 400) {
        errorMessage = "بيانات غير صحيحة. تأكد من جميع الحقول المطلوبة";
      } else if (error.status === 422) {
        errorMessage = "البيانات المدخلة غير صحيحة. يرجى مراجعة جميع الحقول";
      } else if (error.status === 429) {
        errorMessage =
          "محاولات كثيرة جداً. يرجى الانتظار قبل المحاولة مرة أخرى";
      } else if (error.status >= 500) {
        errorMessage = "خطأ في الخادم. يرجى المحاولة لاحقاً";
      }

      return { data: null, error: { ...error, message: errorMessage } };
    }

    if (data?.user) {
      console.log("✅ تم إنشاء الحساب بنجاح:", {
        userId: data.user.id,
        email: data.user.email,
        confirmed: data.user.email_confirmed_at ? "نعم" : "لا",
        hasSession: !!data.session,
      });
    }

    return { data, error: null };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في إنشاء الحساب:", {
      message: err.message,
      name: err.name,
      stack: err.stack,
      cause: err.cause,
    });

    let errorMessage = "حدث خطأ غير متوقع في إنشاء الحساب";

    if (
      err.message?.includes("fetch") ||
      err.message?.includes("Failed to fetch")
    ) {
      errorMessage =
        "مشكلة في الاتصال بالخادم. تأكد من اتصال الإنترنت وحاول مرة أخرى";
    } else if (err.message?.includes("timeout")) {
      errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
    } else if (err.name === "TypeError") {
      errorMessage =
        "خطأ في إعدادات الاتصال. يرجى إعادة تحميل الصفحة والمحاولة مرة أخرى";
    } else if (err.message?.includes("CORS")) {
      errorMessage = "مشكلة في إعدادات الأمان. يرجى المحاولة لاحقاً";
    }

    return {
      data: null,
      error: { message: errorMessage, originalError: err.message },
    };
  }
};

export const signIn = async (email: string, password: string) => {
  try {
    // Validate inputs
    if (!email || !password) {
      return {
        data: null,
        error: { message: "البريد الإلكتروني وكلمة المرور مطلوبان" },
      };
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      return {
        data: null,
        error: { message: "تنسيق البريد الإلكتروني غير صحيح" },
      };
    }

    // Validate password length
    if (password.length < 6) {
      return {
        data: null,
        error: { message: "كلمة المرور يجب أن تكون 6 أحرف على الأقل" },
      };
    }

    // Log connection attempt with more details
    console.log("🔐 محاولة تسجيل الدخول:", {
      url: supabaseUrl,
      email: email.trim(),
      hasKey: !!supabaseAnonKey,
      keyLength: supabaseAnonKey?.length || 0,
      timestamp: new Date().toISOString(),
    });

    const { data, error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    if (error) {
      console.error("❌ خطأ Supabase في تسجيل الدخول:", {
        message: error.message,
        status: error.status,
        statusText: error.statusText,
        name: error.name,
        details: error,
      });

      let errorMessage = "حدث خطأ غير متوقع";

      // More specific and accurate error handling
      if (
        error.message.includes("Invalid login credentials") ||
        error.message.includes("Invalid credentials") ||
        error.message.includes("invalid_credentials")
      ) {
        errorMessage = "البريد الإلكتروني أو كلمة المرور غير صحيحة";
      } else if (error.message.includes("Email not confirmed")) {
        errorMessage =
          "يرجى تأكيد البريد الإلكتروني من خلال الرسالة المرسلة إليك";
      } else if (error.message.includes("Too many requests")) {
        errorMessage =
          "محاولات كثيرة جداً. يرجى الانتظار 5 دقائق قبل المحاولة مرة أخرى";
      } else if (error.message.includes("User not found")) {
        errorMessage =
          "لا يوجد حساب مسجل بهذا البريد الإلكتروني. يرجى التسجيل أولاً";
      } else if (
        error.message.includes("Email logins are disabled") ||
        error.message.includes("logins are disabled")
      ) {
        errorMessage =
          "تسجيل الدخول بالبريد الإلكتروني معطل. يرجى التواصل مع الدعم الفني لتفعيل الحساب";
      } else if (
        error.message.includes("Signup is disabled") ||
        error.message.includes("disabled")
      ) {
        errorMessage =
          "الخدمة معطلة مؤقتاً. يرجى المحاولة لاحقاً أو التواصل مع الدعم الفني";
      } else if (
        error.message.includes("fetch") ||
        error.message.includes("network") ||
        error.message.includes("Failed to fetch")
      ) {
        errorMessage =
          "مشكلة في الاتصال بالخادم. تأكد من اتصال الإنترنت وحاول مرة أخرى";
      } else if (error.message.includes("timeout")) {
        errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
      } else if (error.status === 400) {
        errorMessage =
          "بيانات غير صحيحة. تأكد من البريد الإلكتروني وكلمة المرور";
      } else if (error.status === 401) {
        errorMessage = "بيانات الدخول غير صحيحة";
      } else if (error.status === 422) {
        errorMessage = "البريد الإلكتروني غير صحيح أو كلمة المرور ضعيفة";
      } else if (error.status === 429) {
        errorMessage =
          "محاولات كثيرة جداً. يرجى الانتظار قبل المحاولة مرة أخرى";
      } else if (error.status >= 500) {
        errorMessage = "خطأ في الخادم. يرجى المحاولة لاحقاً";
      }

      return { data: null, error: { ...error, message: errorMessage } };
    }

    if (data?.user) {
      console.log("✅ نجح تسجيل الدخول في Supabase:", {
        userId: data.user.id,
        email: data.user.email,
        confirmed: data.user.email_confirmed_at ? "نعم" : "لا",
        hasSession: !!data.session,
        sessionExpiry: data.session?.expires_at,
      });
    }

    return { data, error: null };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في Supabase signin:", {
      message: err.message,
      name: err.name,
      stack: err.stack,
      cause: err.cause,
    });

    let errorMessage = "حدث خطأ غير متوقع في الاتصال";

    if (
      err.message?.includes("fetch") ||
      err.message?.includes("Failed to fetch")
    ) {
      errorMessage =
        "مشكلة في الاتصال بالخادم. تأكد من اتصال الإنترنت وحاول مرة أخرى";
    } else if (err.message?.includes("timeout")) {
      errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
    } else if (err.name === "TypeError") {
      errorMessage = "خطأ في إعدادات الاتصال. يرجى إعادة تحميل الصفحة";
    } else if (err.message?.includes("CORS")) {
      errorMessage = "مشكلة في إعدادات الأمان. يرجى المحاولة لاحقاً";
    }

    return {
      data: null,
      error: { message: errorMessage, originalError: err.message },
    };
  }
};

export const signOut = async () => {
  try {
    const { error } = await supabase.auth.signOut();

    if (error) {
      console.error("Supabase signout error:", error);
      return { error };
    }

    return { error: null };
  } catch (err: any) {
    console.error("Signout catch error:", err);
    return {
      error: { message: err.message || "حدث خطأ في تسجيل الخروج" },
    };
  }
};

export const getCurrentUser = async () => {
  try {
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser();

    if (error) {
      console.error("Get user error:", error);
      return { user: null, error };
    }

    return { user, error: null };
  } catch (err: any) {
    console.error("Get user catch error:", err);
    return {
      user: null,
      error: { message: err.message || "حدث خطأ في جلب بيانات المستخدم" },
    };
  }
};

// Database helpers
export const getUserProfile = async (userId: string) => {
  try {
    console.log("🔍 Fetching user profile for:", userId);

    const { data, error } = await supabase
      .from("users")
      .select("*")
      .eq("id", userId)
      .single();

    if (error) {
      console.error("❌ getUserProfile error:", {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code,
        status: error.status || "unknown",
      });

      // Handle specific error codes
      if (error.code === "PGRST116") {
        // No rows returned - user doesn't exist in users table
        console.log(
          "ℹ️ User not found in users table, this might be normal for new users",
        );
        return {
          data: null,
          error: { ...error, message: "User profile not found" },
        };
      }

      if (
        error.message?.includes("permission denied") ||
        error.code === "42501"
      ) {
        console.error("🔒 Permission denied - RLS policy issue");
        return {
          data: null,
          error: { ...error, message: "Access denied to user profile" },
        };
      }

      return { data: null, error };
    }

    console.log("✅ getUserProfile success:", data?.id);
    return { data, error: null };
  } catch (err: any) {
    console.error("💥 getUserProfile catch error:", err);
    return {
      data: null,
      error: { message: err.message || "Failed to fetch user profile" },
    };
  }
};

export const updateUserProfile = async (userId: string, updates: any) => {
  const { data, error } = await supabase
    .from("users")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", userId)
    .select()
    .single();
  return { data, error };
};

export const getUserBalance = async (userId: string) => {
  try {
    console.log("💰 Fetching user balance for:", userId);

    const { data, error } = await supabase
      .from("balances")
      .select("*")
      .eq("user_id", userId)
      .single();

    if (error) {
      console.error("❌ getUserBalance error:", {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code,
        status: error.status || "unknown",
      });

      // Handle specific error codes
      if (error.code === "PGRST116") {
        // No rows returned - balance doesn't exist
        console.log("ℹ️ Balance not found, this might be normal for new users");
        return {
          data: null,
          error: { ...error, message: "User balance not found" },
        };
      }

      if (
        error.message?.includes("permission denied") ||
        error.code === "42501"
      ) {
        console.error(
          "🔒 Permission denied - RLS policy issue on balances table",
        );
        return {
          data: null,
          error: { ...error, message: "Access denied to user balance" },
        };
      }

      return { data: null, error };
    }

    console.log("✅ getUserBalance success:", {
      userId: data?.user_id,
      dzd: data?.dzd,
      hasBalance: !!data,
    });
    return { data, error: null };
  } catch (err: any) {
    console.error("💥 getUserBalance catch error:", err);
    return {
      data: null,
      error: { message: err.message || "Failed to fetch user balance" },
    };
  }
};

export const updateUserBalance = async (userId: string, balances: any) => {
  try {
    // التحقق من صحة مبالغ الأرصدة
    const validatedBalances = {
      dzd:
        balances.dzd !== undefined
          ? Math.max(0, parseFloat(balances.dzd) || 0)
          : undefined,
      eur:
        balances.eur !== undefined
          ? Math.max(0, parseFloat(balances.eur) || 0)
          : undefined,
      usd:
        balances.usd !== undefined
          ? Math.max(0, parseFloat(balances.usd) || 0)
          : undefined,
      gbp:
        balances.gbp !== undefined
          ? Math.max(0, parseFloat(balances.gbp) || 0)
          : undefined,
      investment_balance:
        balances.investment_balance !== undefined
          ? Math.max(0, parseFloat(balances.investment_balance) || 0)
          : undefined,
    };

    // استخدام الدالة المخصصة لتحديث الأرصدة
    const { data, error } = await supabase.rpc("update_user_balance", {
      p_user_id: userId,
      p_dzd: validatedBalances.dzd,
      p_eur: validatedBalances.eur,
      p_usd: validatedBalances.usd,
      p_gbp: validatedBalances.gbp,
      p_investment_balance: validatedBalances.investment_balance,
    });

    if (error) {
      console.error("Error calling update_user_balance function:", error);
      return { data: null, error };
    }

    // إرجاع أول سجل من النتائج
    return { data: data?.[0] || null, error: null };
  } catch (err: any) {
    console.error("Error in updateUserBalance:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في تحديث الرصيد" },
    };
  }
};

// Get investment balance for a user
export const getInvestmentBalance = async (userId: string) => {
  const { data, error } = await supabase
    .from("balances")
    .select("investment_balance")
    .eq("user_id", userId)
    .single();
  return { data, error };
};

// Update investment balance using database function
export const updateInvestmentBalance = async (
  userId: string,
  amount: number,
  operation: "add" | "subtract",
) => {
  try {
    // استخدام دالة قاعدة البيانات لمعالجة الاستثمار
    const dbOperation = operation === "add" ? "invest" : "return";

    const { data, error } = await supabase.rpc("process_investment", {
      p_user_id: userId,
      p_amount: amount,
      p_operation: dbOperation,
    });

    if (error) {
      console.error("Error calling process_investment function:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    if (!result?.success) {
      return {
        data: null,
        error: { message: result?.message || "فشل في معالجة الاستثمار" },
      };
    }

    // إرجاع البيانات المحدثة بتنسيق متوافق
    const updatedBalance = {
      user_id: userId,
      dzd: result.new_dzd_balance,
      investment_balance: result.new_investment_balance,
      updated_at: new Date().toISOString(),
    };

    return { data: updatedBalance, error: null };
  } catch (error: any) {
    console.error("Error in updateInvestmentBalance:", error);
    return {
      data: null,
      error: { message: error.message || "خطأ في تحديث رصيد الاستثمار" },
    };
  }
};

export const createTransaction = async (transaction: any) => {
  // التحقق من صحة بيانات المعاملة
  const validatedTransaction = {
    ...transaction,
    amount: Math.abs(parseFloat(transaction.amount) || 0),
    currency: (transaction.currency || "dzd").toLowerCase(),
    type: transaction.type || "transfer",
    status: transaction.status || "completed",
    description: transaction.description || "معاملة",
  };

  // التحقق من أن المبلغ أكبر من صفر
  if (validatedTransaction.amount <= 0) {
    return {
      data: null,
      error: { message: "مبلغ المعاملة يجب أن يكون أكبر من صفر" },
    };
  }

  // التحقق من صحة نوع العملة
  const validCurrencies = ["dzd", "eur", "usd", "gbp"];
  if (!validCurrencies.includes(validatedTransaction.currency)) {
    return { data: null, error: { message: "نوع العملة غير صحيح" } };
  }

  // التحقق من صحة نوع المعاملة
  const validTypes = [
    "recharge",
    "transfer",
    "bill",
    "investment",
    "conversion",
    "withdrawal",
  ];
  if (!validTypes.includes(validatedTransaction.type)) {
    return { data: null, error: { message: "نوع المعاملة غير صحيح" } };
  }

  const { data, error } = await supabase
    .from("transactions")
    .insert(validatedTransaction)
    .select()
    .single();
  return { data, error };
};

export const getUserTransactions = async (userId: string, limit = 50) => {
  const { data, error } = await supabase
    .from("transactions")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(limit);
  return { data, error };
};

export const createInvestment = async (investment: any) => {
  // التحقق من صحة بيانات الاستثمار
  const validatedInvestment = {
    ...investment,
    amount: Math.abs(parseFloat(investment.amount) || 0),
    profit_rate: Math.max(
      0,
      Math.min(100, parseFloat(investment.profit_rate) || 0),
    ),
    profit: 0, // يبدأ الربح من صفر
    status: investment.status || "active",
    type: investment.type || "monthly",
  };

  // التحقق من أن المبلغ أكبر من صفر
  if (validatedInvestment.amount <= 0) {
    return {
      data: null,
      error: { message: "مبلغ الاستثمار يجب أن يكون أكبر من صفر" },
    };
  }

  // التحقق من صحة نوع الاستثمار
  const validTypes = ["weekly", "monthly", "quarterly", "yearly"];
  if (!validTypes.includes(validatedInvestment.type)) {
    return { data: null, error: { message: "نوع الاستثمار غير صحيح" } };
  }

  // التحقق من صحة التواريخ
  const startDate = new Date(validatedInvestment.start_date);
  const endDate = new Date(validatedInvestment.end_date);
  if (endDate <= startDate) {
    return {
      data: null,
      error: {
        message: "تاريخ انتهاء الاستثمار يجب أن يكون بعد تاريخ البداية",
      },
    };
  }

  const { data, error } = await supabase
    .from("investments")
    .insert(validatedInvestment)
    .select()
    .single();
  return { data, error };
};

export const getUserInvestments = async (userId: string) => {
  const { data, error } = await supabase
    .from("investments")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  return { data, error };
};

export const updateInvestment = async (investmentId: string, updates: any) => {
  const { data, error } = await supabase
    .from("investments")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", investmentId)
    .select()
    .single();
  return { data, error };
};

export const createSavingsGoal = async (goal: any) => {
  // التحقق من صحة بيانات هدف الادخار
  const validatedGoal = {
    ...goal,
    target_amount: Math.abs(parseFloat(goal.target_amount) || 0),
    current_amount: Math.max(0, parseFloat(goal.current_amount) || 0),
    status: goal.status || "active",
    name: goal.name || "هدف ادخار",
    category: goal.category || "عام",
    icon: goal.icon || "target",
    color: goal.color || "#3B82F6",
  };

  // التحقق من أن المبلغ المستهدف أكبر من صفر
  if (validatedGoal.target_amount <= 0) {
    return {
      data: null,
      error: { message: "المبلغ المستهدف يجب أن يكون أكبر من صفر" },
    };
  }

  // التحقق من أن المبلغ الحالي لا يتجاوز المستهدف
  if (validatedGoal.current_amount > validatedGoal.target_amount) {
    return {
      data: null,
      error: { message: "المبلغ الحالي لا يمكن أن يتجاوز المبلغ المستهدف" },
    };
  }

  // التحقق من صحة تاريخ الموعد النهائي
  const deadline = new Date(validatedGoal.deadline);
  if (deadline <= new Date()) {
    return {
      data: null,
      error: { message: "الموعد النهائي يجب أن يكون في المستقبل" },
    };
  }

  const { data, error } = await supabase
    .from("savings_goals")
    .insert(validatedGoal)
    .select()
    .single();
  return { data, error };
};

export const getUserSavingsGoals = async (userId: string) => {
  const { data, error } = await supabase
    .from("savings_goals")
    .select("*")
    .eq("user_id", userId)
    .eq("status", "active")
    .order("created_at", { ascending: false });
  return { data, error };
};

export const updateSavingsGoal = async (goalId: string, updates: any) => {
  const { data, error } = await supabase
    .from("savings_goals")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", goalId)
    .select()
    .single();
  return { data, error };
};

export const getUserCards = async (userId: string) => {
  const { data, error } = await supabase
    .from("cards")
    .select("*")
    .eq("user_id", userId);
  return { data, error };
};

export const updateCard = async (cardId: string, updates: any) => {
  const { data, error } = await supabase
    .from("cards")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", cardId)
    .select()
    .single();
  return { data, error };
};

export const createNotification = async (notification: any) => {
  const { data, error } = await supabase
    .from("notifications")
    .insert(notification)
    .select()
    .single();
  return { data, error };
};

export const getUserNotifications = async (userId: string) => {
  const { data, error } = await supabase
    .from("notifications")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  return { data, error };
};

export const markNotificationAsRead = async (notificationId: string) => {
  const { data, error } = await supabase
    .from("notifications")
    .update({ is_read: true })
    .eq("id", notificationId)
    .select()
    .single();
  return { data, error };
};

export const createReferral = async (referral: any) => {
  const { data, error } = await supabase
    .from("referrals")
    .insert(referral)
    .select()
    .single();
  return { data, error };
};

export const getUserReferrals = async (userId: string) => {
  const { data, error } = await supabase
    .from("referrals")
    .select(
      `
      *,
      referred_user:users!referrals_referred_id_fkey(full_name, email)
    `,
    )
    .eq("referrer_id", userId)
    .order("created_at", { ascending: false });
  return { data, error };
};

// Get referral statistics for a user
export const getReferralStats = async (userId: string) => {
  try {
    // Get total referrals count
    const { count: totalReferrals } = await supabase
      .from("referrals")
      .select("*", { count: "exact", head: true })
      .eq("referrer_id", userId);

    // Get completed referrals count
    const { count: completedReferrals } = await supabase
      .from("referrals")
      .select("*", { count: "exact", head: true })
      .eq("referrer_id", userId)
      .eq("status", "completed");

    // Get total earnings from referrals
    const { data: userEarnings } = await supabase
      .from("users")
      .select("referral_earnings")
      .eq("id", userId)
      .single();

    // Get this month's referrals
    const startOfMonth = new Date();
    startOfMonth.setDate(1);
    startOfMonth.setHours(0, 0, 0, 0);

    const { count: thisMonthReferrals } = await supabase
      .from("referrals")
      .select("*", { count: "exact", head: true })
      .eq("referrer_id", userId)
      .gte("created_at", startOfMonth.toISOString());

    return {
      data: {
        totalReferrals: totalReferrals || 0,
        completedReferrals: completedReferrals || 0,
        totalEarnings: userEarnings?.referral_earnings || 0,
        thisMonthReferrals: thisMonthReferrals || 0,
        pendingRewards: (totalReferrals || 0) - (completedReferrals || 0),
      },
      error: null,
    };
  } catch (error: any) {
    return {
      data: null,
      error: { message: error.message || "خطأ في جلب إحصائيات الإحالة" },
    };
  }
};

// Validate referral code with enhanced checking
export const validateReferralCode = async (code: string) => {
  if (!code || code.trim().length === 0) {
    return { isValid: false, error: "كود الإحالة مطلوب" };
  }

  if (code.trim().length < 6) {
    return {
      isValid: false,
      error: "كود الإحالة يجب أن يكون 6 أحرف على الأقل",
    };
  }

  try {
    const { data, error } = await supabase
      .from("users")
      .select("id, full_name, email, is_active")
      .eq("referral_code", code.trim().toUpperCase())
      .eq("is_active", true)
      .single();

    if (error || !data) {
      console.log("Referral code validation error:", error);
      return { isValid: false, error: "كود الإحالة غير صحيح أو غير موجود" };
    }

    return {
      isValid: true,
      referrer: data,
      message: `كود صحيح - ستحصل على مكافأة 500 دج من ${data.full_name}`,
    };
  } catch (err: any) {
    console.error("Error validating referral code:", err);
    return { isValid: false, error: "خطأ في التحقق من كود الإحالة" };
  }
};

// Send phone verification SMS
export const sendPhoneVerification = async (phoneNumber: string) => {
  try {
    // This would integrate with an SMS service like Twilio
    // For now, we'll simulate the process
    console.log("Sending SMS verification to:", phoneNumber);

    // Generate a 6-digit verification code
    const verificationCode = Math.floor(
      100000 + Math.random() * 900000,
    ).toString();

    // In a real implementation, you would:
    // 1. Send SMS via Twilio/other SMS service
    // 2. Store the code in database with expiration
    // 3. Return success/failure status

    // For demo purposes, we'll store in localStorage
    localStorage.setItem(
      `phone_verification_${phoneNumber}`,
      JSON.stringify({
        code: verificationCode,
        expires: Date.now() + 5 * 60 * 1000, // 5 minutes
        attempts: 0,
      }),
    );

    console.log(`Verification code for ${phoneNumber}: ${verificationCode}`);

    return {
      success: true,
      message: "تم إرسال رمز التحقق إلى هاتفك",
      // In production, don't return the code!
      code: verificationCode, // Only for demo
    };
  } catch (error: any) {
    console.error("Error sending phone verification:", error);
    return {
      success: false,
      message: "فشل في إرسال رمز التحقق",
    };
  }
};

// Verify phone number with code
export const verifyPhoneNumber = async (phoneNumber: string, code: string) => {
  try {
    const storedData = localStorage.getItem(
      `phone_verification_${phoneNumber}`,
    );

    if (!storedData) {
      return {
        success: false,
        message: "لم يتم العثور على رمز التحقق. يرجى طلب رمز جديد",
      };
    }

    const verification = JSON.parse(storedData);

    // Check if code expired
    if (Date.now() > verification.expires) {
      localStorage.removeItem(`phone_verification_${phoneNumber}`);
      return {
        success: false,
        message: "انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد",
      };
    }

    // Check attempts
    if (verification.attempts >= 3) {
      localStorage.removeItem(`phone_verification_${phoneNumber}`);
      return {
        success: false,
        message: "تم تجاوز عدد المحاولات المسموح. يرجى طلب رمز جديد",
      };
    }

    // Verify code
    if (code.trim() === verification.code) {
      localStorage.removeItem(`phone_verification_${phoneNumber}`);
      return {
        success: true,
        message: "تم تأكيد رقم الهاتف بنجاح",
      };
    } else {
      // Increment attempts
      verification.attempts += 1;
      localStorage.setItem(
        `phone_verification_${phoneNumber}`,
        JSON.stringify(verification),
      );

      return {
        success: false,
        message: `رمز التحقق غير صحيح. المحاولات المتبقية: ${3 - verification.attempts}`,
      };
    }
  } catch (error: any) {
    console.error("Error verifying phone number:", error);
    return {
      success: false,
      message: "خطأ في التحقق من رقم الهاتف",
    };
  }
};

// Get user credentials (username and password)
export const getUserCredentials = async (userId: string) => {
  try {
    console.log("🔑 Fetching user credentials for:", userId);

    const { data, error } = await supabase
      .from("user_credentials")
      .select("username, password_hash")
      .eq("user_id", userId)
      .single();

    if (error) {
      console.error("❌ getUserCredentials error:", {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code,
        status: error.status || "unknown",
      });

      // Handle specific error codes
      if (error.code === "PGRST116") {
        // No rows returned - credentials don't exist
        console.log(
          "ℹ️ Credentials not found, this might be normal for new users",
        );
        return {
          data: null,
          error: { ...error, message: "User credentials not found" },
        };
      }

      if (
        error.message?.includes("permission denied") ||
        error.code === "42501"
      ) {
        console.error(
          "🔒 Permission denied - RLS policy issue on user_credentials table",
        );
        return {
          data: null,
          error: { ...error, message: "Access denied to user credentials" },
        };
      }

      return { data: null, error };
    }

    console.log("✅ getUserCredentials success:", {
      userId,
      username: data?.username,
      hasCredentials: !!data,
    });
    return { data, error: null };
  } catch (err: any) {
    console.error("💥 getUserCredentials catch error:", err);
    return {
      data: null,
      error: { message: err.message || "Failed to fetch user credentials" },
    };
  }
};

// Get all user credentials (for admin viewing)
export const getAllUserCredentials = async () => {
  const { data, error } = await supabase.from("user_credentials").select(`
      username,
      password_hash,
      user_id,
      users!inner(email, full_name)
    `);
  return { data, error };
};

// =============================================================================
// OTP SYSTEM FUNCTIONS
// =============================================================================

// Create and send OTP (supports both phone and email)
export const createOTP = async (
  userId?: string | null,
  phoneNumber?: string | null,
  email?: string | null,
  otpType: string = "phone_verification",
  expiresInMinutes: number = 5,
) => {
  try {
    console.log("🔐 إنشاء OTP جديد:", {
      phoneNumber: phoneNumber
        ? phoneNumber.substring(0, 6) + "***"
        : "غير محدد",
      email: email ? email.substring(0, 3) + "***" : "غير محدد",
      userId,
      otpType,
      expiresInMinutes,
    });

    const { data, error } = await supabase.rpc("create_otp", {
      p_user_id: userId || null,
      p_phone_number: phoneNumber || null,
      p_email: email || null,
      p_otp_type: otpType,
      p_expires_in_minutes: expiresInMinutes,
      p_ip_address: null,
      p_user_agent: navigator?.userAgent || null,
    });

    if (error) {
      console.error("❌ خطأ في إنشاء OTP:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    if (!result?.success) {
      return {
        data: null,
        error: { message: result?.message || "فشل في إنشاء OTP" },
      };
    }

    console.log("✅ تم إنشاء OTP بنجاح:", {
      otpId: result.otp_id,
      expiresAt: result.expires_at,
    });

    return {
      data: {
        otpId: result.otp_id,
        otpCode: result.otp_code, // Only for demo - remove in production
        expiresAt: result.expires_at,
        message: result.message,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في إنشاء OTP:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في إنشاء OTP" },
    };
  }
};

// Verify OTP (supports both phone and email)
export const verifyOTP = async (
  phoneNumber?: string | null,
  email?: string | null,
  otpCode: string,
  otpType: string = "phone_verification",
) => {
  try {
    console.log("🔐 التحقق من OTP:", {
      phoneNumber: phoneNumber
        ? phoneNumber.substring(0, 6) + "***"
        : "غير محدد",
      email: email ? email.substring(0, 3) + "***" : "غير محدد",
      otpCode: otpCode.substring(0, 2) + "****",
      otpType,
    });

    const { data, error } = await supabase.rpc("verify_otp", {
      p_phone_number: phoneNumber || null,
      p_email: email || null,
      p_otp_code: otpCode,
      p_otp_type: otpType,
      p_ip_address: null,
      p_user_agent: navigator?.userAgent || null,
    });

    if (error) {
      console.error("❌ خطأ في التحقق من OTP:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    if (!result?.success) {
      return {
        data: null,
        error: { message: result?.message || "فشل في التحقق من OTP" },
      };
    }

    console.log("✅ تم التحقق من OTP بنجاح:", {
      userId: result.user_id,
      phoneNumber: result.phone_number,
      otpType: result.otp_type,
    });

    return {
      data: {
        userId: result.user_id,
        phoneNumber: result.phone_number,
        email: result.email,
        otpType: result.otp_type,
        message: result.message,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في التحقق من OTP:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في التحقق من OTP" },
    };
  }
};

// Increment OTP attempts
export const incrementOTPAttempts = async (
  phoneNumber: string,
  otpCode: string,
  otpType: string = "phone_verification",
) => {
  try {
    const { data, error } = await supabase.rpc("increment_otp_attempts", {
      p_phone_number: phoneNumber,
      p_otp_code: otpCode,
      p_otp_type: otpType,
      p_ip_address: null,
      p_user_agent: navigator?.userAgent || null,
    });

    if (error) {
      console.error("❌ خطأ في تسجيل محاولة OTP:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    return {
      data: {
        success: result?.success || false,
        message: result?.message || "",
        attemptsRemaining: result?.attempts_remaining || 0,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في تسجيل محاولة OTP:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في تسجيل المحاولة" },
    };
  }
};

// Get OTP status (supports both phone and email)
export const getOTPStatus = async (
  phoneNumber?: string | null,
  email?: string | null,
  otpType: string = "phone_verification",
) => {
  try {
    const { data, error } = await supabase.rpc("get_otp_status", {
      p_phone_number: phoneNumber || null,
      p_email: email || null,
      p_otp_type: otpType,
    });

    if (error) {
      console.error("❌ خطأ في جلب حالة OTP:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    return {
      data: {
        hasActiveOTP: result?.has_active_otp || false,
        expiresAt: result?.expires_at,
        attemptsUsed: result?.attempts_used || 0,
        canResend: result?.can_resend || false,
        nextResendAt: result?.next_resend_at,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في جلب حالة OTP:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في جلب حالة OTP" },
    };
  }
};

// Clean up expired OTPs
export const cleanupExpiredOTPs = async () => {
  try {
    const { data, error } = await supabase.rpc("cleanup_expired_otps");

    if (error) {
      console.error("❌ خطأ في تنظيف OTPs المنتهية الصلاحية:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    return {
      data: {
        cleanedOTPs: result?.cleaned_otps || 0,
        cleanedLogs: result?.cleaned_logs || 0,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في تنظيف OTPs:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في تنظيف OTPs" },
    };
  }
};

// Send OTP via SMS (mock implementation for demo)
export const sendOTPSMS = async (
  phoneNumber: string,
  otpCode: string,
  otpType: string = "phone_verification",
) => {
  try {
    // This would integrate with an SMS service like Twilio
    // For now, we'll simulate the process
    console.log("📱 إرسال OTP عبر SMS:", {
      phoneNumber: phoneNumber.substring(0, 6) + "***",
      otpCode: otpCode.substring(0, 2) + "****",
      otpType,
    });

    // Simulate SMS sending delay
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // In a real implementation, you would:
    // 1. Send SMS via Twilio/other SMS service
    // 2. Handle delivery status
    // 3. Return success/failure status

    console.log(`📱 تم إرسال OTP إلى ${phoneNumber}: ${otpCode}`);

    return {
      success: true,
      message: "تم إرسال رمز التحقق إلى هاتفك",
      deliveryId: `sms_${Date.now()}`, // Mock delivery ID
    };
  } catch (error: any) {
    console.error("❌ خطأ في إرسال OTP عبر SMS:", error);
    return {
      success: false,
      message: "فشل في إرسال رمز التحقق",
      error: error.message,
    };
  }
};

// Complete phone verification process
export const completePhoneVerification = async (
  phoneNumber: string,
  otpCode: string,
  userId?: string,
) => {
  try {
    console.log("🔐 إكمال عملية تأكيد الهاتف:", {
      phoneNumber: phoneNumber.substring(0, 6) + "***",
      otpCode: otpCode.substring(0, 2) + "****",
      userId,
    });

    // First verify the OTP
    const verificationResult = await verifyOTP(
      phoneNumber,
      otpCode,
      "phone_verification",
    );

    if (!verificationResult.data) {
      return verificationResult;
    }

    // If verification successful and user ID provided, update user profile
    if (userId && verificationResult.data.userId) {
      try {
        await updateUserProfile(userId, {
          phone: phoneNumber,
          is_verified: true,
          verification_status: "verified",
        });

        console.log("✅ تم تحديث ملف المستخدم بعد تأكيد الهاتف");
      } catch (profileError) {
        console.warn("⚠️ فشل في تحديث ملف المستخدم:", profileError);
        // Don't fail the entire process if profile update fails
      }
    }

    return {
      data: {
        ...verificationResult.data,
        phoneVerified: true,
        profileUpdated: true,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في إكمال تأكيد الهاتف:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في إكمال تأكيد الهاتف" },
    };
  }
};

// Get user OTP logs
export const getUserOTPLogs = async (userId: string, limit: number = 10) => {
  try {
    const { data, error } = await supabase
      .from("otp_logs")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(limit);

    if (error) {
      console.error("❌ خطأ في جلب سجلات OTP:", error);
      return { data: null, error };
    }

    return { data: data || [], error: null };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في جلب سجلات OTP:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في جلب سجلات OTP" },
    };
  }
};

// Password reset functions
export const resetPassword = async (email: string) => {
  try {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });

    if (error) {
      console.error("Password reset error:", error);
      return {
        error: { message: "فشل في إرسال رابط إعادة تعيين كلمة المرور" },
      };
    }

    return { error: null };
  } catch (err: any) {
    console.error("Password reset catch error:", err);
    return {
      error: { message: "حدث خطأ في إرسال رابط إعادة تعيين كلمة المرور" },
    };
  }
};

// Enhanced email verification with database integration
export const confirmEmailVerification = async (
  token: string,
  verificationCode?: string,
  type: string = "signup",
) => {
  try {
    console.log("🔐 محاولة تأكيد البريد الإلكتروني:", {
      token: token.substring(0, 10) + "...",
      hasCode: !!verificationCode,
      type,
    });

    // First try to verify using our database function
    const { data: dbResult, error: dbError } = await supabase.rpc(
      "verify_email_token",
      {
        p_token: token,
        p_verification_code: verificationCode || null,
        p_ip_address: null, // Could be passed from client if needed
        p_user_agent: navigator?.userAgent || null,
      },
    );

    if (dbError) {
      console.error("❌ خطأ في قاعدة البيانات:", dbError);
      // Fallback to Supabase auth verification
      return await fallbackAuthVerification(token, type);
    }

    const result = dbResult?.[0];
    if (!result?.success) {
      console.error("❌ فشل التأكيد:", result?.message);
      return {
        data: null,
        error: { message: result?.message || "فشل في تأكيد البريد الإلكتروني" },
      };
    }

    console.log("✅ تم تأكيد البريد الإلكتروني بنجاح:", {
      userId: result.user_id,
      email: result.email,
      tokenType: result.token_type,
    });

    // Get updated user data
    const { data: userData } = await supabase.auth.getUser();

    return {
      data: {
        user: userData?.user || null,
        session: null,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في تأكيد البريد الإلكتروني:", err);
    // Fallback to Supabase auth verification
    return await fallbackAuthVerification(token, type);
  }
};

// Fallback function for Supabase auth verification
const fallbackAuthVerification = async (token: string, type: string) => {
  try {
    const { data, error } = await supabase.auth.verifyOtp({
      token_hash: token,
      type: type as any,
    });

    if (error) {
      console.error("❌ خطأ في تأكيد البريد الإلكتروني (fallback):", error);

      let errorMessage = "فشل في تأكيد البريد الإلكتروني";

      if (
        error.message.includes("Token has expired") ||
        error.message.includes("expired")
      ) {
        errorMessage = "انتهت صلاحية رابط التأكيد. يرجى طلب رابط جديد";
      } else if (
        error.message.includes("Invalid token") ||
        error.message.includes("invalid")
      ) {
        errorMessage = "رابط التأكيد غير صحيح أو تم استخدامه من قبل";
      } else if (error.message.includes("Email already confirmed")) {
        errorMessage = "تم تأكيد البريد الإلكتروني مسبقاً";
      }

      return { data: null, error: { message: errorMessage } };
    }

    if (data?.user) {
      console.log("✅ تم تأكيد البريد الإلكتروني بنجاح (fallback):", {
        userId: data.user.id,
        email: data.user.email,
        confirmed: data.user.email_confirmed_at ? "نعم" : "لا",
      });
    }

    return { data, error: null };
  } catch (err: any) {
    console.error(
      "💥 خطأ غير متوقع في تأكيد البريد الإلكتروني (fallback):",
      err,
    );
    return {
      error: { message: "حدث خطأ غير متوقع في تأكيد البريد الإلكتروني" },
    };
  }
};

export const updatePassword = async (newPassword: string) => {
  try {
    const { error } = await supabase.auth.updateUser({
      password: newPassword,
    });

    if (error) {
      console.error("Password update error:", error);
      return { error: { message: "فشل في تحديث كلمة المرور" } };
    }

    return { error: null };
  } catch (err: any) {
    console.error("Password update catch error:", err);
    return { error: { message: "حدث خطأ في تحديث كلمة المرور" } };
  }
};

// Email verification functions
export const verifyOtp = async (token: string, type: string = "signup") => {
  return confirmEmailVerification(token, undefined, type);
};

// Verify with 6-digit code
export const verifyEmailCode = async (code: string, email?: string) => {
  try {
    console.log("🔐 محاولة تأكيد البريد الإلكتروني بالكود:", {
      code: code.substring(0, 2) + "****",
      email: email ? email.substring(0, 3) + "***" : "unknown",
    });

    // First try using our enhanced database function if available
    try {
      const { data: dbResult, error: dbError } = await supabase.rpc(
        "verify_email_token",
        {
          p_token: "", // Empty token when using code
          p_verification_code: code,
          p_ip_address: null,
          p_user_agent: navigator?.userAgent || null,
        },
      );

      if (!dbError && dbResult?.[0]?.success) {
        const result = dbResult[0];
        console.log("✅ تم تأكيد البريد الإلكتروني بالكود بنجاح:", {
          userId: result.user_id,
          email: result.email,
        });

        return {
          data: {
            user_id: result.user_id,
            email: result.email,
            verified: true,
          },
          error: null,
        };
      }
    } catch (dbErr) {
      console.warn("⚠️ Database function not available, using fallback");
    }

    // Fallback: Try Supabase OTP verification
    const { data, error } = await supabase.auth.verifyOtp({
      token: code,
      type: "email",
    });

    if (error) {
      console.error("❌ خطأ في تأكيد الكود:", error);
      let errorMessage = "الكود غير صحيح أو منتهي الصلاحية";

      if (error.message?.includes("expired")) {
        errorMessage = "انتهت صلاحية الكود. يرجى طلب كود جديد";
      } else if (error.message?.includes("invalid")) {
        errorMessage = "الكود غير صحيح. تأكد من إدخال الكود بشكل صحيح";
      }

      return {
        data: null,
        error: { message: errorMessage },
      };
    }

    console.log("✅ تم تأكيد البريد الإلكتروني بالكود بنجاح (fallback):", {
      userId: data?.user?.id,
      email: data?.user?.email,
    });

    return {
      data: {
        user_id: data?.user?.id,
        email: data?.user?.email,
        verified: true,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في تأكيد الكود:", err);
    return {
      data: null,
      error: { message: "حدث خطأ في التحقق من الكود" },
    };
  }
};

export const resendVerification = async (email?: string) => {
  // Use the new link-based system
  return await resendEmailVerificationLink(email);
};

// Check user verification status using database function
export const checkAccountVerification = async (userId: string) => {
  try {
    const { data, error } = await supabase.rpc("get_user_verification_status", {
      p_user_id: userId,
    });

    if (error) {
      console.error("❌ خطأ في فحص حالة التوثيق:", error);
      // Fallback to simple check
      const { data: userData, error: userError } = await supabase
        .from("users")
        .select("is_verified, verification_status")
        .eq("id", userId)
        .single();

      if (userError) {
        return {
          data: {
            is_verified: false,
            verification_status: "unknown",
          },
          error: userError,
        };
      }

      return {
        data: {
          is_verified: userData?.is_verified || false,
          verification_status: userData?.verification_status || "pending",
        },
        error: null,
      };
    }

    const result = data?.[0];
    return {
      data: {
        is_verified: result?.is_verified || false,
        verification_status: result?.verification_status || "pending",
        email_verified: result?.email_verified || false,
        pending_verifications: result?.pending_verifications || 0,
        last_verification_attempt: result?.last_verification_attempt,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في فحص حالة التوثيق:", err);
    return {
      data: {
        is_verified: false,
        verification_status: "error",
      },
      error: { message: err.message || "خطأ في فحص حالة التوثيق" },
    };
  }
};

// Update card balance
export const updateCardBalance = async (cardId: string, amount: number) => {
  const { data, error } = await supabase
    .from("cards")
    .update({
      balance: amount,
      updated_at: new Date().toISOString(),
    })
    .eq("id", cardId)
    .select()
    .single();
  return { data, error };
};

// Support Messages Functions
export const createSupportMessage = async (
  userId: string,
  subject: string,
  message: string,
  category: string = "general",
  priority: string = "normal",
) => {
  try {
    const { data, error } = await supabase.rpc("create_support_message", {
      p_user_id: userId,
      p_subject: subject,
      p_message: message,
      p_category: category,
      p_priority: priority,
    });

    if (error) {
      console.error("Error creating support message:", error);
      return { data: null, error };
    }

    return { data: data?.[0] || null, error: null };
  } catch (err: any) {
    console.error("Error in createSupportMessage:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في إرسال رسالة الدعم" },
    };
  }
};

export const getUserSupportMessages = async (
  userId: string,
  limit: number = 50,
) => {
  try {
    const { data, error } = await supabase.rpc("get_user_support_messages", {
      p_user_id: userId,
      p_limit: limit,
    });

    if (error) {
      console.error("Error getting support messages:", error);
      return { data: null, error };
    }

    return { data: data || [], error: null };
  } catch (err: any) {
    console.error("Error in getUserSupportMessages:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في جلب رسائل الدعم" },
    };
  }
};

export const updateSupportMessageStatus = async (
  messageId: string,
  status: string,
  adminResponse?: string,
  adminId?: string,
) => {
  try {
    const { data, error } = await supabase.rpc(
      "update_support_message_status",
      {
        p_message_id: messageId,
        p_status: status,
        p_admin_response: adminResponse,
        p_admin_id: adminId,
      },
    );

    if (error) {
      console.error("Error updating support message status:", error);
      return { data: null, error };
    }

    return { data: data?.[0] || null, error: null };
  } catch (err: any) {
    console.error("Error in updateSupportMessageStatus:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في تحديث حالة الرسالة" },
    };
  }
};

// Email verification token management functions
export const createEmailVerificationToken = async (
  userId: string,
  email: string,
  tokenType: string = "signup",
  expiresInHours: number = 24,
) => {
  try {
    const { data, error } = await supabase.rpc(
      "create_email_verification_token",
      {
        p_user_id: userId,
        p_email: email,
        p_token_type: tokenType,
        p_expires_in_hours: expiresInHours,
      },
    );

    if (error) {
      console.error("❌ خطأ في إنشاء رمز التأكيد:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    if (!result?.success) {
      return {
        data: null,
        error: { message: result?.message || "فشل في إنشاء رمز التأكيد" },
      };
    }

    return {
      data: {
        token: result.token,
        expires_at: result.expires_at,
        message: result.message,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في إنشاء رمز التأكيد:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في إنشاء رمز التأكيد" },
    };
  }
};

// Send email verification link (replaces code-based system)
export const resendEmailVerificationLink = async (email?: string) => {
  try {
    let userEmail = email;
    let userId: string | null = null;

    if (!userEmail) {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      userEmail = user?.email;
      userId = user?.id || null;
    }

    if (!userEmail) {
      return { error: { message: "لم يتم العثور على البريد الإلكتروني" } };
    }

    console.log("📧 إرسال رابط التأكيد إلى:", userEmail);

    // Use Supabase auth resend with improved email template
    const { error } = await supabase.auth.resend({
      type: "signup",
      email: userEmail,
      options: {
        emailRedirectTo: `${window.location.origin}/verify-email`,
        data: {
          app_name: "منصة الدفع الرقمية",
          verification_message:
            "يرجى النقر على الرابط أدناه لتأكيد بريدك الإلكتروني",
          support_email: "support@yourapp.com",
        },
      },
    });

    if (error) {
      console.error("❌ خطأ في إرسال رابط التأكيد:", error);

      let errorMessage = "فشل في إرسال رابط التأكيد";

      if (error.message.includes("Email rate limit exceeded")) {
        errorMessage =
          "تم تجاوز الحد المسموح لإرسال الرسائل. يرجى الانتظار قبل المحاولة مرة أخرى";
      } else if (error.message.includes("Email already confirmed")) {
        errorMessage = "تم تأكيد البريد الإلكتروني مسبقاً";
      }

      return { error: { message: errorMessage } };
    }

    console.log("✅ تم إرسال رابط التأكيد بنجاح");
    return { error: null };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في إرسال رابط التأكيد:", err);
    return { error: { message: "حدث خطأ في إرسال رابط التأكيد" } };
  }
};

export const verifyEmailToken = async (
  token: string,
  ipAddress?: string,
  userAgent?: string,
) => {
  try {
    // Use Supabase auth verification for token-based verification
    const { data, error } = await supabase.auth.verifyOtp({
      token_hash: token,
      type: "signup",
    });

    if (error) {
      console.error("❌ خطأ في تأكيد الرابط:", error);

      let errorMessage = "فشل في تأكيد البريد الإلكتروني";

      if (
        error.message.includes("Token has expired") ||
        error.message.includes("expired")
      ) {
        errorMessage = "انتهت صلاحية رابط التأكيد. يرجى طلب رابط جديد";
      } else if (
        error.message.includes("Invalid token") ||
        error.message.includes("invalid")
      ) {
        errorMessage = "رابط التأكيد غير صحيح أو تم استخدامه من قبل";
      } else if (error.message.includes("Email already confirmed")) {
        errorMessage = "تم تأكيد البريد الإلكتروني مسبقاً";
      }

      return { data: null, error: { message: errorMessage } };
    }

    if (data?.user) {
      console.log("✅ تم تأكيد البريد الإلكتروني بنجاح:", {
        userId: data.user.id,
        email: data.user.email,
        confirmed: data.user.email_confirmed_at ? "نعم" : "لا",
      });
    }

    return {
      data: {
        user_id: data?.user?.id,
        email: data?.user?.email,
        token_type: "signup",
        message: "تم تأكيد البريد الإلكتروني بنجاح",
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في تأكيد الرابط:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في تأكيد الرابط" },
    };
  }
};

export const incrementTokenAttempts = async (
  token: string,
  ipAddress?: string,
  userAgent?: string,
) => {
  try {
    const { data, error } = await supabase.rpc("increment_token_attempts", {
      p_token: token,
      p_ip_address: ipAddress || null,
      p_user_agent: userAgent || navigator?.userAgent || null,
    });

    if (error) {
      console.error("❌ خطأ في تسجيل المحاولة:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    return {
      data: {
        success: result?.success || false,
        message: result?.message || "",
        attempts_remaining: result?.attempts_remaining || 0,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في تسجيل المحاولة:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في تسجيل المحاولة" },
    };
  }
};

export const cleanupExpiredTokens = async () => {
  try {
    const { data, error } = await supabase.rpc(
      "cleanup_expired_verification_tokens",
    );

    if (error) {
      console.error("❌ خطأ في تنظيف الرموز المنتهية الصلاحية:", error);
      return { data: null, error };
    }

    const result = data?.[0];
    return {
      data: {
        cleaned_tokens: result?.cleaned_tokens || 0,
        cleaned_logs: result?.cleaned_logs || 0,
      },
      error: null,
    };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في تنظيف الرموز:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في تنظيف الرموز" },
    };
  }
};

// Enhanced user registration function for Google OAuth users
export const handleNewGoogleUser = async (user: any) => {
  try {
    console.log("🔄 Processing new Google user:", {
      userId: user.id,
      email: user.email,
      fullName: user.user_metadata?.full_name,
      provider: user.app_metadata?.provider,
      emailVerified: user.email_confirmed_at,
    });

    // Use the enhanced database function for user setup
    const { data, error } = await supabase.rpc("setup_google_user", {
      p_user_id: user.id,
      p_email: user.email,
      p_full_name:
        user.user_metadata?.full_name ||
        user.user_metadata?.fullName ||
        "مستخدم جديد",
      p_referral_code:
        user.user_metadata?.referralCode ||
        user.user_metadata?.used_referral_code ||
        null,
    });

    if (error) {
      console.error("❌ خطأ في استدعاء دالة إعداد المستخدم:", error);
      throw error;
    }

    const setupResult = data;
    console.log("📊 نتيجة إعداد المستخدم:", setupResult);

    if (!setupResult?.success) {
      throw new Error(setupResult?.message || "فشل في إعداد المستخدم");
    }

    // Wait a moment for all database operations to complete
    await new Promise((resolve) => setTimeout(resolve, 1000));

    // Get complete user data
    const { data: completeData, error: dataError } = await supabase.rpc(
      "get_complete_user_data",
      {
        p_user_id: user.id,
      },
    );

    if (dataError) {
      console.warn("⚠️ خطأ في جلب البيانات الكاملة:", dataError);
    }

    // Fallback to individual queries if RPC fails
    let profile = null;
    let balance = null;

    if (completeData) {
      profile = completeData.user;
      balance = completeData.balance;
    } else {
      const { data: profileData } = await getUserProfile(user.id);
      const { data: balanceData } = await getUserBalance(user.id);
      profile = profileData;
      balance = balanceData;
    }

    console.log("✅ إعداد المستخدم الجديد من Google مكتمل:", {
      hasProfile: !!profile,
      hasBalance: !!balance,
      accountNumber: profile?.account_number,
      initialBalance: balance?.dzd,
      setupResult,
    });

    return {
      success: true,
      profile,
      balance,
      setupResult,
      completeData: completeData || null,
    };
  } catch (error) {
    console.error("❌ خطأ في إعداد المستخدم الجديد من Google:", error);
    return { success: false, error };
  }
};

// Get complete user data using the database function
export const getCompleteUserData = async (userId: string) => {
  try {
    const { data, error } = await supabase.rpc("get_complete_user_data", {
      p_user_id: userId,
    });

    if (error) {
      console.error("❌ خطأ في جلب البيانات الكاملة للمستخدم:", error);
      return { data: null, error };
    }

    return { data, error: null };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في جلب البيانات الكاملة:", err);
    return { data: null, error: { message: err.message } };
  }
};

export const getUserVerificationLogs = async (
  userId: string,
  limit: number = 10,
) => {
  try {
    const { data, error } = await supabase
      .from("email_verification_logs")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(limit);

    if (error) {
      console.error("❌ خطأ في جلب سجلات التأكيد:", error);
      return { data: null, error };
    }

    return { data: data || [], error: null };
  } catch (err: any) {
    console.error("💥 خطأ غير متوقع في جلب سجلات التأكيد:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في جلب سجلات التأكيد" },
    };
  }
};

// Account Verification Functions
export const submitAccountVerification = async (
  userId: string,
  verificationData: any,
) => {
  try {
    const { data, error } = await supabase
      .from("account_verifications")
      .insert({
        user_id: userId,
        country: verificationData.country,
        date_of_birth: verificationData.date_of_birth,
        full_address: verificationData.full_address,
        postal_code: verificationData.postal_code,
        document_type: verificationData.document_type,
        document_number: verificationData.document_number,
        documents: verificationData.documents,
        additional_notes: verificationData.additional_notes,
        status: "pending",
        submitted_at: verificationData.submitted_at,
      })
      .select()
      .single();

    if (error) {
      console.error("Error submitting account verification:", error);
      return { data: null, error };
    }

    // Update user verification status
    await supabase
      .from("users")
      .update({
        verification_status: "pending",
        updated_at: new Date().toISOString(),
      })
      .eq("id", userId);

    return { data, error: null };
  } catch (err: any) {
    console.error("Error in submitAccountVerification:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في إرسال طلب التوثيق" },
    };
  }
};

export const getUserVerificationStatus = async (userId: string) => {
  try {
    const { data, error } = await supabase
      .from("account_verifications")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    if (error && error.code !== "PGRST116") {
      // PGRST116 is "not found"
      console.error("Error getting verification status:", error);
      return { data: null, error };
    }

    return { data, error: null };
  } catch (err: any) {
    console.error("Error in getUserVerificationStatus:", err);
    return { data: null, error: { message: err.message } };
  }
};

export const updateVerificationStatus = async (
  verificationId: string,
  status: string,
  adminNotes?: string,
  adminId?: string,
) => {
  try {
    const { data, error } = await supabase
      .from("account_verifications")
      .update({
        status,
        admin_notes: adminNotes,
        reviewed_by: adminId,
        reviewed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", verificationId)
      .select()
      .single();

    if (error) {
      console.error("Error updating verification status:", error);
      return { data: null, error };
    }

    // Update user verification status
    if (data) {
      await supabase
        .from("users")
        .update({
          verification_status: status,
          is_verified: status === "approved",
          updated_at: new Date().toISOString(),
        })
        .eq("id", data.user_id);
    }

    return { data, error: null };
  } catch (err: any) {
    console.error("Error in updateVerificationStatus:", err);
    return {
      data: null,
      error: { message: err.message || "خطأ في تحديث حالة التوثيق" },
    };
  }
};

// Get all verification requests (for admin)
export const getAllVerificationRequests = async (
  limit: number = 100,
  offset: number = 0,
  status?: string,
) => {
  try {
    const { data, error } = await supabase.rpc("get_all_verifications", {
      p_limit: limit,
      p_offset: offset,
      p_status: status || null,
    });

    if (error) {
      console.error("Error getting all verification requests:", error);
      return { data: [], error };
    }

    return { data: data || [], error: null };
  } catch (err: any) {
    console.error("Error in getAllVerificationRequests:", err);
    return { data: [], error: { message: err.message } };
  }
};
