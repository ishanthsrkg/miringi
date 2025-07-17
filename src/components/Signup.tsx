import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  ArrowRight,
  Wallet,
  Shield,
  AlertCircle,
  Loader2,
  Eye,
  EyeOff,
  Users,
  Gift,
} from "lucide-react";
import { useAuth } from "../hooks/useAuth";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface SignupProps {
  onSignup?: () => void;
}

export default function Signup({ onSignup }: SignupProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [signupMethod, setSignupMethod] = useState<"google" | "email">(
    "google",
  );
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [referralCode, setReferralCode] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const { loginWithGoogle, register, loading, error, user } = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();

  // Load referral code from URL parameters
  useEffect(() => {
    const refCode = searchParams.get("ref");
    if (refCode) {
      setReferralCode(refCode);
      console.log("🎯 تم تحميل كود الإحالة من الرابط:", refCode);
    }
  }, [searchParams]);

  // Redirect if already logged in
  useEffect(() => {
    if (user && !loading) {
      console.log(
        "🔄 المستخدم مسجل دخول بالفعل، إعادة توجيه إلى الصفحة الرئيسية",
      );
      navigate("/home", { replace: true });
    }
  }, [user, loading, navigate]);

  const handleGoogleSignUp = async () => {
    // Prevent double submission
    if (isSubmitting || loading) {
      console.log("🚫 منع الإرسال المتكرر - العملية قيد التنفيذ");
      return;
    }

    setIsSubmitting(true);

    try {
      console.log("🔐 بدء عملية إنشاء الحساب بجوجل...");
      const { data, error: signupError } = await loginWithGoogle();

      if (signupError) {
        console.error("❌ خطأ في إنشاء الحساب بجوجل:", signupError);
        setIsSubmitting(false);
        return;
      }

      if (data) {
        console.log("✅ تم إنشاء الحساب بجوجل بنجاح");

        if (onSignup) {
          onSignup();
        }

        // Navigation will be handled by the auth state change
        console.log("🏠 سيتم إعادة التوجيه تلقائياً بعد إنشاء الحساب");
      }
    } catch (err) {
      console.error("💥 خطأ غير متوقع في إنشاء الحساب بجوجل:", err);
      setIsSubmitting(false);
    }
  };

  const handleEmailSignUp = async (e: React.FormEvent) => {
    e.preventDefault();

    // Prevent double submission
    if (isSubmitting || loading) {
      console.log("🚫 منع الإرسال المتكرر - العملية قيد التنفيذ");
      return;
    }

    // Validate passwords match
    if (password !== confirmPassword) {
      console.error("❌ كلمات المرور غير متطابقة");
      return;
    }

    setIsSubmitting(true);

    try {
      console.log("🔐 بدء عملية إنشاء الحساب بالبريد الإلكتروني...");
      const { data, error: signupError } = await register(email, password, {
        fullName,
        phone,
        referralCode: referralCode || null,
      });

      if (signupError) {
        console.error("❌ خطأ في إنشاء الحساب:", signupError);
        setIsSubmitting(false);
        return;
      }

      if (data) {
        console.log("✅ تم إنشاء الحساب بنجاح");

        if (onSignup) {
          onSignup();
        }

        // Navigation will be handled by the auth state change
        console.log("🏠 سيتم إعادة التوجيه تلقائياً بعد إنشاء الحساب");
      }
    } catch (err) {
      console.error("💥 خطأ غير متوقع في إنشاء الحساب:", err);
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen w-full bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 relative overflow-hidden">
      {/* Enhanced Background Elements - Investment Style */}
      <div className="absolute inset-0">
        <div className="absolute top-0 left-1/4 w-64 h-64 bg-blue-400/20 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-pulse"></div>
        <div className="absolute top-1/3 right-1/4 w-64 h-64 bg-purple-400/20 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-pulse animation-delay-2000"></div>
        <div className="absolute bottom-0 left-1/2 w-64 h-64 bg-indigo-400/20 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-pulse animation-delay-4000"></div>
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
          {/* Enhanced Header - Investment Style */}
          <div className="text-center mb-8">
            <div className="flex items-center justify-center mb-6">
              <img
                alt="Netlify Logo"
                src="/logo.png"
                className="w-16 h-16 sm:w-20 sm:h-20 object-contain drop-shadow-2xl"
              />
            </div>
            <h1 className="text-3xl sm:text-4xl font-bold text-white mb-4 bg-gradient-to-r from-white via-indigo-100 to-white bg-clip-text text-transparent">
              Netlify
            </h1>
            <p className="text-gray-300 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed">
              البنك الرقمي الأول في الجزائر - انضم إلينا اليوم
            </p>
            <div className="flex items-center justify-center space-x-6 space-x-reverse mt-6">
              <div className="flex items-center space-x-2 space-x-reverse text-green-400">
                <Shield className="w-5 h-5" />
                <span className="text-sm font-medium">أمان عالي</span>
              </div>
              <div className="flex items-center space-x-2 space-x-reverse text-blue-400">
                <Users className="w-5 h-5" />
                <span className="text-sm font-medium">مجتمع كبير</span>
              </div>
              <div className="flex items-center space-x-2 space-x-reverse text-purple-400">
                <Gift className="w-5 h-5" />
                <span className="text-sm font-medium">مكافآت حصرية</span>
              </div>
            </div>
          </div>

          {/* Enhanced Signup Form - Investment Style */}
          <Card className="bg-gradient-to-br from-slate-800/40 to-blue-900/40 backdrop-blur-md border border-blue-400/20 shadow-xl">
            <CardHeader className="text-center pb-6">
              <CardTitle className="text-2xl font-bold text-white mb-2">
                إنشاء حساب جديد
              </CardTitle>
              <CardDescription className="text-gray-300">
                انضم إلينا اليوم
              </CardDescription>

              {/* Simple Signup Method Selector */}
              <div className="flex items-center justify-center mt-6">
                <div className="bg-white/5 rounded-xl p-1 border border-white/20">
                  <button
                    onClick={() => setSignupMethod("google")}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                      signupMethod === "google"
                        ? "bg-white text-gray-900"
                        : "text-white hover:bg-white/10"
                    }`}
                  >
                    تسجيل سريع
                  </button>
                  <button
                    onClick={() => setSignupMethod("email")}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                      signupMethod === "email"
                        ? "bg-white text-gray-900"
                        : "text-white hover:bg-white/10"
                    }`}
                  >
                    بريد إلكتروني
                  </button>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-6">
              {error && (
                <Alert className="bg-red-500/20 border-red-500/50 text-red-200">
                  <AlertCircle className="h-4 w-4" />
                  <AlertDescription className="text-right">
                    {error}
                  </AlertDescription>
                </Alert>
              )}

              {signupMethod === "google" ? (
                <div className="space-y-4">
                  {/* Referral Code Section - Moved Above Google Button */}
                  {referralCode && (
                    <div className="space-y-3">
                      <div className="bg-gradient-to-br from-green-500/20 to-emerald-600/20 backdrop-blur-md border border-green-400/30 rounded-lg p-4 text-center shadow-xl">
                        <div className="flex items-center justify-center gap-2 mb-3">
                          <div className="p-2 bg-green-500/30 rounded-full">
                            <Gift className="w-5 h-5 text-green-400" />
                          </div>
                          <span className="text-green-400 font-bold">
                            مكافأة الإحالة متاحة
                          </span>
                        </div>
                        <p className="text-green-300 text-sm mb-4">
                          ستحصل على مكافأة ترحيبية عند إكمال التسجيل!
                        </p>
                        <div className="bg-green-500/10 rounded-lg p-3 mb-4 border border-green-400/20">
                          <p className="text-green-300 text-xs mb-1">
                            كود الإحالة
                          </p>
                          <p className="text-white font-bold text-lg">
                            {referralCode}
                          </p>
                        </div>
                        <Button
                          type="button"
                          onClick={() => {
                            const shareText = `انضم إلى نتليفاي واستخدم كود الإحالة ${referralCode} للحصول على مكافأة ترحيبية! ${window.location.origin}/signup?ref=${referralCode}`;
                            if (navigator.share) {
                              navigator.share({
                                title: "انضم إلى نتليفاي",
                                text: shareText,
                                url: `${window.location.origin}/signup?ref=${referralCode}`,
                              });
                            } else {
                              navigator.clipboard?.writeText(shareText);
                            }
                          }}
                          className="w-full bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 h-10 text-sm font-bold transition-all duration-300 transform hover:scale-105 shadow-lg"
                          disabled={loading || isSubmitting}
                        >
                          <Users className="w-4 h-4 ml-2" />
                          مشاركة رابط الإحالة
                        </Button>
                      </div>
                    </div>
                  )}

                  {/* Hidden Referral Code Input for URL parameter handling */}
                  <input
                    type="hidden"
                    value={referralCode}
                    onChange={(e) => setReferralCode(e.target.value)}
                  />

                  <Button
                    onClick={handleGoogleSignUp}
                    className="w-full h-12 bg-white hover:bg-gray-50 text-gray-900 font-medium flex items-center justify-center gap-3 transition-all duration-200 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed rounded-lg transform hover:scale-105"
                    disabled={loading || isSubmitting}
                  >
                    {loading || isSubmitting ? (
                      <>
                        <Loader2 className="w-5 h-5 animate-spin" />
                        <span>جاري إنشاء الحساب...</span>
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
                        <span>إنشاء حساب بجوجل</span>
                      </>
                    )}
                  </Button>
                </div>
              ) : (
                <form onSubmit={handleEmailSignUp} className="space-y-4">
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
                      className="w-full h-12 bg-white/10 border-white/20 text-white placeholder-gray-400 rounded-lg focus:border-blue-400 text-right"
                      placeholder="أدخل اسمك الكامل"
                      required
                      disabled={loading || isSubmitting}
                    />
                  </div>

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
                      className="w-full h-12 bg-white/10 border-white/20 text-white placeholder-gray-400 rounded-lg focus:border-blue-400 text-right"
                      placeholder="أدخل بريدك الإلكتروني"
                      required
                      disabled={loading || isSubmitting}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label
                      htmlFor="phone"
                      className="text-white text-right block"
                    >
                      رقم الهاتف
                    </Label>
                    <Input
                      id="phone"
                      type="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      className="w-full h-12 bg-white/10 border-white/20 text-white placeholder-gray-400 rounded-lg focus:border-blue-400 text-right"
                      placeholder="أدخل رقم هاتفك"
                      disabled={loading || isSubmitting}
                    />
                  </div>

                  {/* Referral Code Section - Enhanced Style */}
                  {referralCode && (
                    <div className="space-y-3">
                      <div className="bg-gradient-to-br from-green-500/20 to-emerald-600/20 backdrop-blur-md border border-green-400/30 rounded-lg p-4 text-center shadow-xl">
                        <div className="flex items-center justify-center gap-2 mb-3">
                          <div className="p-2 bg-green-500/30 rounded-full">
                            <Gift className="w-5 h-5 text-green-400" />
                          </div>
                          <span className="text-green-400 font-bold">
                            مكافأة الإحالة متاحة
                          </span>
                        </div>
                        <p className="text-green-300 text-sm mb-4">
                          ستحصل على مكافأة ترحيبية عند إكمال التسجيل!
                        </p>
                        <div className="bg-green-500/10 rounded-lg p-3 mb-4 border border-green-400/20">
                          <p className="text-green-300 text-xs mb-1">
                            كود الإحالة
                          </p>
                          <p className="text-white font-bold text-lg">
                            {referralCode}
                          </p>
                        </div>
                        <Button
                          type="button"
                          onClick={() => {
                            const shareText = `انضم إلى نتليفاي واستخدم كود الإحالة ${referralCode} للحصول على مكافأة ترحيبية! ${window.location.origin}/signup?ref=${referralCode}`;
                            if (navigator.share) {
                              navigator.share({
                                title: "انضم إلى نتليفاي",
                                text: shareText,
                                url: `${window.location.origin}/signup?ref=${referralCode}`,
                              });
                            } else {
                              navigator.clipboard?.writeText(shareText);
                            }
                          }}
                          className="w-full bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 h-10 text-sm font-bold transition-all duration-300 transform hover:scale-105 shadow-lg"
                          disabled={loading || isSubmitting}
                        >
                          <Users className="w-4 h-4 ml-2" />
                          مشاركة رابط الإحالة
                        </Button>
                      </div>
                    </div>
                  )}

                  {/* Hidden Referral Code Input for URL parameter handling */}
                  <input
                    type="hidden"
                    value={referralCode}
                    onChange={(e) => setReferralCode(e.target.value)}
                  />

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
                        className="w-full h-12 bg-white/10 border-white/20 text-white placeholder-gray-400 rounded-lg focus:border-blue-400 text-right pr-12"
                        placeholder="أدخل كلمة المرور"
                        required
                        disabled={loading || isSubmitting}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-white"
                      >
                        {showPassword ? (
                          <EyeOff className="w-5 h-5" />
                        ) : (
                          <Eye className="w-5 h-5" />
                        )}
                      </button>
                    </div>
                  </div>

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
                        className="w-full h-12 bg-white/10 border-white/20 text-white placeholder-gray-400 rounded-lg focus:border-blue-400 text-right pr-12"
                        placeholder="أعد إدخال كلمة المرور"
                        required
                        disabled={loading || isSubmitting}
                      />
                      <button
                        type="button"
                        onClick={() =>
                          setShowConfirmPassword(!showConfirmPassword)
                        }
                        className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-white"
                      >
                        {showConfirmPassword ? (
                          <EyeOff className="w-5 h-5" />
                        ) : (
                          <Eye className="w-5 h-5" />
                        )}
                      </button>
                    </div>
                  </div>

                  {password !== confirmPassword && confirmPassword && (
                    <p className="text-red-400 text-sm text-right">
                      كلمات المرور غير متطابقة
                    </p>
                  )}

                  <Button
                    type="submit"
                    className="w-full h-12 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white font-medium transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed rounded-lg"
                    disabled={
                      loading || isSubmitting || password !== confirmPassword
                    }
                  >
                    {loading || isSubmitting ? (
                      <>
                        <Loader2 className="w-5 h-5 animate-spin mr-2" />
                        جاري إنشاء الحساب...
                      </>
                    ) : (
                      "إنشاء حساب جديد"
                    )}
                  </Button>
                </form>
              )}

              <div className="text-center pt-4 border-t border-white/20">
                <p className="text-gray-300">
                  لديك حساب بالفعل؟{" "}
                  <a
                    href="/login"
                    className="text-blue-400 hover:text-blue-300 font-medium"
                  >
                    تسجيل الدخول
                  </a>
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
