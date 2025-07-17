import { useState } from "react";
import { useNavigate } from "react-router-dom";
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
  Key,
  Mail,
  ArrowRight,
  AlertCircle,
  CheckCircle,
  Loader2,
} from "lucide-react";
import { useAuth } from "../hooks/useAuth";
import { Alert, AlertDescription } from "@/components/ui/alert";

export default function PasswordResetRequestPage() {
  const [email, setEmail] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState("");
  const [success, setSuccess] = useState(false);
  const navigate = useNavigate();
  const { requestPasswordReset } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!email.trim()) {
      setMessage("يرجى إدخال البريد الإلكتروني");
      setSuccess(false);
      return;
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      setMessage("تنسيق البريد الإلكتروني غير صحيح");
      setSuccess(false);
      return;
    }

    setIsSubmitting(true);
    setMessage("");

    try {
      const { error } = await requestPasswordReset(email.trim());

      if (error) {
        setMessage(
          error.message || "فشل في إرسال رابط إعادة تعيين كلمة المرور",
        );
        setSuccess(false);
      } else {
        setMessage(
          "تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني",
        );
        setSuccess(true);
      }
    } catch (err) {
      setMessage("حدث خطأ في إرسال رابط إعادة تعيين كلمة المرور");
      setSuccess(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleBackToLogin = () => {
    navigate("/login", { replace: true });
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
                  <Key className="w-8 h-8 text-white" />
                </div>
              </div>
              <CardTitle className="text-2xl font-bold text-white mb-2">
                إعادة تعيين كلمة المرور
              </CardTitle>
              <CardDescription className="text-gray-300">
                أدخل بريدك الإلكتروني لإرسال رابط إعادة تعيين كلمة المرور
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
                    {success && (
                      <div className="mt-2 text-sm">
                        تحقق من صندوق الوارد وصندوق الرسائل غير المرغوب فيها
                      </div>
                    )}
                  </AlertDescription>
                </Alert>
              )}

              {/* Form */}
              {!success && (
                <form onSubmit={handleSubmit} className="space-y-4">
                  <div className="space-y-2">
                    <label
                      htmlFor="email"
                      className="text-sm font-medium text-white block text-right"
                    >
                      البريد الإلكتروني
                    </label>
                    <div className="relative">
                      <Input
                        id="email"
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        className="h-12 text-right pr-12 bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-blue-400 focus:ring-blue-400"
                        placeholder="أدخل بريدك الإلكتروني"
                        required
                        disabled={isSubmitting}
                        dir="ltr"
                      />
                      <Mail className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                    </div>
                  </div>

                  <Button
                    type="submit"
                    className="w-full h-12 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white font-medium flex items-center justify-center gap-2 transition-all duration-300 shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed"
                    disabled={isSubmitting || !email.trim()}
                  >
                    {isSubmitting ? (
                      <>
                        <Loader2 className="w-4 h-4 animate-spin" />
                        جاري الإرسال...
                      </>
                    ) : (
                      <>
                        إرسال رابط إعادة التعيين
                        <ArrowRight className="w-4 h-4" />
                      </>
                    )}
                  </Button>
                </form>
              )}

              {/* Success state */}
              {success && (
                <div className="text-center space-y-4">
                  <div className="flex justify-center">
                    <CheckCircle className="w-16 h-16 text-green-400" />
                  </div>
                  <div className="space-y-2">
                    <p className="text-white text-lg font-medium">
                      تم إرسال الرابط بنجاح!
                    </p>
                    <p className="text-gray-300 text-sm">
                      تحقق من بريدك الإلكتروني واتبع التعليمات لإعادة تعيين كلمة
                      المرور
                    </p>
                  </div>

                  <Button
                    onClick={() => {
                      setSuccess(false);
                      setMessage("");
                      setEmail("");
                    }}
                    variant="outline"
                    className="bg-white/10 border-white/30 text-white hover:bg-white/20"
                  >
                    إرسال رابط آخر
                  </Button>
                </div>
              )}

              {/* Back to login */}
              <div className="text-center pt-4 border-t border-white/20">
                <Button
                  onClick={handleBackToLogin}
                  variant="ghost"
                  className="text-blue-400 hover:text-blue-300 hover:bg-white/10"
                >
                  العودة إلى تسجيل الدخول
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
