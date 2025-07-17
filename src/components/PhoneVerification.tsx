import { useState, useEffect } from "react";
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
  Phone,
  CheckCircle,
  AlertCircle,
  Clock,
  RefreshCw,
} from "lucide-react";
import {
  createOTP,
  verifyOTP,
  sendOTPSMS,
  getOTPStatus,
  completePhoneVerification,
} from "@/lib/supabase";
import { validateAlgerianPhoneNumber } from "@/utils/validation";

interface PhoneVerificationProps {
  phoneNumber?: string;
  userId?: string;
  onVerificationComplete: (verified: boolean, phoneNumber?: string) => void;
  onClose?: () => void;
  otpType?: string;
}

export default function PhoneVerification({
  phoneNumber: initialPhoneNumber = "",
  userId,
  onVerificationComplete,
  onClose,
  otpType = "phone_verification",
}: PhoneVerificationProps) {
  const [phoneNumber, setPhoneNumber] = useState(initialPhoneNumber);
  const [verificationCode, setVerificationCode] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [message, setMessage] = useState("");
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState("");
  const [timeLeft, setTimeLeft] = useState(300); // 5 minutes
  const [canResend, setCanResend] = useState(false);
  const [demoCode, setDemoCode] = useState(""); // For demo purposes
  const [otpId, setOtpId] = useState<string | null>(null);
  const [phoneInputMode, setPhoneInputMode] = useState(!initialPhoneNumber);
  const [attemptsRemaining, setAttemptsRemaining] = useState(5);

  // Countdown timer
  useEffect(() => {
    if (timeLeft > 0) {
      const timer = setTimeout(() => setTimeLeft(timeLeft - 1), 1000);
      return () => clearTimeout(timer);
    } else {
      setCanResend(true);
    }
  }, [timeLeft]);

  // Send initial verification code if phone number is provided
  useEffect(() => {
    if (initialPhoneNumber && !phoneInputMode) {
      sendVerificationCode();
    }
  }, [initialPhoneNumber, phoneInputMode]);

  // Check OTP status on mount
  useEffect(() => {
    if (phoneNumber && !phoneInputMode) {
      checkOTPStatus();
    }
  }, [phoneNumber, phoneInputMode]);

  const checkOTPStatus = async () => {
    if (!phoneNumber) return;

    try {
      const { data, error } = await getOTPStatus(phoneNumber, otpType);

      if (error) {
        console.warn("فشل في جلب حالة OTP:", error);
        return;
      }

      if (data?.hasActiveOTP) {
        setMessage("يوجد رمز تحقق نشط بالفعل");
        setCanResend(!data.canResend);

        if (data.expiresAt) {
          const expiresAt = new Date(data.expiresAt);
          const now = new Date();
          const timeLeftSeconds = Math.max(
            0,
            Math.floor((expiresAt.getTime() - now.getTime()) / 1000),
          );
          setTimeLeft(timeLeftSeconds);
        }

        setAttemptsRemaining(5 - (data.attemptsUsed || 0));
      }
    } catch (err) {
      console.warn("خطأ في فحص حالة OTP:", err);
    }
  };

  const sendVerificationCode = async () => {
    if (!phoneNumber) {
      setError("يرجى إدخال رقم الهاتف");
      return;
    }

    // Validate phone number
    const phoneValidation = validateAlgerianPhoneNumber(phoneNumber);
    if (!phoneValidation.isValid) {
      setError(phoneValidation.error || "رقم الهاتف غير صحيح");
      return;
    }

    setIsSending(true);
    setError("");
    setMessage("");

    try {
      // Create OTP in database
      const otpResult = await createOTP(
        phoneValidation.value,
        userId,
        otpType,
        5,
      );

      if (!otpResult.data) {
        setError(otpResult.error?.message || "فشل في إنشاء رمز التحقق");
        return;
      }

      setOtpId(otpResult.data.otpId);
      setDemoCode(otpResult.data.otpCode || ""); // For demo - remove in production

      // Send SMS (mock implementation)
      const smsResult = await sendOTPSMS(
        phoneValidation.value,
        otpResult.data.otpCode || "",
        otpType,
      );

      if (smsResult.success) {
        setMessage("تم إرسال رمز التحقق إلى هاتفك");
        setPhoneNumber(phoneValidation.value); // Update with validated phone number
        setTimeLeft(300); // Reset timer
        setCanResend(false);
        setAttemptsRemaining(5);

        if (phoneInputMode) {
          setPhoneInputMode(false);
        }
      } else {
        setError(smsResult.message || "فشل في إرسال رمز التحقق");
      }
    } catch (err: any) {
      console.error("خطأ في إرسال رمز التحقق:", err);
      setError("حدث خطأ في إرسال رمز التحقق");
    } finally {
      setIsSending(false);
    }
  };

  const handleVerifyCode = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!verificationCode.trim() || verificationCode.length !== 6) {
      setError("يرجى إدخال رمز التحقق المكون من 6 أرقام");
      return;
    }

    if (!phoneNumber) {
      setError("رقم الهاتف مطلوب");
      return;
    }

    setIsLoading(true);
    setError("");
    setMessage("");

    try {
      const result = await completePhoneVerification(
        phoneNumber,
        verificationCode.trim(),
        userId,
      );

      if (result.data) {
        setSuccess(true);
        setMessage("تم تأكيد رقم الهاتف بنجاح!");
        setTimeout(() => {
          onVerificationComplete(true, phoneNumber);
        }, 2000);
      } else {
        const errorMessage = result.error?.message || "رمز التحقق غير صحيح";
        setError(errorMessage);

        // Decrement attempts remaining
        if (attemptsRemaining > 1) {
          setAttemptsRemaining(attemptsRemaining - 1);
        } else {
          setError("تم تجاوز عدد المحاولات المسموح. يرجى طلب رمز جديد");
          setCanResend(true);
        }
      }
    } catch (err: any) {
      console.error("خطأ في التحقق من الرمز:", err);
      setError("حدث خطأ في التحقق من الرمز");
    } finally {
      setIsLoading(false);
    }
  };

  const handlePhoneSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await sendVerificationCode();
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <Card className="w-full max-w-md bg-white/10 backdrop-blur-md border border-white/20 shadow-2xl">
        <CardHeader className="text-center">
          <div className="w-16 h-16 bg-blue-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
            <Phone className="w-8 h-8 text-blue-400" />
          </div>
          <CardTitle className="text-xl font-bold text-white">
            تأكيد رقم الهاتف
          </CardTitle>
          <CardDescription className="text-gray-300">
            تم إرسال رمز التحقق إلى
            <br />
            <span className="font-mono text-white">{phoneNumber}</span>
          </CardDescription>
        </CardHeader>

        <CardContent className="space-y-6">
          {/* Phone Number Input Mode */}
          {phoneInputMode && (
            <form onSubmit={handlePhoneSubmit} className="space-y-4">
              <div className="space-y-2">
                <label className="text-sm font-medium text-white block text-right">
                  رقم الهاتف
                </label>
                <Input
                  type="tel"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(e.target.value)}
                  className="h-12 text-right bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-blue-400 focus:ring-blue-400"
                  placeholder="+213555123456"
                  required
                  dir="ltr"
                />
                <p className="text-gray-400 text-xs text-right">
                  أدخل رقم هاتفك الجزائري (يبدأ بـ 5 أو 6 أو 7)
                </p>
              </div>

              <Button
                type="submit"
                className="w-full h-12 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white font-medium transition-all duration-300 shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed"
                disabled={isSending || !phoneNumber.trim()}
              >
                {isSending ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></div>
                    جاري الإرسال...
                  </>
                ) : (
                  "إرسال رمز التحقق"
                )}
              </Button>
            </form>
          )}

          {/* Demo Code Display - Remove in production */}
          {!phoneInputMode && demoCode && (
            <div className="bg-yellow-500/20 border border-yellow-500/30 rounded-lg p-3 text-center">
              <p className="text-yellow-300 text-sm mb-1">
                رمز التحقق التجريبي:
              </p>
              <p className="text-yellow-100 font-mono text-lg font-bold">
                {demoCode}
              </p>
              <p className="text-yellow-300 text-xs mt-1">
                (هذا للعرض التوضيحي فقط - سيتم إزالته في الإنتاج)
              </p>
            </div>
          )}

          {/* Success/Error Messages */}
          {(message || error) && (
            <div
              className={`p-3 rounded-lg flex items-center gap-2 text-sm ${
                success
                  ? "bg-green-500/20 border border-green-500/30 text-green-300"
                  : error
                    ? "bg-red-500/20 border border-red-500/30 text-red-300"
                    : "bg-blue-500/20 border border-blue-500/30 text-blue-300"
              }`}
            >
              {success ? (
                <CheckCircle className="w-4 h-4 flex-shrink-0" />
              ) : error ? (
                <AlertCircle className="w-4 h-4 flex-shrink-0" />
              ) : (
                <Phone className="w-4 h-4 flex-shrink-0" />
              )}
              <span>{message || error}</span>
            </div>
          )}

          {/* Verification Form */}
          {!success && !phoneInputMode && (
            <form onSubmit={handleVerifyCode} className="space-y-4">
              <div className="space-y-2">
                <label className="text-sm font-medium text-white block text-right">
                  رمز التحقق
                </label>
                <Input
                  type="text"
                  value={verificationCode}
                  onChange={(e) => {
                    const value = e.target.value.replace(/[^0-9]/g, "");
                    if (value.length <= 6) {
                      setVerificationCode(value);
                    }
                  }}
                  className="h-12 text-center text-2xl font-mono bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-blue-400 focus:ring-blue-400"
                  placeholder="000000"
                  maxLength={6}
                  required
                />
                <p className="text-gray-400 text-xs text-center">
                  أدخل الرمز المكون من 6 أرقام (المحاولات المتبقية:{" "}
                  {attemptsRemaining})
                </p>
              </div>

              <Button
                type="submit"
                className="w-full h-12 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white font-medium transition-all duration-300 shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed"
                disabled={isLoading || verificationCode.length !== 6}
              >
                {isLoading ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></div>
                    جاري التحقق...
                  </>
                ) : (
                  "تأكيد الرمز"
                )}
              </Button>
            </form>
          )}

          {/* Timer and Resend */}
          {!success && !phoneInputMode && (
            <div className="text-center space-y-3">
              {!canResend ? (
                <div className="flex items-center justify-center gap-2 text-gray-400 text-sm">
                  <Clock className="w-4 h-4" />
                  <span>إعادة الإرسال خلال {formatTime(timeLeft)}</span>
                </div>
              ) : (
                <Button
                  variant="outline"
                  onClick={sendVerificationCode}
                  disabled={isSending}
                  className="bg-white/10 border-white/30 text-white hover:bg-white/20"
                >
                  {isSending ? (
                    <>
                      <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                      جاري الإرسال...
                    </>
                  ) : (
                    <>
                      <RefreshCw className="w-4 h-4 mr-2" />
                      إعادة إرسال الرمز
                    </>
                  )}
                </Button>
              )}
            </div>
          )}

          {/* Close Button */}
          {onClose && (
            <div className="text-center pt-4 border-t border-white/20">
              <Button
                variant="ghost"
                onClick={onClose}
                className="text-gray-400 hover:text-white"
              >
                إلغاء
              </Button>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
