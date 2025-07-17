import { useState, useEffect } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  CheckCircle,
  Mail,
  ArrowRight,
  AlertCircle,
  Loader2,
  RefreshCw,
  Key,
} from "lucide-react";
import { useAuth } from "../hooks/useAuth";
import { createOTP, verifyOTP, getOTPStatus } from "../lib/supabase";
import { Alert, AlertDescription } from "@/components/ui/alert";

export default function EmailVerificationPage() {
  const [verificationCode, setVerificationCode] = useState("");
  const [isVerifying, setIsVerifying] = useState(false);
  const [isResending, setIsResending] = useState(false);
  const [message, setMessage] = useState("");
  const [success, setSuccess] = useState(false);
  const [useCodeMethod, setUseCodeMethod] = useState(false);
  const [useOTPSystem, setUseOTPSystem] = useState(true);
  const [otpId, setOtpId] = useState<string | null>(null);
  const [attemptsRemaining, setAttemptsRemaining] = useState(5);
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { verifyEmail, resendEmailVerification, user } = useAuth();

  // Auto-verify if token is in URL
  useEffect(() => {
    const token = searchParams.get("token") || searchParams.get("token_hash");
    const type = searchParams.get("type") || "signup";

    console.log("🔍 فحص معاملات URL:", {
      token: token ? token.substring(0, 10) + "..." : "غير موجود",
      type,
      allParams: Object.fromEntries(searchParams.entries()),
    });

    if (token) {
      console.log(
        "🔐 تم العثور على رمز التأكيد في URL، بدء التأكيد التلقائي...",
      );
      handleAutoVerification(token, type);
    } else {
      console.log("ℹ️ لم يتم العثور على رمز التأكيد في URL");
      setUseCodeMethod(true); // Default to code method if no token
    }
  }, [searchParams]);

  const handleAutoVerification = async (token: string, type: string) => {
    setIsVerifying(true);
    setMessage("");
    setSuccess(false);

    // Set timeout for verification process
    const verificationTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة عملية التأكيد التلقائي");
      setIsVerifying(false);
      setMessage("انتهت مهلة تأكيد البريد الإلكتروني. يرجى المحاولة مرة أخرى");
      setSuccess(false);
    }, 20000); // 20 seconds timeout

    try {
      console.log("🔐 بدء عملية التأكيد التلقائي...");
      const { data, error } = await verifyEmail(token, type);

      clearTimeout(verificationTimeout);

      if (error) {
        console.error("❌ فشل في التأكيد التلقائي:", error);
        let errorMessage = error.message || "فشل في تأكيد البريد الإلكتروني";

        // Provide more specific error messages
        if (error.message?.includes("expired")) {
          errorMessage =
            "انتهت صلاحية رابط التأكيد. يرجى طلب رابط جديد من أسفل الصفحة";
        } else if (error.message?.includes("invalid")) {
          errorMessage = "رابط التأكيد غير صحيح أو تم استخدامه من قبل";
        } else if (error.message?.includes("already confirmed")) {
          errorMessage =
            "تم تأكيد البريد الإلكتروني مسبقاً. يمكنك تسجيل الدخول الآن";
          setSuccess(true);
          setTimeout(() => {
            navigate("/", { replace: true, state: { emailVerified: true } });
          }, 2000);
          return;
        }

        setMessage(errorMessage);
        setSuccess(false);
      } else {
        console.log("✅ تم التأكيد التلقائي بنجاح:", data?.user?.id);
        setMessage(
          "تم تأكيد البريد الإلكتروني بنجاح! سيتم توجيهك إلى صفحة تسجيل الدخول...",
        );
        setSuccess(true);

        // Redirect to landing page with email verification state
        setTimeout(() => {
          console.log("🏠 إعادة توجيه إلى الصفحة الرئيسية مع حالة تحميل");
          navigate("/", { replace: true, state: { emailVerified: true } });
        }, 2000);
      }
    } catch (err: any) {
      clearTimeout(verificationTimeout);
      console.error("💥 خطأ غير متوقع في التأكيد التلقائي:", err);
      setMessage("حدث خطأ غير متوقع في تأكيد البريد الإلكتروني");
      setSuccess(false);
    } finally {
      setIsVerifying(false);
    }
  };

  const handleManualVerification = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!verificationCode.trim()) {
      setMessage("يرجى إدخال رمز التأكيد");
      setSuccess(false);
      return;
    }

    if (verificationCode.trim().length !== 6) {
      setMessage("رمز التأكيد يجب أن يكون 6 أرقام بالضبط");
      setSuccess(false);
      return;
    }

    setIsVerifying(true);
    setMessage("");
    setSuccess(false);

    // Set timeout for manual verification
    const manualTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة التأكيد اليدوي");
      setIsVerifying(false);
      setMessage("انتهت مهلة تأكيد البريد الإلكتروني. يرجى المحاولة مرة أخرى");
      setSuccess(false);
    }, 15000); // 15 seconds timeout

    try {
      console.log("🔐 بدء التأكيد اليدوي بالرمز...");

      let result;
      if (useOTPSystem) {
        // Use new OTP system
        const emailFromParams = searchParams.get("email") || user?.email;
        if (!emailFromParams) {
          setMessage("لم يتم العثور على البريد الإلكتروني");
          setSuccess(false);
          return;
        }

        result = await verifyOTP(
          null, // phone_number
          emailFromParams, // email
          verificationCode.trim(),
          "email_verification",
        );
      } else {
        // Fallback to old system
        result = await verifyEmail(verificationCode.trim());
      }

      clearTimeout(manualTimeout);

      if (result.error) {
        console.error("❌ فشل في التأكيد اليدوي:", result.error);
        let errorMessage = result.error.message || "رمز التأكيد غير صحيح";

        if (result.error.message?.includes("expired")) {
          errorMessage = "انتهت صلاحية رمز التأكيد. يرجى طلب رمز جديد";
        } else if (result.error.message?.includes("invalid")) {
          errorMessage = "رمز التأكيد غير صحيح. تأكد من إدخال الرمز بشكل صحيح";
        } else if (result.error.message?.includes("already confirmed")) {
          errorMessage =
            "تم تأكيد البريد الإلكتروني مسبقاً. يمكنك تسجيل الدخول الآن";
          setSuccess(true);
          setTimeout(() => {
            navigate("/", { replace: true, state: { emailVerified: true } });
          }, 2000);
          return;
        }

        setMessage(errorMessage);
        setSuccess(false);

        // Decrement attempts for OTP system
        if (useOTPSystem && attemptsRemaining > 1) {
          setAttemptsRemaining(attemptsRemaining - 1);
        }
      } else {
        console.log("✅ تم التأكيد اليدوي بنجاح:", result.data);
        setMessage(
          "تم تأكيد البريد الإلكتروني بنجاح! سيتم توجيهك إلى صفحة تسجيل الدخول...",
        );
        setSuccess(true);
        setVerificationCode(""); // Clear the input

        // Redirect to landing page with email verification state
        setTimeout(() => {
          console.log("🏠 إعادة توجيه إلى الصفحة الرئيسية مع حالة تحميل");
          navigate("/", { replace: true, state: { emailVerified: true } });
        }, 2000);
      }
    } catch (err: any) {
      clearTimeout(manualTimeout);
      console.error("💥 خطأ غير متوقع في التأكيد اليدوي:", err);
      setMessage("حدث خطأ غير متوقع في تأكيد البريد الإلكتروني");
      setSuccess(false);
    } finally {
      setIsVerifying(false);
    }
  };

  const handleResendVerification = async () => {
    setIsResending(true);
    setMessage("");
    setSuccess(false);

    // Set timeout for resend operation
    const resendTimeout = setTimeout(() => {
      console.log("⏰ انتهت مهلة إعادة الإرسال");
      setIsResending(false);
      setMessage(
        "انتهت مهلة إعادة إرسال رسالة التأكيد. يرجى المحاولة مرة أخرى",
      );
      setSuccess(false);
    }, 10000); // 10 seconds timeout

    try {
      console.log("📧 بدء إعادة إرسال رابط التأكيد...");

      // Try to get email from URL params or user input
      const emailFromParams = searchParams.get("email") || user?.email;

      // Use the new link-based system
      const result = await resendEmailVerification(
        emailFromParams || undefined,
      );

      clearTimeout(resendTimeout);

      if (result.error) {
        console.error("❌ فشل في إعادة الإرسال:", result.error);
        let errorMessage =
          result.error.message || "فشل في إعادة إرسال رابط التأكيد";

        if (result.error.message?.includes("rate limit")) {
          errorMessage =
            "تم تجاوز الحد المسموح لإرسال الرسائل. يرجى الانتظار قبل المحاولة مرة أخرى";
        } else if (result.error.message?.includes("already confirmed")) {
          errorMessage =
            "تم تأكيد البريد الإلكتروني مسبقاً. يمكنك تسجيل الدخول الآن";
          setSuccess(true);
          setTimeout(() => {
            navigate("/", { replace: true, state: { emailVerified: true } });
          }, 2000);
          return;
        }

        setMessage(errorMessage);
        setSuccess(false);
      } else {
        console.log("✅ تم إعادة إرسال رابط التأكيد بنجاح");
        setMessage(
          "تم إعادة إرسال رابط التأكيد بنجاح! تحقق من بريدك الإلكتروني واضغط على الرابط لتأكيد حسابك",
        );
        setSuccess(true);
        setUseCodeMethod(false); // Switch back to link-based verification
      }
    } catch (err: any) {
      clearTimeout(resendTimeout);
      console.error("💥 خطأ غير متوقع في إعادة الإرسال:", err);
      setMessage("حدث خطأ في إعادة إرسال رابط التأكيد");
      setSuccess(false);
    } finally {
      setIsResending(false);
    }
  };

  const handleBackToLogin = () => {
    navigate("/", { replace: true });
  };

  return (
    <div className="min-h-screen w-full bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 relative overflow-hidden">
      {/* Animated Background */}
      <div className="absolute inset-0">
        <div className="absolute top-0 left-1/4 w-32 h-32 sm:w-64 sm:h-64 lg:w-96 lg:h-96 bg-blue-400/20 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-pulse"></div>
        <div className="absolute top-1/3 right-1/4 w-32 h-32 sm:w-64 sm:h-64 lg:w-96 lg:h-96 bg-purple-400/20 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-pulse animation-delay-2000"></div>
        <div className="absolute bottom-0 left-1/2 w-32 h-32 sm:w-64 sm:h-64 lg:w-96 lg:h-96 bg-indigo-400/20 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-pulse animation-delay-4000"></div>
      </div>

      {/* Grid Pattern */}
      <div className="absolute inset-0 bg-black/10">
        <div
          className="absolute inset-0 opacity-20"
          style={{
            backgroundImage: `linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px)`,
            backgroundSize: "20px 20px",
          }}
        ></div>
      </div>

      <div className="relative z-10 flex items-center justify-center min-h-screen p-4">
        <div className="w-full max-w-md">
          <Card className="bg-white/10 backdrop-blur-md border border-white/20 shadow-2xl">
            <CardHeader className="text-center pb-6">
              <div className="flex justify-center mb-4">
                <div className="w-16 h-16 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-2xl flex items-center justify-center">
                  {success ? (
                    <CheckCircle className="w-8 h-8 text-white" />
                  ) : useCodeMethod ? (
                    <Key className="w-8 h-8 text-white" />
                  ) : (
                    <Mail className="w-8 h-8 text-white" />
                  )}
                </div>
              </div>
              <CardTitle className="text-2xl font-bold text-white mb-2">
                {success
                  ? "تم التأكيد بنجاح"
                  : useCodeMethod
                    ? "إدخال كود التأكيد"
                    : "تأكيد البريد الإلكتروني"}
              </CardTitle>
              <CardDescription className="text-gray-300">
                {success
                  ? "تم تأكيد بريدك الإلكتروني بنجاح"
                  : searchParams.get("token") || searchParams.get("token_hash")
                    ? "جاري تأكيد بريدك الإلكتروني..."
                    : "تحقق من بريدك الإلكتروني واضغط على رابط التأكيد"}
              </CardDescription>
            </CardHeader>

            <CardContent className="space-y-6">
              {/* Status Messages */}
              {message && (
                <Alert
                  className={`${
                    success
                      ? "bg-green-500/20 border-green-500/50 text-green-200"
                      : "bg-red-500/20 border-red-500/50 text-red-200"
                  }`}
                >
                  {success ? (
                    <CheckCircle className="h-4 w-4" />
                  ) : (
                    <AlertCircle className="h-4 w-4" />
                  )}
                  <AlertDescription className="text-right">
                    {message}
                  </AlertDescription>
                </Alert>
              )}

              {/* Auto-verification in progress */}
              {isVerifying &&
                (searchParams.get("token") ||
                  searchParams.get("token_hash")) && (
                  <div className="flex flex-col items-center justify-center space-y-3 text-white">
                    <div className="flex items-center space-x-2">
                      <Loader2 className="w-5 h-5 animate-spin" />
                      <span>جاري تأكيد البريد الإلكتروني...</span>
                    </div>
                    <p className="text-gray-400 text-sm text-center">
                      يرجى الانتظار، قد تستغرق العملية بضع ثوانٍ
                    </p>
                  </div>
                )}

              {/* Link-based verification message */}
              {!success && !isVerifying && (
                <div className="text-center space-y-4">
                  <div className="bg-blue-500/20 border border-blue-500/50 rounded-lg p-4">
                    <Mail className="w-8 h-8 text-blue-400 mx-auto mb-2" />
                    <p className="text-blue-200 text-sm">
                      تم إرسال رابط التأكيد إلى بريدك الإلكتروني
                    </p>
                    <p className="text-gray-300 text-xs mt-2">
                      ابحث عن رسالة من منصة الدفع الرقمية واضغط على رابط التأكيد
                    </p>
                  </div>
                </div>
              )}

              {/* Resend verification */}
              {!success && (
                <div className="text-center space-y-3">
                  <p className="text-gray-300 text-sm">
                    لم تستلم رابط التأكيد؟
                  </p>
                  <Button
                    onClick={handleResendVerification}
                    variant="outline"
                    className="bg-white/10 border-white/30 text-white hover:bg-white/20 disabled:opacity-50"
                    disabled={isResending}
                  >
                    {isResending ? (
                      <>
                        <Loader2 className="w-4 h-4 animate-spin ml-2" />
                        جاري الإرسال...
                      </>
                    ) : (
                      <>
                        <RefreshCw className="w-4 h-4 ml-2" />
                        إعادة إرسال رابط التأكيد
                      </>
                    )}
                  </Button>
                </div>
              )}

              {/* Success state - redirect info */}
              {success && (
                <div className="text-center space-y-4">
                  <div className="flex justify-center">
                    <div className="w-16 h-16 bg-green-500/20 rounded-full flex items-center justify-center">
                      <CheckCircle className="w-10 h-10 text-green-400" />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <p className="text-white text-lg font-medium">
                      تم تأكيد البريد الإلكتروني بنجاح!
                    </p>
                    <p className="text-green-400 text-sm">
                      ✅ يمكنك الآن تسجيل الدخول إلى حسابك
                    </p>
                    <p className="text-gray-300 text-sm">
                      سيتم توجيهك إلى صفحة تسجيل الدخول خلال ثانيتين...
                    </p>
                  </div>
                  <div className="flex justify-center">
                    <div className="w-8 h-8 border-2 border-green-400/30 border-t-green-400 rounded-full animate-spin"></div>
                  </div>
                </div>
              )}

              {/* Navigation buttons */}
              <div className="text-center pt-4 border-t border-white/20 space-y-3">
                <Button
                  onClick={handleBackToLogin}
                  variant="ghost"
                  className="text-blue-400 hover:text-blue-300 hover:bg-white/10 w-full"
                >
                  العودة إلى تسجيل الدخول
                </Button>

                {!success && (
                  <div className="text-center">
                    <p className="text-gray-400 text-xs mb-2">
                      لم تستلم البريد الإلكتروني؟ تحقق من مجلد الرسائل غير
                      المرغوب فيها أو البريد المهمل
                    </p>
                    <a
                      href="/signup"
                      className="text-gray-400 hover:text-gray-300 text-xs underline"
                    >
                      إنشاء حساب جديد
                    </a>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
