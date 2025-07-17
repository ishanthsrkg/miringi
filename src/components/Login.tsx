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
  Zap,
  Globe,
  AlertCircle,
  Loader2,
  CreditCard,
  TrendingUp,
  Users,
  Gift,
  Star,
  CheckCircle,
  Sparkles,
  Lock,
  Smartphone,
  Award,
  DollarSign,
  Clock,
  Eye,
  EyeOff,
  Building2,
  Banknote,
  PiggyBank,
  Coins,
  TrendingDown,
  BarChart3,
  Percent,
  Target,
} from "lucide-react";
import { useAuth } from "../hooks/useAuth";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { useNavigate } from "react-router-dom";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface LoginProps {
  onLogin?: () => void;
}

export default function Login({ onLogin }: LoginProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [loginMethod, setLoginMethod] = useState<"google" | "email">("google");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const { loginWithGoogle, login, loading, error, user } = useAuth();
  const navigate = useNavigate();

  // Redirect if already logged in
  useEffect(() => {
    if (user && !loading) {
      console.log(
        "🔄 المستخدم مسجل دخول بالفعل، إعادة توجيه إلى الصفحة الرئيسية",
      );
      navigate("/home", { replace: true });
    }
  }, [user, loading, navigate]);

  const handleGoogleSignIn = async () => {
    // Prevent double submission
    if (isSubmitting || loading) {
      console.log("🚫 منع الإرسال المتكرر - العملية قيد التنفيذ");
      return;
    }

    setIsSubmitting(true);

    try {
      console.log("🔐 بدء عملية تسجيل الدخول بجوجل...");
      const { data, error: loginError } = await loginWithGoogle();

      if (loginError) {
        console.error("❌ خطأ في تسجيل الدخول بجوجل:", loginError);
        setIsSubmitting(false);
        return;
      }

      if (data) {
        console.log("✅ تم تسجيل الدخول بجوجل بنجاح");

        if (onLogin) {
          onLogin();
        }

        // Navigation will be handled by the auth state change
        console.log("🏠 سيتم إعادة التوجيه تلقائياً بعد تسجيل الدخول");
      }
    } catch (err) {
      console.error("💥 خطأ غير متوقع في تسجيل الدخول بجوجل:", err);
      setIsSubmitting(false);
    }
  };

  const handleEmailSignIn = async (e: React.FormEvent) => {
    e.preventDefault();

    // Prevent double submission
    if (isSubmitting || loading) {
      console.log("🚫 منع الإرسال المتكرر - العملية قيد التنفيذ");
      return;
    }

    setIsSubmitting(true);

    try {
      console.log("🔐 بدء عملية تسجيل الدخول بالبريد الإلكتروني...");
      const { data, error: loginError } = await login(email, password);

      if (loginError) {
        console.error("❌ خطأ في تسجيل الدخول:", loginError);
        setIsSubmitting(false);
        return;
      }

      if (data) {
        console.log("✅ تم تسجيل الدخول بنجاح");

        if (onLogin) {
          onLogin();
        }

        // Navigation will be handled by the auth state change
        console.log("🏠 سيتم إعادة التوجيه تلقائياً بعد تسجيل الدخول");
      }
    } catch (err) {
      console.error("💥 خطأ غير متوقع في تسجيل الدخول:", err);
      setIsSubmitting(false);
    }
  };

  const features = [
    {
      icon: Shield,
      title: "أمان عالي",
      description: "حماية متقدمة بتقنية التشفير المصرفي والذكاء الاصطناعي",
      highlight: "آمن 100%",
      color: "from-orange-500 to-red-600",
      stats: "حماية كاملة",
      badge: "تشفير عسكري",
    },
    {
      icon: CreditCard,
      title: "بطاقة مجانية",
      description: "احصل على بطاقة ائتمان مجانية مدى الحياة مع مزايا حصرية",
      highlight: "مجاناً",
      color: "from-emerald-500 to-teal-600",
      stats: "0 رسوم",
      badge: "الأكثر شعبية",
    },
    {
      icon: Zap,
      title: "تحويلات فورية",
      description: "حول الأموال في ثوانٍ معدودة بدون رسوم إضافية",
      highlight: "فوري",
      color: "from-yellow-500 to-orange-600",
      stats: "< 30 ثانية",
      badge: "سرعة البرق",
    },
    {
      icon: TrendingUp,
      title: "استثمار ذكي",
      description: "استثمر أموالك بعوائد تصل إلى 15% سنوياً مع ضمان الأمان",
      highlight: "15%",
      color: "from-blue-500 to-indigo-600",
      stats: "عائد سنوي",
      badge: "عائد مضمون",
    },
    {
      icon: Globe,
      title: "عالمي",
      description: "تحويلات دولية بأفضل الأسعار إلى أكثر من 150 دولة",
      highlight: "عالمي",
      color: "from-cyan-500 to-blue-600",
      stats: "150+ دولة",
      badge: "تغطية شاملة",
    },
    {
      icon: Users,
      title: "نظام الإحالة",
      description: "اربح 500 دج لكل صديق تدعوه للتطبيق + مكافآت إضافية",
      highlight: "500 دج",
      color: "from-purple-500 to-pink-600",
      stats: "لكل إحالة",
      badge: "مكافآت فورية",
    },
    {
      icon: PiggyBank,
      title: "ادخار تلقائي",
      description: "نظام ادخار ذكي يوفر لك المال تلقائياً مع كل معاملة",
      highlight: "ذكي",
      color: "from-green-500 to-emerald-600",
      stats: "توفير تلقائي",
      badge: "AI مدعوم",
    },
    {
      icon: BarChart3,
      title: "تحليلات مالية",
      description: "تقارير مفصلة وتحليلات ذكية لإدارة أموالك بكفاءة",
      highlight: "تحليلات",
      color: "from-indigo-500 to-purple-600",
      stats: "رؤى ذكية",
      badge: "تقارير متقدمة",
    },
  ];

  const benefits = [
    {
      icon: Gift,
      title: "كافأة الترحيب",
      description: "احصل على 100 دج مجاناً عند التسجيل",
      amount: "100 دج",
      color: "from-green-500 to-emerald-600",
    },
    {
      icon: Star,
      title: "خدمة VIP",
      description: "دعم فني متاح 24/7 لجميع العملاء",
      amount: "24/7",
      color: "from-yellow-500 to-orange-600",
    },
    {
      icon: CheckCircle,
      title: "بدون رسوم خفية",
      description: "شفافية كاملة في جميع المعاملات",
      amount: "0%",
      color: "from-blue-500 to-indigo-600",
    },
    {
      icon: Lock,
      title: "أمان متقدم",
      description: "تشفير عسكري وحماية متعددة الطبقات",
      amount: "256-bit",
      color: "from-red-500 to-pink-600",
    },
    {
      icon: Smartphone,
      title: "تطبيق ذكي",
      description: "واجهة سهلة ومميزات متطورة",
      amount: "AI",
      color: "from-purple-500 to-violet-600",
    },
    {
      icon: Award,
      title: "الأفضل محلياً",
      description: "البنك الرقمي الأول في الجزائر",
      amount: "#1",
      color: "from-cyan-500 to-blue-600",
    },
  ];

  return (
    <div className="min-h-screen w-full bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 relative overflow-hidden">
      {/* Enhanced Background Elements - Investment Style */}
      <div className="absolute inset-0">
        <div className="absolute top-0 left-1/4 w-96 h-96 bg-gradient-to-r from-cyan-400/30 to-blue-500/30 rounded-full mix-blend-multiply filter blur-2xl opacity-80 animate-pulse"></div>
        <div className="absolute top-1/3 right-1/4 w-80 h-80 bg-gradient-to-r from-purple-500/30 to-pink-500/30 rounded-full mix-blend-multiply filter blur-2xl opacity-80 animate-pulse animation-delay-2000"></div>
        <div className="absolute bottom-0 left-1/2 w-72 h-72 bg-gradient-to-r from-indigo-500/30 to-purple-600/30 rounded-full mix-blend-multiply filter blur-2xl opacity-80 animate-pulse animation-delay-4000"></div>
        <div className="absolute top-1/2 left-0 w-64 h-64 bg-gradient-to-r from-emerald-400/20 to-teal-500/20 rounded-full mix-blend-multiply filter blur-xl opacity-60 animate-pulse animation-delay-1000"></div>
        <div className="absolute bottom-1/4 right-0 w-56 h-56 bg-gradient-to-r from-rose-400/20 to-orange-500/20 rounded-full mix-blend-multiply filter blur-xl opacity-60 animate-pulse animation-delay-3000"></div>
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
                src="/logo.png"
                alt="Netlify Logo"
                className="w-16 h-16 sm:w-20 sm:h-20 object-contain drop-shadow-2xl"
              />
            </div>
            <h1 className="text-3xl sm:text-4xl font-bold text-white mb-4 bg-gradient-to-r from-white via-indigo-100 to-white bg-clip-text text-transparent">
              Netlify
            </h1>
            <p className="text-gray-300 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed">
              البنك الرقمي الأول في الجزائر - إدارة أموالك بذكاء وأمان
            </p>
            <div className="flex items-center justify-center space-x-6 space-x-reverse mt-6">
              <div className="flex items-center space-x-2 space-x-reverse text-green-400">
                <Shield className="w-5 h-5" />
                <span className="text-sm font-medium">أمان عالي</span>
              </div>
              <div className="flex items-center space-x-2 space-x-reverse text-blue-400">
                <Zap className="w-5 h-5" />
                <span className="text-sm font-medium">سرعة فائقة</span>
              </div>
              <div className="flex items-center space-x-2 space-x-reverse text-purple-400">
                <Globe className="w-5 h-5" />
                <span className="text-sm font-medium">خدمة عالمية</span>
              </div>
            </div>
          </div>

          {/* Enhanced Login Form - Investment Style */}
          <Card className="bg-gradient-to-br from-white/10 via-blue-500/10 to-purple-600/15 backdrop-blur-xl border border-white/20 shadow-2xl hover:shadow-3xl transition-all duration-300">
            <CardHeader className="text-center pb-6">
              <CardTitle className="text-2xl font-bold text-white mb-2">
                مرحباً بك
              </CardTitle>
              <CardDescription className="text-gray-300">
                سجل دخولك للمتابعة
              </CardDescription>

              {/* Simple Login Method Selector */}
              <div className="flex items-center justify-center mt-6">
                <div className="bg-gradient-to-r from-white/10 to-white/5 rounded-xl p-1 border border-white/30 shadow-lg backdrop-blur-sm">
                  <button
                    onClick={() => setLoginMethod("google")}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-300 ${
                      loginMethod === "google"
                        ? "bg-gradient-to-r from-white to-gray-100 text-gray-900 shadow-md"
                        : "text-white hover:bg-gradient-to-r hover:from-white/15 hover:to-white/10"
                    }`}
                  >
                    تسجيل سريع
                  </button>
                  <button
                    onClick={() => setLoginMethod("email")}
                    className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-300 ${
                      loginMethod === "email"
                        ? "bg-gradient-to-r from-white to-gray-100 text-gray-900 shadow-md"
                        : "text-white hover:bg-gradient-to-r hover:from-white/15 hover:to-white/10"
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

              {loginMethod === "google" ? (
                <div className="space-y-4">
                  <Button
                    onClick={handleGoogleSignIn}
                    className="w-full h-12 bg-gradient-to-r from-white to-gray-50 hover:from-gray-50 hover:to-white text-gray-900 font-medium flex items-center justify-center gap-3 transition-all duration-300 shadow-xl hover:shadow-2xl disabled:opacity-50 disabled:cursor-not-allowed rounded-lg transform hover:scale-105"
                    disabled={loading || isSubmitting}
                  >
                    {loading || isSubmitting ? (
                      <>
                        <Loader2 className="w-5 h-5 animate-spin" />
                        <span>جاري تسجيل الدخول...</span>
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
                        <span>تسجيل الدخول بجوجل</span>
                      </>
                    )}
                  </Button>
                </div>
              ) : (
                <form onSubmit={handleEmailSignIn} className="space-y-4">
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

                  <div className="flex items-center justify-between text-sm">
                    <a
                      href="/forgot-password"
                      className="text-blue-400 hover:text-blue-300"
                    >
                      نسيت كلمة المرور؟
                    </a>
                    <div className="flex items-center space-x-2">
                      <input
                        type="checkbox"
                        id="remember"
                        checked={rememberMe}
                        onChange={(e) => setRememberMe(e.target.checked)}
                        className="w-4 h-4 text-blue-600 bg-white/10 border-white/20 rounded"
                      />
                      <Label htmlFor="remember" className="text-white">
                        تذكرني
                      </Label>
                    </div>
                  </div>

                  <Button
                    type="submit"
                    className="w-full h-12 bg-gradient-to-r from-cyan-500 via-blue-600 to-purple-600 hover:from-cyan-600 hover:via-blue-700 hover:to-purple-700 text-white font-medium transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed rounded-lg shadow-xl hover:shadow-2xl transform hover:scale-105"
                    disabled={loading || isSubmitting}
                  >
                    {loading || isSubmitting ? (
                      <>
                        <Loader2 className="w-5 h-5 animate-spin mr-2" />
                        جاري تسجيل الدخول...
                      </>
                    ) : (
                      "تسجيل الدخول"
                    )}
                  </Button>
                </form>
              )}

              <div className="text-center pt-4 border-t border-white/20">
                <p className="text-gray-300">
                  ليس لديك حساب؟{" "}
                  <a
                    href="/signup"
                    className="text-blue-400 hover:text-blue-300 font-medium"
                  >
                    إنشاء حساب جديد
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
