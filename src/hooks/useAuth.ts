import { useState, useEffect } from "react";
import { User } from "@supabase/supabase-js";
import {
  supabase,
  signIn,
  signUp,
  signOut,
  getCurrentUser,
  getUserCredentials,
  getUserProfile,
  getUserBalance,
  resetPassword,
  updatePassword,
  verifyOtp,
  resendVerification,
  createOTP,
  verifyOTP,
  completePhoneVerification,
  getOTPStatus,
} from "../lib/supabase";

interface ExtendedUser extends User {
  credentials?: {
    username: string;
    password_hash: string;
  };
  profile?: any;
  balance?: any;
}

export const useAuth = () => {
  const [user, setUser] = useState<ExtendedUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Get initial session with better error handling and timeout
    const getInitialSession = async () => {
      try {
        console.log("🔄 جاري تحميل الجلسة الأولية...");

        // Add timeout to prevent infinite loading
        const timeoutPromise = new Promise((_, reject) =>
          setTimeout(() => reject(new Error("Session check timeout")), 8000),
        );

        const sessionPromise = getCurrentUser();

        const { user, error } = (await Promise.race([
          sessionPromise,
          timeoutPromise,
        ])) as any;

        if (error) {
          // Don't set error for initial session check - this is normal when not logged in
          console.log("ℹ️ لا توجد جلسة نشطة - هذا طبيعي عند عدم تسجيل الدخول");
        } else if (user) {
          console.log("✅ تم العثور على جلسة نشطة:", user.id);
          setUser(user);
        } else {
          console.log("ℹ️ لا توجد جلسة نشطة");
        }
      } catch (err: any) {
        console.error("💥 خطأ غير متوقع في تحميل الجلسة:", err);
        if (err.message === "Session check timeout") {
          console.log("⏰ انتهت مهلة فحص الجلسة - سيتم المتابعة بدون مستخدم");
        }
        // Don't set error for initial session check
        console.log("ℹ️ خطأ في تحميل الجلسة الأولية - سيتم المحاولة مرة أخرى");
      } finally {
        setLoading(false);
      }
    };

    getInitialSession();

    // Listen for auth changes with improved logging and timeout
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log("🔄 تغيير في حالة المصادقة:", {
        event,
        hasSession: !!session,
        hasUser: !!session?.user,
        userId: session?.user?.id,
        userEmail: session?.user?.email,
        isNewUser: event === "SIGNED_IN" && session?.user?.created_at,
      });

      // Always ensure loading is set to false after auth state change
      const finishLoading = () => {
        setLoading(false);
      };

      // Set a timeout to ensure loading never gets stuck
      const loadingTimeout = setTimeout(() => {
        console.log("⏰ انتهت مهلة تحميل بيانات المستخدم - سيتم إنهاء التحميل");
        finishLoading();
      }, 15000); // Increased timeout for new user setup

      try {
        if (session?.user) {
          // Check if this is a new user (Google OAuth)
          const isNewUser =
            event === "SIGNED_IN" &&
            session.user.app_metadata?.provider === "google";

          if (isNewUser) {
            console.log(
              "🆕 مستخدم جديد من Google - انتظار إعداد قاعدة البيانات...",
            );
            // Wait a bit longer for database triggers to complete for new users
            await new Promise((resolve) => setTimeout(resolve, 3000));
          }

          // Fetch additional user data when session changes
          try {
            console.log("📊 جاري تحميل بيانات المستخدم الإضافية...");

            // Add timeout for database operations
            const dbTimeout = new Promise(
              (_, reject) =>
                setTimeout(() => reject(new Error("Database timeout")), 12000), // Increased timeout
            );

            const dbPromise = Promise.allSettled([
              getUserCredentials(session.user.id),
              getUserProfile(session.user.id),
              getUserBalance(session.user.id),
            ]);

            const results = (await Promise.race([dbPromise, dbTimeout])) as any;

            // Handle results from Promise.allSettled
            const [credentialsResult, profileResult, balanceResult] = results;

            const extendedUser: ExtendedUser = {
              ...session.user,
              credentials:
                credentialsResult.status === "fulfilled"
                  ? credentialsResult.value.data
                  : undefined,
              profile:
                profileResult.status === "fulfilled"
                  ? profileResult.value.data
                  : undefined,
              balance:
                balanceResult.status === "fulfilled"
                  ? balanceResult.value.data
                  : undefined,
            };

            // Log any failed requests
            if (credentialsResult.status === "rejected") {
              console.warn(
                "⚠️ Failed to load credentials:",
                credentialsResult.reason,
              );
            }
            if (profileResult.status === "rejected") {
              console.warn("⚠️ Failed to load profile:", profileResult.reason);
            }
            if (balanceResult.status === "rejected") {
              console.warn("⚠️ Failed to load balance:", balanceResult.reason);
            }

            setUser(extendedUser);
            setError(null); // Clear any previous errors on successful login

            // Log successful authentication with user data status
            console.log("✅ تم تحميل بيانات المستخدم بنجاح:", {
              userId: session.user.id,
              email: session.user.email,
              hasProfile: !!extendedUser.profile,
              hasBalance: !!extendedUser.balance,
              hasCredentials: !!extendedUser.credentials,
              isNewUser,
              provider: session.user.app_metadata?.provider,
            });

            // If this is a Google login, ensure user is redirected to home
            if (
              event === "SIGNED_IN" &&
              session.user.app_metadata?.provider === "google"
            ) {
              console.log(
                "🏠 تسجيل دخول بجوجل مكتمل - المستخدم جاهز للتوجيه إلى الصفحة الرئيسية",
              );
            }
          } catch (dbError: any) {
            console.error(
              "❌ خطأ في جلب بيانات المستخدم عند تغيير الجلسة:",
              dbError,
            );
            // Still set the user even if database fetch fails
            setUser(session.user);
            setError(null);

            if (dbError.message === "Database timeout") {
              console.log("⏰ انتهت مهلة تحميل البيانات من قاعدة البيانات");
            } else {
              console.log(
                "⚠️ تم تسجيل الدخول ولكن فشل في تحميل بعض البيانات الإضافية",
              );
            }
          }
        } else {
          console.log("🚪 تم تسجيل الخروج أو انتهت الجلسة");
          setUser(null);
          setError(null); // Clear errors when logging out
        }
      } finally {
        clearTimeout(loadingTimeout);
        finishLoading();
      }
    });

    return () => {
      console.log("🔌 إلغاء الاشتراك في تغييرات المصادقة");
      subscription.unsubscribe();
    };
  }, []);

  const loginWithGoogle = async () => {
    setLoading(true);
    setError(null);

    // Set a timeout to prevent infinite loading
    const loginTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة تسجيل الدخول بجوجل");
      setLoading(false);
      setError("انتهت مهلة تسجيل الدخول. يرجى المحاولة مرة أخرى");
    }, 30000); // 30 seconds timeout

    try {
      console.log("🔐 محاولة تسجيل الدخول بجوجل:", {
        timestamp: new Date().toISOString(),
        redirectUrl: `${window.location.origin}/home`,
      });

      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo: `${window.location.origin}/home`,
          queryParams: {
            access_type: "offline",
            prompt: "consent",
          },
        },
      });

      if (error) {
        console.error("❌ خطأ في تسجيل الدخول بجوجل:", error);
        clearTimeout(loginTimeout);

        let errorMessage = "حدث خطأ في تسجيل الدخول بجوجل";

        if (error.message.includes("popup")) {
          errorMessage =
            "تم حظر النافذة المنبثقة. يرجى السماح بالنوافذ المنبثقة والمحاولة مرة أخرى";
        } else if (error.message.includes("network")) {
          errorMessage =
            "مشكلة في الاتصال بالإنترنت. تأكد من اتصالك وحاول مرة أخرى";
        } else if (error.message.includes("timeout")) {
          errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
        }

        setError(errorMessage);
        setLoading(false);
        return { data: null, error: { message: errorMessage } };
      }

      console.log("✅ تم بدء عملية تسجيل الدخول بجوجل بنجاح");
      console.log("🔄 سيتم إعادة التوجيه إلى الصفحة الرئيسية بعد المصادقة");
      clearTimeout(loginTimeout);

      // Don't set loading to false here as the redirect will handle it
      return { data, error: null };
    } catch (err: any) {
      clearTimeout(loginTimeout);
      console.error("💥 خطأ غير متوقع في تسجيل الدخول بجوجل:", err);

      let errorMessage = "حدث خطأ غير متوقع في تسجيل الدخول";

      if (err.message?.includes("fetch")) {
        errorMessage = "مشكلة في الاتصال بالخادم. تأكد من اتصال الإنترنت";
      } else if (err.message?.includes("timeout")) {
        errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
      }

      setError(errorMessage);
      setLoading(false);
      return { data: null, error: { message: errorMessage } };
    }
  };

  const login = async (email: string, password: string) => {
    setLoading(true);
    setError(null);

    // Set a timeout to prevent infinite loading
    const loginTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة تسجيل الدخول");
      setLoading(false);
      setError("انتهت مهلة تسجيل الدخول. يرجى المحاولة مرة أخرى");
    }, 20000); // 20 seconds timeout

    try {
      // Validate inputs before making request
      if (!email?.trim() || !password) {
        const errorMessage = "يرجى إدخال البريد الإلكتروني وكلمة المرور";
        setError(errorMessage);
        setLoading(false);
        return { data: null, error: { message: errorMessage } };
      }

      // Validate email format
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(email.trim())) {
        const errorMessage = "تنسيق البريد الإلكتروني غير صحيح";
        setError(errorMessage);
        setLoading(false);
        return { data: null, error: { message: errorMessage } };
      }

      // Validate password length
      if (password.length < 6) {
        const errorMessage = "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
        setError(errorMessage);
        setLoading(false);
        return { data: null, error: { message: errorMessage } };
      }

      // Enhanced logging for debugging
      console.log("🔐 محاولة تسجيل الدخول:", {
        email: email.trim(),
        timestamp: new Date().toISOString(),
      });
      console.log("🔧 إعدادات Supabase:", {
        url: import.meta.env.VITE_SUPABASE_URL,
        hasAnonKey: !!import.meta.env.VITE_SUPABASE_ANON_KEY,
        keyLength: import.meta.env.VITE_SUPABASE_ANON_KEY?.length || 0,
        environment: import.meta.env.MODE,
      });

      const { data, error } = await signIn(email.trim(), password);

      if (error) {
        console.error("تفاصيل خطأ تسجيل الدخول:", {
          message: error.message,
          status: error.status,
          statusText: error.statusText,
          details: error,
        });

        let errorMessage = "حدث خطأ في تسجيل الدخول";

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
          errorMessage = "لا يوجد حساب مسجل بهذا البريد الإلكتروني";
        } else if (error.message.includes("Email logins are disabled")) {
          errorMessage =
            "تسجيل الدخول بالبريد الإلكتروني معطل. يرجى التواصل مع الدعم الفني لتفعيل الحساب";
        } else if (error.message.includes("Signup is disabled")) {
          errorMessage =
            "نظام تسجيل الدخول معطل مؤقتاً. يرجى المحاولة لاحقاً أو التواصل مع الدعم الفني";
        } else if (error.message.includes("disabled")) {
          errorMessage = "الخدمة معطلة مؤقتاً. يرجى المحاولة لاحقاً";
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

        setError(errorMessage);
        setLoading(false);
        return { data: null, error: { message: errorMessage } };
      }

      if (data?.user) {
        console.log("تم تسجيل الدخول بنجاح، معرف المستخدم:", data.user.id);

        // Fetch additional user data from database with better error handling
        try {
          const results = await Promise.allSettled([
            getUserCredentials(data.user.id),
            getUserProfile(data.user.id),
            getUserBalance(data.user.id),
          ]);

          const [credentialsResult, profileResult, balanceResult] = results;

          const extendedUser: ExtendedUser = {
            ...data.user,
            credentials:
              credentialsResult.status === "fulfilled"
                ? credentialsResult.value.data
                : undefined,
            profile:
              profileResult.status === "fulfilled"
                ? profileResult.value.data
                : undefined,
            balance:
              balanceResult.status === "fulfilled"
                ? balanceResult.value.data
                : undefined,
          };

          // Log any failed requests but don't fail the login
          if (credentialsResult.status === "rejected") {
            console.warn(
              "⚠️ Failed to load credentials during login:",
              credentialsResult.reason,
            );
          }
          if (profileResult.status === "rejected") {
            console.warn(
              "⚠️ Failed to load profile during login:",
              profileResult.reason,
            );
          }
          if (balanceResult.status === "rejected") {
            console.warn(
              "⚠️ Failed to load balance during login:",
              balanceResult.reason,
            );
          }

          setUser(extendedUser);
          setError(null);

          console.log("تم تحميل بيانات المستخدم بنجاح (مع معالجة الأخطاء):", {
            userId: data.user.id,
            email: data.user.email,
            username:
              credentialsResult.status === "fulfilled"
                ? credentialsResult.value.data?.username
                : "failed to load",
            profile:
              profileResult.status === "fulfilled"
                ? profileResult.value.data?.full_name
                : "failed to load",
            hasBalance:
              balanceResult.status === "fulfilled" &&
              !!balanceResult.value.data,
          });
        } catch (dbError) {
          console.error(
            "خطأ في جلب بيانات المستخدم من قاعدة البيانات:",
            dbError,
          );
          // Still set the user even if database fetch fails
          setUser(data.user);
          setError(null);
        }
      } else {
        console.error("لم يتم إرجاع بيانات المستخدم من Supabase");
        setError("حدث خطأ في تسجيل الدخول - لم يتم العثور على بيانات المستخدم");
        setLoading(false);
        return { data: null, error: { message: "No user data returned" } };
      }

      clearTimeout(loginTimeout);
      setLoading(false);
      return { data, error: null };
    } catch (err: any) {
      clearTimeout(loginTimeout);
      console.error("خطأ غير متوقع في تسجيل الدخول:", {
        message: err.message,
        stack: err.stack,
        name: err.name,
        cause: err.cause,
      });

      let errorMessage = "حدث خطأ غير متوقع";

      if (err.message?.includes("fetch")) {
        errorMessage = "مشكلة في الاتصال بالخادم. تأكد من اتصال الإنترنت";
      } else if (err.message?.includes("timeout")) {
        errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
      } else if (err.name === "TypeError") {
        errorMessage = "خطأ في إعدادات الاتصال. يرجى إعادة تحميل الصفحة";
      }

      setError(errorMessage);
      setLoading(false);
      return { data: null, error: { message: errorMessage } };
    }
  };

  const register = async (email: string, password: string, userData: any) => {
    setLoading(true);
    setError(null);

    // Set a timeout to prevent infinite loading
    const registerTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة إنشاء الحساب");
      setLoading(false);
      setError("انتهت مهلة إنشاء الحساب. يرجى المحاولة مرة أخرى");
    }, 30000); // 30 seconds timeout

    try {
      // Validate inputs
      if (!email?.trim() || !password) {
        clearTimeout(registerTimeout);
        const errorMessage = "يرجى إدخال البريد الإلكتروني وكلمة المرور";
        setError(errorMessage);
        setLoading(false);
        return { data: null, error: { message: errorMessage } };
      }

      if (password.length < 6) {
        clearTimeout(registerTimeout);
        const errorMessage = "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
        setError(errorMessage);
        setLoading(false);
        return { data: null, error: { message: errorMessage } };
      }

      console.log("🔄 بدء عملية إنشاء الحساب:", {
        email: email.trim(),
        hasUserData: !!userData,
        userData: {
          fullName: userData.fullName || userData.full_name,
          phone: userData.phone,
          username: userData.username,
          address: userData.address,
          referralCode: userData.referralCode,
        },
      });

      // إنشاء المستخدم مع إرسال جميع البيانات بما في ذلك كود الإحالة
      // كود الإحالة سيتم معالجته تلقائياً في الخلفية
      const { data, error } = await signUp(email.trim(), password, {
        full_name: userData.fullName || userData.full_name || "مستخدم جديد",
        fullName: userData.fullName || userData.full_name || "مستخدم جديد", // Keep both for compatibility
        phone: userData.phone || "",
        username: (userData.username || "")
          .toLowerCase()
          .replace(/[^a-z0-9_]/g, ""),
        address: userData.address || "",
        referralCode: userData.referralCode || null, // كود الإحالة سيتم معالجته تلقائياً
      });

      if (error) {
        console.error("Register error details:", error);
        let errorMessage = "حدث خطأ في إنشاء الحساب";

        if (
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
            "تسجيل الدخول بالبريد الإلكتروني معطل. يرجى التواصل مع الدعم الفني لتفعيل الحساب";
        } else if (
          error.message.includes("AuthSessionMissingError") ||
          error.message.includes("Auth session missing")
        ) {
          errorMessage =
            "خطأ في إعدادات المصادقة. يرجى إعادة تحميل الصفحة والمحاولة مرة أخرى";
        } else if (
          error.message.includes("Database error") ||
          error.message.includes("database")
        ) {
          errorMessage =
            "خطأ في قاعدة البيانات. يرجى المحاولة مرة أخرى أو التواصل مع الدعم الفني";
        } else if (error.message.includes("disabled")) {
          errorMessage = "الخدمة معطلة مؤقتاً. يرجى المحاولة لاحقاً";
        } else if (
          error.message.includes("Network") ||
          error.message.includes("network") ||
          error.message.includes("fetch")
        ) {
          errorMessage =
            "مشكلة في الاتصال بالإنترنت. تأكد من اتصالك وحاول مرة أخرى";
        } else if (error.message.includes("timeout")) {
          errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
        }

        setError(errorMessage);
        setLoading(false);
        return { data: null, error: { message: errorMessage } };
      }

      if (data?.user) {
        clearTimeout(registerTimeout);
        console.log("✅ تم إنشاء الحساب بنجاح في Supabase:", {
          userId: data.user.id,
          email: data.user.email,
          confirmed: data.user.email_confirmed_at ? "نعم" : "لا",
        });

        // The user profile and balance will be created automatically by the database trigger
        // Wait a moment for the trigger to complete
        console.log("⏳ انتظار إكمال إعداد المستخدم في قاعدة البيانات...");
        await new Promise((resolve) => setTimeout(resolve, 2000));

        // Fetch additional user data from database for new registration with better error handling
        try {
          const results = await Promise.allSettled([
            getUserCredentials(data.user.id),
            getUserProfile(data.user.id),
            getUserBalance(data.user.id),
          ]);

          const [credentialsResult, profileResult, balanceResult] = results;

          const extendedUser: ExtendedUser = {
            ...data.user,
            credentials:
              credentialsResult.status === "fulfilled"
                ? credentialsResult.value.data
                : undefined,
            profile:
              profileResult.status === "fulfilled"
                ? profileResult.value.data
                : undefined,
            balance:
              balanceResult.status === "fulfilled"
                ? balanceResult.value.data
                : undefined,
          };

          // Log any failed requests but don't fail the registration
          if (credentialsResult.status === "rejected") {
            console.warn(
              "⚠️ Failed to load credentials during registration:",
              credentialsResult.reason,
            );
          }
          if (profileResult.status === "rejected") {
            console.warn(
              "⚠️ Failed to load profile during registration:",
              profileResult.reason,
            );
          }
          if (balanceResult.status === "rejected") {
            console.warn(
              "⚠️ Failed to load balance during registration:",
              balanceResult.reason,
            );
          }

          setUser(extendedUser);
          setError(null);

          console.log(
            "✅ تم إنشاء الحساب بنجاح مع بيانات المستخدم (مع معالجة الأخطاء):",
            {
              userId: data.user.id,
              username:
                credentialsResult.status === "fulfilled"
                  ? credentialsResult.value.data?.username
                  : "failed to load",
              profile:
                profileResult.status === "fulfilled"
                  ? profileResult.value.data?.full_name
                  : "failed to load",
              fullName: data.user.user_metadata?.full_name,
              hasBalance:
                balanceResult.status === "fulfilled" &&
                !!balanceResult.value.data,
            },
          );
        } catch (dbError) {
          console.error("⚠️ خطأ في جلب بيانات المستخدم الجديد:", dbError);
          // Still set the user even if database fetch fails
          setUser(data.user);
          setError(null);
          console.log(
            "ℹ️ تم تسجيل المستخدم بنجاح رغم عدم تحميل بعض البيانات الإضافية",
          );
        }
      }

      clearTimeout(registerTimeout);
      setLoading(false);
      return { data, error: null };
    } catch (err: any) {
      clearTimeout(registerTimeout);
      console.error("💥 خطأ غير متوقع في إنشاء الحساب:", {
        message: err.message,
        name: err.name,
        stack: err.stack,
      });

      let errorMessage = "حدث خطأ غير متوقع في إنشاء الحساب";

      if (err.message?.includes("fetch")) {
        errorMessage = "مشكلة في الاتصال بالخادم. تأكد من اتصال الإنترنت";
      } else if (err.message?.includes("timeout")) {
        errorMessage = "انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى";
      } else if (err.name === "TypeError") {
        errorMessage = "خطأ في إعدادات الاتصال. يرجى إعادة تحميل الصفحة";
      }

      setError(errorMessage);
      setLoading(false);
      return { data: null, error: { message: errorMessage } };
    }
  };

  const logout = async () => {
    setLoading(true);
    setError(null);

    // Set a timeout to prevent infinite loading
    const logoutTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة تسجيل الخروج - سيتم إنهاء الجلسة محلياً");
      setUser(null);
      setError(null);
      setLoading(false);
    }, 10000); // 10 seconds timeout

    try {
      const { error } = await signOut();

      if (error) {
        console.error("Logout error:", error);
        setError("حدث خطأ في تسجيل الخروج");
        setLoading(false);
        return { error };
      }

      clearTimeout(logoutTimeout);
      setUser(null);
      setError(null);
      setLoading(false);
      return { error: null };
    } catch (err: any) {
      clearTimeout(logoutTimeout);
      console.error("Logout catch error:", err);
      const errorMessage = "حدث خطأ في تسجيل الخروج";
      setError(errorMessage);
      setLoading(false);
      return { error: { message: errorMessage } };
    }
  };

  const requestPasswordReset = async (email: string) => {
    setLoading(true);
    setError(null);

    try {
      const { error } = await resetPassword(email);

      if (error) {
        setError(error.message);
        return { error };
      }

      return { error: null };
    } catch (err: any) {
      const errorMessage = "حدث خطأ في إرسال رابط إعادة تعيين كلمة المرور";
      setError(errorMessage);
      return { error: { message: errorMessage } };
    } finally {
      setLoading(false);
    }
  };

  const confirmPasswordReset = async (newPassword: string) => {
    setLoading(true);
    setError(null);

    try {
      const { error } = await updatePassword(newPassword);

      if (error) {
        setError(error.message);
        return { error };
      }

      return { error: null };
    } catch (err: any) {
      const errorMessage = "حدث خطأ في تحديث كلمة المرور";
      setError(errorMessage);
      return { error: { message: errorMessage } };
    } finally {
      setLoading(false);
    }
  };

  const verifyEmail = async (token: string, type: string = "signup") => {
    setLoading(true);
    setError(null);

    // Set timeout to prevent infinite loading
    const verifyTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة تأكيد البريد الإلكتروني");
      setLoading(false);
      setError("انتهت مهلة تأكيد البريد الإلكتروني. يرجى المحاولة مرة أخرى");
    }, 15000); // 15 seconds timeout

    try {
      console.log("🔐 بدء عملية تأكيد البريد الإلكتروني...");
      const { data, error } = await verifyOtp(token, type);

      clearTimeout(verifyTimeout);

      if (error) {
        console.error("❌ خطأ في تأكيد البريد الإلكتروني:", error);
        setError(error.message);
        setLoading(false);
        return { error };
      }

      if (data?.user) {
        console.log("✅ تم تأكيد البريد الإلكتروني بنجاح:", {
          userId: data.user.id,
          email: data.user.email,
          confirmed: data.user.email_confirmed_at ? "نعم" : "لا",
        });

        // Update user state after successful verification
        setUser(data.user);
        setError(null);
      }

      setLoading(false);
      return { data, error: null };
    } catch (err: any) {
      clearTimeout(verifyTimeout);
      console.error("💥 خطأ غير متوقع في تأكيد البريد الإلكتروني:", err);
      const errorMessage = "حدث خطأ في تأكيد البريد الإلكتروني";
      setError(errorMessage);
      setLoading(false);
      return { error: { message: errorMessage } };
    }
  };

  const resendEmailVerification = async (email?: string) => {
    setLoading(true);
    setError(null);

    // Set timeout to prevent infinite loading
    const resendTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة إعادة إرسال رابط التأكيد");
      setLoading(false);
      setError("انتهت مهلة إعادة إرسال رابط التأكيد. يرجى المحاولة مرة أخرى");
    }, 10000); // 10 seconds timeout

    try {
      console.log("📧 بدء عملية إعادة إرسال رابط التأكيد...");
      const { error } = await resendVerification(email);

      clearTimeout(resendTimeout);

      if (error) {
        console.error("❌ خطأ في إعادة إرسال رابط التأكيد:", error);
        setError(error.message);
        setLoading(false);
        return { error };
      }

      console.log("✅ تم إرسال رابط التأكيد بنجاح");
      setError(null);
      setLoading(false);
      return { error: null };
    } catch (err: any) {
      clearTimeout(resendTimeout);
      console.error("💥 خطأ غير متوقع في إعادة إرسال رابط التأكيد:", err);
      const errorMessage = "حدث خطأ في إعادة إرسال رابط التأكيد";
      setError(errorMessage);
      setLoading(false);
      return { error: { message: errorMessage } };
    }
  };

  // OTP Functions
  const sendOTP = async (
    phoneNumber?: string,
    email?: string,
    otpType: string = "phone_verification",
  ) => {
    setLoading(true);
    setError(null);

    try {
      const { data, error } = await createOTP(
        user?.id,
        phoneNumber,
        email,
        otpType,
        otpType === "email_verification" ? 10 : 5, // 10 minutes for email, 5 for phone
      );

      if (error) {
        setError(error.message);
        return { error };
      }

      return { data, error: null };
    } catch (err: any) {
      const errorMessage = "حدث خطأ في إرسال رمز التحقق";
      setError(errorMessage);
      return { error: { message: errorMessage } };
    } finally {
      setLoading(false);
    }
  };

  const verifyOTPCode = async (
    phoneNumber?: string,
    email?: string,
    otpCode: string,
    otpType: string = "phone_verification",
  ) => {
    setLoading(true);
    setError(null);

    try {
      const { data, error } = await verifyOTP(
        phoneNumber,
        email,
        otpCode,
        otpType,
      );

      if (error) {
        setError(error.message);
        return { error };
      }

      // Update user state if verification was successful
      if (data && user) {
        const updatedUser = {
          ...user,
          ...(phoneNumber && { phone: phoneNumber }),
          ...(email && { email: email }),
          user_metadata: {
            ...user.user_metadata,
            ...(otpType === "phone_verification" && { phone_verified: true }),
            ...(otpType === "email_verification" && { email_verified: true }),
          },
        };
        setUser(updatedUser);
      }

      return { data, error: null };
    } catch (err: any) {
      const errorMessage = "حدث خطأ في التحقق من رمز OTP";
      setError(errorMessage);
      return { error: { message: errorMessage } };
    } finally {
      setLoading(false);
    }
  };

  const checkOTPStatus = async (
    phoneNumber?: string,
    email?: string,
    otpType: string = "phone_verification",
  ) => {
    try {
      const { data, error } = await getOTPStatus(phoneNumber, email, otpType);
      return { data, error };
    } catch (err: any) {
      return { data: null, error: { message: err.message } };
    }
  };

  // Email OTP functions
  const sendEmailOTP = async (email?: string) => {
    return sendOTP(undefined, email || user?.email, "email_verification");
  };

  const verifyEmailOTP = async (otpCode: string, email?: string) => {
    return verifyOTPCode(
      undefined,
      email || user?.email,
      otpCode,
      "email_verification",
    );
  };

  return {
    user,
    loading,
    error,
    login,
    loginWithGoogle,
    register,
    logout,
    requestPasswordReset,
    confirmPasswordReset,
    verifyEmail,
    resendEmailVerification,
    sendOTP,
    verifyOTPCode,
    checkOTPStatus,
    sendEmailOTP,
    verifyEmailOTP,
  };
};
