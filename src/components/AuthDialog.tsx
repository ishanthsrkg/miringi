import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  AlertCircle,
  Loader2,
  Eye,
  EyeOff,
  Shield,
  Zap,
  Gift,
  Users,
  Star,
  CheckCircle,
  Sparkles,
  ArrowRight,
  X,
} from "lucide-react";
import { useAuth } from "../hooks/useAuth";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { useNavigate } from "react-router-dom";

interface AuthDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  defaultMode?: "login" | "signup";
  referralCode?: string | null;
  showEmailVerificationLoading?: boolean;
  onEmailVerificationLoadingChange?: (loading: boolean) => void;
}

export default function AuthDialog({
  open,
  onOpenChange,
  defaultMode = "login",
  referralCode,
  showEmailVerificationLoading = false,
  onEmailVerificationLoadingChange,
}: AuthDialogProps) {
  const [mode, setMode] = useState<"login" | "signup">(defaultMode);
  const [method, setMethod] = useState<"google" | "email">("google");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  // Form states
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [referralCodeInput, setReferralCodeInput] = useState("");
  const [rememberMe, setRememberMe] = useState(false);

  const { loginWithGoogle, login, register, loading, error, user } = useAuth();
  const navigate = useNavigate();

  // Reset form when dialog opens/closes or mode changes
  useEffect(() => {
    if (!open) {
      setEmail("");
      setPassword("");
      setConfirmPassword("");
      setFullName("");
      setPhone("");
      if (!referralCode) {
        setReferralCodeInput("");
      }
      setRememberMe(false);
      setShowPassword(false);
      setShowConfirmPassword(false);
      setIsSubmitting(false);
    }
  }, [open, referralCode]);

  // Set referral code when provided
  useEffect(() => {
    if (referralCode && open) {
      console.log("🔗 تعيين كود الإحالة في النموذج:", referralCode);
      setReferralCodeInput(referralCode);
    }
  }, [referralCode, open]);

  // Close dialog and navigate when user is authenticated
  useEffect(() => {
    if (user && !loading && open) {
      console.log(
        "✅ تم تسجيل الدخول بنجاح - إغلاق النافذة والتوجه للصفحة الرئيسية",
      );
      // Clear email verification loading state
      if (onEmailVerificationLoadingChange) {
        onEmailVerificationLoadingChange(false);
      }
      // Small delay to show success before redirect
      setTimeout(() => {
        onOpenChange(false);
        navigate("/home", { replace: true });
      }, 500);
    }
  }, [
    user,
    loading,
    open,
    onOpenChange,
    navigate,
    onEmailVerificationLoadingChange,
  ]);

  const handleGoogleAuth = async () => {
    if (isSubmitting || loading) return;

    setIsSubmitting(true);
    try {
      console.log(
        `🔐 بدء عملية ${mode === "login" ? "تسجيل الدخول" : "إنشاء الحساب"} بجوجل...`,
      );
      const { data, error: authError } = await loginWithGoogle();

      if (authError) {
        console.error(
          `❌ خطأ في ${mode === "login" ? "تسجيل الدخول" : "إنشاء الحساب"} بجوجل:`,
          authError,
        );
        setIsSubmitting(false);
        return;
      }

      if (data) {
        console.log(
          `✅ تم ${mode === "login" ? "تسجيل الدخول" : "إنشاء الحساب"} بجوجل بنجاح`,
        );
      }
    } catch (err) {
      console.error(
        `💥 خطأ غير متوقع في ${mode === "login" ? "تسجيل الدخول" : "إنشاء الحساب"} بجوجل:`,
        err,
      );
      setIsSubmitting(false);
    }
  };

  const handleEmailAuth = async (e: React.FormEvent) => {
    e.preventDefault();
    if (isSubmitting || loading) return;

    // Validate passwords match for signup
    if (mode === "signup" && password !== confirmPassword) {
      console.error("❌ كلمات المرور غير متطابقة");
      return;
    }

    setIsSubmitting(true);
    try {
      if (mode === "login") {
        console.log("🔐 بدء عملية تسجيل الدخول بالبريد الإلكتروني...");
        const { data, error: loginError } = await login(email, password);

        if (loginError) {
          console.error("❌ خطأ في تسجيل الدخول:", loginError);
          setIsSubmitting(false);
          return;
        }

        if (data) {
          console.log("✅ تم تسجيل الدخول بنجاح");
        }
      } else {
        console.log("🔐 بدء عملية إنشاء الحساب بالبريد الإلكتروني...");
        const { data, error: signupError } = await register(email, password, {
          fullName,
          phone,
          referralCode: referralCodeInput || null,
        });

        if (signupError) {
          console.error("❌ خطأ في إنشاء الحساب:", signupError);
          setIsSubmitting(false);
          return;
        }

        if (data) {
          console.log("✅ تم إنشاء الحساب بنجاح");
        }
      }
    } catch (err) {
      console.error(
        `💥 خطأ غير متوقع في ${mode === "login" ? "تسجيل الدخول" : "إنشاء الحساب"}:`,
        err,
      );
      setIsSubmitting(false);
    }
  };

  const benefits = [
    {
      icon: Gift,
      title: "مكافأة ترحيبية",
      description: "1000 دج مجاناً",
      color: "text-green-400",
    },
    {
      icon: Shield,
      title: "أمان عالي",
      description: "تشفير 256-bit",
      color: "text-blue-400",
    },
    {
      icon: Zap,
      title: "تحويلات فورية",
      description: "< 30 ثانية",
      color: "text-yellow-400",
    },
    {
      icon: Users,
      title: "نظام الإحالة",
      description: "500 دج لكل إحالة",
      color: "text-purple-400",
    },
  ];

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-4xl w-full bg-gradient-to-br from-slate-900/95 via-blue-900/95 to-indigo-900/95 backdrop-blur-xl border border-white/20 shadow-2xl text-white overflow-hidden fixed top-[5%] left-1/2 transform -translate-x-1/2 -translate-y-0">
        {/* Close Button */}
        <button
          onClick={() => onOpenChange(false)}
          className="absolute right-4 top-4 z-50 p-2 rounded-full bg-white/10 hover:bg-white/20 transition-colors"
        >
          <X className="w-5 h-5 text-white" />
        </button>

        {/* Background Effects */}
        <div className="absolute inset-0 overflow-hidden">
          <div className="absolute top-0 left-1/4 w-64 h-64 bg-blue-400/20 rounded-full mix-blend-multiply filter blur-3xl opacity-70 animate-pulse"></div>
          <div className="absolute bottom-0 right-1/4 w-64 h-64 bg-purple-400/20 rounded-full mix-blend-multiply filter blur-3xl opacity-70 animate-pulse animation-delay-2000"></div>
          <div className="absolute top-1/2 left-0 w-48 h-48 bg-indigo-400/20 rounded-full mix-blend-multiply filter blur-2xl opacity-50 animate-pulse animation-delay-4000"></div>
        </div>

        <div className="relative z-10 grid grid-cols-1 lg:grid-cols-2 gap-8 p-6">
          {/* Left Side - Benefits & Branding */}
          <div className="space-y-6">
            <DialogHeader className="text-right">
              <div className="flex items-center justify-center lg:justify-end mb-4">
                <img
                  src="/logo.png"
                  alt="Netlify Logo"
                  className="w-12 h-12 object-contain drop-shadow-lg"
                />
                <DialogTitle className="text-2xl font-bold text-white mr-3">
                  Netlify
                </DialogTitle>
              </div>
              <DialogDescription className="text-gray-300 text-lg leading-relaxed">
                البنك الرقمي الأول في الجزائر - إدارة أموالك بذكاء وأمان
              </DialogDescription>
            </DialogHeader>
            {/* Benefits Grid */}
            {/* Animated Features */}
            {/* Trust Indicators */}
          </div>

          {/* Right Side - Auth Form */}
          <div className="space-y-6">
            {/* Mode Toggle */}

            {/* Method Toggle */}
            <div className="flex items-center justify-center">
              <div className="bg-white/5 rounded-xl p-1 border border-white/20">
                <button
                  onClick={() => setMethod("google")}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                    method === "google"
                      ? "bg-white text-gray-900"
                      : "text-white hover:bg-white/10"
                  }`}
                >
                  تسجيل سريع
                </button>
                <button
                  onClick={() => setMethod("email")}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                    method === "email"
                      ? "bg-white text-gray-900"
                      : "text-white hover:bg-white/10"
                  }`}
                >
                  بريد إلكتروني
                </button>
              </div>
            </div>
            {/* Email Verification Loading State */}
            {showEmailVerificationLoading && (
              <Alert className="bg-blue-500/20 border-blue-500/50 text-blue-200">
                <Loader2 className="h-4 w-4 animate-spin" />
                <AlertDescription className="text-right">
                  تم تأكيد البريد الإلكتروني بنجاح! جاري تسجيل الدخول...
                </AlertDescription>
              </Alert>
            )}

            {/* Error Display */}
            {error && (
              <Alert className="bg-red-500/20 border-red-500/50 text-red-200">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription className="text-right">
                  {error}
                </AlertDescription>
              </Alert>
            )}
            {/* Auth Forms */}
            {method === "google" ? (
              <div className="space-y-4">
                {/* Referral Code Display */}
                {referralCodeInput && (
                  <div className="bg-gradient-to-r from-green-500/20 to-emerald-500/20 border border-green-400/30 rounded-lg p-4 text-center">
                    <div className="flex items-center justify-center mb-2">
                      <Gift className="w-5 h-5 text-green-400 ml-2" />
                      <span className="text-green-400 font-semibold">
                        كود الإحالة
                      </span>
                    </div>
                    <div className="text-white text-lg font-bold">
                      {referralCodeInput}
                    </div>
                    <div className="text-green-300 text-sm mt-1">
                      ستحصل على 500 دج مكافأة!
                    </div>
                  </div>
                )}

                <Button
                  onClick={handleGoogleAuth}
                  className="w-full h-12 bg-gradient-to-r from-white to-gray-50 hover:from-gray-50 hover:to-white text-gray-900 font-medium flex items-center justify-center gap-3 transition-all duration-300 shadow-xl hover:shadow-2xl disabled:opacity-50 disabled:cursor-not-allowed rounded-lg transform hover:scale-105"
                  disabled={loading || isSubmitting}
                >
                  {loading || isSubmitting ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin" />
                      <span>
                        جاري{" "}
                        {mode === "login" ? "تسجيل الدخول" : "إنشاء الحساب"}...
                      </span>
                    </>
                  ) : (
                    <>
                      <svg className="w-5 h-5" viewBox="0 0 24 24">
                        <path
                          fill="#4285F4"
                          d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                        />
                        <path
                          fill="#34A853"
                          d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                        />
                        <path
                          fill="#FBBC05"
                          d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                        />
                        <path
                          fill="#EA4335"
                          d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                        />
                      </svg>
                      <span>
                        {mode === "login" ? "تسجيل الدخول" : "إنشاء حساب"} بجوجل
                      </span>
                    </>
                  )}
                </Button>
              </div>
            ) : (
              <form onSubmit={handleEmailAuth} className="space-y-4">
                {mode === "signup" && (
                  <div className="space-y-2">
                    <Label
                      htmlFor="fullName"
                      className="text-white text-right block"
                    >
                      الاسم الكامل
                    </Label>
                    <Input
                      id="fullName"
                      type="text"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      className="w-full h-12 bg-gradient-to-r from-white/10 to-white/5 border-white/30 text-white placeholder-gray-300 rounded-lg focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/20 text-right backdrop-blur-sm transition-all duration-300"
                      placeholder="أدخل اسمك الكامل"
                      required
                      disabled={loading || isSubmitting}
                    />
                  </div>
                )}

                <div className="space-y-2">
                  <Label
                    htmlFor="email"
                    className="text-white text-right block"
                  >
                    البريد الإلكتروني
                  </Label>
                  <Input
                    id="email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full h-12 bg-gradient-to-r from-white/10 to-white/5 border-white/30 text-white placeholder-gray-300 rounded-lg focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/20 text-right backdrop-blur-sm transition-all duration-300"
                    placeholder="أدخل بريدك الإلكتروني"
                    required
                    disabled={loading || isSubmitting}
                  />
                </div>

                {mode === "signup" && (
                  <div className="space-y-2">
                    <Label
                      htmlFor="phone"
                      className="text-white text-right block"
                    >
                      رقم الهاتف (اختياري)
                    </Label>
                    <Input
                      id="phone"
                      type="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      className="w-full h-12 bg-gradient-to-r from-white/10 to-white/5 border-white/30 text-white placeholder-gray-300 rounded-lg focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/20 text-right backdrop-blur-sm transition-all duration-300"
                      placeholder="أدخل رقم هاتفك"
                      disabled={loading || isSubmitting}
                    />
                  </div>
                )}

                <div className="space-y-2">
                  <Label
                    htmlFor="password"
                    className="text-white text-right block"
                  >
                    كلمة المرور
                  </Label>
                  <div className="relative">
                    <Input
                      id="password"
                      type={showPassword ? "text" : "password"}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="w-full h-12 bg-gradient-to-r from-white/10 to-white/5 border-white/30 text-white placeholder-gray-300 rounded-lg focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/20 text-right pr-12 backdrop-blur-sm transition-all duration-300"
                      placeholder="أدخل كلمة المرور"
                      required
                      disabled={loading || isSubmitting}
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-white transition-colors"
                    >
                      {showPassword ? (
                        <EyeOff className="w-5 h-5" />
                      ) : (
                        <Eye className="w-5 h-5" />
                      )}
                    </button>
                  </div>
                </div>

                {mode === "signup" && (
                  <div className="space-y-2">
                    <Label
                      htmlFor="confirmPassword"
                      className="text-white text-right block"
                    >
                      تأكيد كلمة المرور
                    </Label>
                    <div className="relative">
                      <Input
                        id="confirmPassword"
                        type={showConfirmPassword ? "text" : "password"}
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        className="w-full h-12 bg-gradient-to-r from-white/10 to-white/5 border-white/30 text-white placeholder-gray-300 rounded-lg focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/20 text-right pr-12 backdrop-blur-sm transition-all duration-300"
                        placeholder="أعد إدخال كلمة المرور"
                        required
                        disabled={loading || isSubmitting}
                      />
                      <button
                        type="button"
                        onClick={() =>
                          setShowConfirmPassword(!showConfirmPassword)
                        }
                        className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-white transition-colors"
                      >
                        {showConfirmPassword ? (
                          <EyeOff className="w-5 h-5" />
                        ) : (
                          <Eye className="w-5 h-5" />
                        )}
                      </button>
                    </div>
                    {password !== confirmPassword && confirmPassword && (
                      <p className="text-red-400 text-sm text-right">
                        كلمات المرور غير متطابقة
                      </p>
                    )}
                  </div>
                )}

                {mode === "signup" && (
                  <div className="space-y-2">
                    <Label
                      htmlFor="referralCode"
                      className="text-white text-right block"
                    >
                      كود الإحالة {referralCodeInput ? "" : "(اختياري)"}
                    </Label>
                    <div className="relative">
                      <Input
                        id="referralCode"
                        type="text"
                        value={referralCodeInput}
                        onChange={(e) => setReferralCodeInput(e.target.value)}
                        className={`w-full h-12 bg-gradient-to-r from-white/10 to-white/5 border-white/30 text-white placeholder-gray-300 rounded-lg focus:border-cyan-400 focus:ring-2 focus:ring-cyan-400/20 text-right backdrop-blur-sm transition-all duration-300 ${
                          referralCodeInput
                            ? "border-green-400/50 bg-green-500/10"
                            : ""
                        }`}
                        placeholder="أدخل كود الإحالة إن وجد"
                        disabled={loading || isSubmitting}
                      />
                      {referralCodeInput && (
                        <div className="absolute left-3 top-1/2 transform -translate-y-1/2">
                          <CheckCircle className="w-5 h-5 text-green-400" />
                        </div>
                      )}
                    </div>
                    {referralCodeInput && (
                      <p className="text-green-400 text-sm text-right">
                        ✅ سيتم تطبيق كود الإحالة: {referralCodeInput}
                      </p>
                    )}
                  </div>
                )}

                {mode === "login" && (
                  <div className="flex items-center justify-between text-sm">
                    <a
                      href="/forgot-password"
                      className="text-blue-400 hover:text-blue-300 transition-colors"
                    >
                      نسيت كلمة المرور؟
                    </a>
                    <div className="flex items-center space-x-2">
                      <input
                        type="checkbox"
                        id="remember"
                        checked={rememberMe}
                        onChange={(e) => setRememberMe(e.target.checked)}
                        className="w-4 h-4 text-blue-600 bg-white/10 border-white/20 rounded focus:ring-blue-500"
                      />
                      <Label htmlFor="remember" className="text-white">
                        تذكرني
                      </Label>
                    </div>
                  </div>
                )}

                <Button
                  type="submit"
                  className="w-full h-12 bg-gradient-to-r from-cyan-500 via-blue-600 to-purple-600 hover:from-cyan-600 hover:via-blue-700 hover:to-purple-700 text-white font-medium transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed rounded-lg shadow-xl hover:shadow-2xl transform hover:scale-105"
                  disabled={
                    loading ||
                    isSubmitting ||
                    (mode === "signup" && password !== confirmPassword)
                  }
                >
                  {loading || isSubmitting ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin mr-2" />
                      جاري {mode === "login" ? "تسجيل الدخول" : "إنشاء الحساب"}
                      ...
                    </>
                  ) : (
                    <>
                      {mode === "login" ? "تسجيل الدخول" : "إنشاء حساب جديد"}
                      <ArrowRight className="w-5 h-5 mr-2" />
                    </>
                  )}
                </Button>
              </form>
            )}
            {/* Switch Mode Link */}
            <div className="text-center pt-4 border-t border-white/20">
              <p className="text-gray-300">
                {mode === "login" ? "ليس لديك حساب؟" : "لديك حساب بالفعل؟"}{" "}
                <button
                  onClick={() => setMode(mode === "login" ? "signup" : "login")}
                  className="text-blue-400 hover:text-blue-300 font-medium transition-colors"
                >
                  {mode === "login" ? "إنشاء حساب جديد" : "تسجيل الدخول"}
                </button>
              </p>
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
