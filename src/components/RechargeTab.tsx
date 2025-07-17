import { useState, useCallback, useMemo } from "react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import {
  Plus,
  CreditCard,
  Building2,
  Copy,
  CheckCircle,
  AlertCircle,
  Info,
  Banknote,
  ArrowLeft,
  DollarSign,
  Shield,
  X,
  Wallet,
  Star,
  Zap,
} from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "./ui/dialog";
import { Label } from "./ui/label";
import { Badge } from "./ui/badge";
import {
  createNotification,
  showBrowserNotification,
  type Notification,
} from "../utils/notifications";

interface RechargeTabProps {
  balance: {
    dzd: number;
    eur: number;
    usd: number;
    gbt: number;
  };
  onRecharge: (amount: number, method: string, rib: string) => void;
  onNotification: (notification: Notification) => void;
}

function RechargeTab({
  balance,
  onRecharge,
  onNotification,
}: RechargeTabProps) {
  const [showRechargeDialog, setShowRechargeDialog] = useState(false);
  const [currentStep, setCurrentStep] = useState(1);
  const [rechargeAmount, setRechargeAmount] = useState("");
  const [senderRib, setSenderRib] = useState("");
  const [amountError, setAmountError] = useState("");
  const [ribError, setRibError] = useState("");

  const validateAmount = () => {
    if (!rechargeAmount || parseFloat(rechargeAmount) <= 0) {
      setAmountError("يرجى إدخال مبلغ صحيح");
      return false;
    }
    if (parseFloat(rechargeAmount) < 1000) {
      setAmountError("الحد الأدنى: 1000 دج");
      return false;
    }
    setAmountError("");
    return true;
  };

  const validateRib = () => {
    if (!senderRib.trim()) {
      setRibError("يرجى إدخال رقم المعاملة");
      return false;
    }
    if (senderRib.length < 6) {
      setRibError("رقم المعاملة غير صحيح");
      return false;
    }
    setRibError("");
    return true;
  };

  const handleAmountSubmit = () => {
    if (validateAmount()) {
      setCurrentStep(2);
    }
  };

  const handlePaymentMethodSelect = () => {
    setCurrentStep(3);
  };

  const handleFinalConfirm = useCallback(() => {
    if (validateRib()) {
      const amount = parseFloat(rechargeAmount);
      onRecharge(amount, "bank", senderRib);

      const notification = createNotification(
        "success",
        "تم إرسال طلب الشحن",
        `سوف نتحقق من المعاملة وإضافة ${amount.toLocaleString()} دج في أقل من 10 دقائق`,
      );
      onNotification(notification);
      showBrowserNotification(
        "تم إرسال طلب الشحن",
        `سوف نتحقق من المعاملة وإضافة ${amount.toLocaleString()} دج في أقل من 10 دقائق`,
      );

      // Reset dialog
      setShowRechargeDialog(false);
      setCurrentStep(1);
      setRechargeAmount("");
      setSenderRib("");
      setAmountError("");
      setRibError("");
    }
  }, [rechargeAmount, senderRib, onRecharge, onNotification, validateRib]);

  const resetDialog = () => {
    setShowRechargeDialog(false);
    setCurrentStep(1);
    setRechargeAmount("");
    setSenderRib("");
    setAmountError("");
    setRibError("");
  };

  const goToPreviousStep = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1);
    }
  };

  const renderStepContent = () => {
    switch (currentStep) {
      case 1:
        return (
          <div className="space-y-6">
            <div className="text-center">
              <div className="w-16 h-16 bg-green-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <DollarSign className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-bold text-white mb-2">أدخل المبلغ</h3>
              <p className="text-gray-300 text-sm">المبلغ بالدينار الجزائري</p>
            </div>
            <div className="space-y-4">
              <Input
                type="number"
                placeholder="أدخل المبلغ (الحد الأدنى: 1000 دج)"
                value={rechargeAmount}
                onChange={(e) => {
                  setRechargeAmount(e.target.value);
                  if (amountError) setAmountError("");
                }}
                className={`text-center text-lg bg-white/10 border-white/30 text-white placeholder:text-gray-400 h-12 ${
                  amountError ? "border-red-400" : "focus:border-green-400"
                }`}
              />
              {amountError && (
                <p className="text-red-400 text-sm text-center">
                  {amountError}
                </p>
              )}
            </div>
            <Button
              onClick={handleAmountSubmit}
              disabled={!rechargeAmount || parseFloat(rechargeAmount) < 1000}
              className="w-full h-12 bg-green-500 hover:bg-green-600 text-white font-bold"
            >
              التالي
            </Button>
          </div>
        );

      case 2:
        return (
          <div className="space-y-6">
            <div className="text-center">
              <div className="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <CreditCard className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-bold text-white mb-2">
                إرسال المبلغ
              </h3>
            </div>
            <Card className="bg-blue-500/20 border border-blue-400/30">
              <CardContent className="p-4">
                <div className="flex items-center space-x-3 space-x-reverse mb-3">
                  <div className="w-8 h-8 bg-green-500 rounded flex items-center justify-center">
                    <span className="text-white text-sm font-bold">B</span>
                  </div>
                  <div>
                    <p className="text-green-200 text-sm font-medium">
                      بريد الجزائر - BaridiMob
                    </p>
                  </div>
                </div>
                <p className="text-white text-sm mb-3">
                  أرسل المبلغ من بريدي موب إلى الحساب التالي:
                </p>

                <div className="space-y-3 mb-4">
                  <div className="bg-white/10 border border-white/20 rounded-lg p-3">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-gray-300 text-xs mb-1">
                          رقم الحساب البنكي (RIB)
                        </p>
                        <p className="text-white font-mono text-sm">
                          0079999900272354667
                        </p>
                      </div>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                          navigator.clipboard.writeText("0079999900272354667");
                          const notification = createNotification(
                            "success",
                            "تم النسخ",
                            "تم نسخ رقم الحساب البنكي",
                          );
                          onNotification(notification);
                        }}
                        className="text-blue-300 hover:text-blue-200 hover:bg-white/10 p-1"
                      >
                        <Copy className="w-4 h-4" />
                      </Button>
                    </div>
                  </div>

                  <div className="bg-white/10 border border-white/20 rounded-lg p-3">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-gray-300 text-xs mb-1">
                          اسم المستفيد
                        </p>
                        <p className="text-white text-sm">
                          NETLIFY DIGITAL SERVICES
                        </p>
                      </div>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                          navigator.clipboard.writeText(
                            "NETLIFY DIGITAL SERVICES",
                          );
                          const notification = createNotification(
                            "success",
                            "تم النسخ",
                            "تم نسخ اسم المستفيد",
                          );
                          onNotification(notification);
                        }}
                        className="text-blue-300 hover:text-blue-200 hover:bg-white/10 p-1"
                      >
                        <Copy className="w-4 h-4" />
                      </Button>
                    </div>
                  </div>
                </div>

                <div className="flex items-center space-x-2 space-x-reverse text-yellow-300 text-xs mb-3">
                  <AlertCircle className="w-4 h-4" />
                  <span>انقر على أيقونة النسخ لنسخ البيانات</span>
                </div>

                <div className="bg-orange-500/20 border border-orange-400/30 rounded-lg p-3">
                  <p className="text-orange-200 text-sm font-medium">
                    المبلغ: {parseFloat(rechargeAmount).toLocaleString()} دج
                  </p>
                </div>

                <div className="bg-blue-500/20 border border-blue-400/30 rounded-lg p-3 mt-3">
                  <div className="flex items-center space-x-2 space-x-reverse text-blue-200 text-xs">
                    <Info className="w-4 h-4" />
                    <span>
                      بعد إرسال المبلغ عبر بريدي موب، اضغط على "التالي" وأدخل
                      رقم المعاملة للتأكيد
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
            <div className="flex gap-3">
              <Button
                onClick={goToPreviousStep}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
              >
                <ArrowLeft className="w-4 h-4 ml-2" />
                السابق
              </Button>
              <Button
                onClick={handlePaymentMethodSelect}
                className="flex-1 h-12 bg-green-500 hover:bg-green-600 text-white font-bold"
              >
                التالي
              </Button>
            </div>
          </div>
        );

      case 3:
        return (
          <div className="space-y-6">
            <div className="text-center">
              <div className="w-16 h-16 bg-purple-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <Shield className="w-8 h-8 text-white" />
              </div>
              <h3 className="text-xl font-bold text-white mb-2">
                تأكيد المعاملة
              </h3>
              <p className="text-gray-300 text-sm">
                أدخل رقم المعاملة من بريدي موب
              </p>
            </div>
            <div className="space-y-4">
              <Input
                type="text"
                placeholder="أدخل رقم المعاملة من بريدي موب"
                value={senderRib}
                onChange={(e) => {
                  setSenderRib(e.target.value);
                  if (ribError) setRibError("");
                }}
                className={`text-center bg-white/10 border-white/30 text-white placeholder:text-gray-400 h-12 ${
                  ribError ? "border-red-400" : "focus:border-green-400"
                }`}
              />
              {ribError && (
                <p className="text-red-400 text-sm text-center">{ribError}</p>
              )}

              <div className="bg-orange-500/20 border border-orange-400/30 rounded-lg p-3">
                <p className="text-orange-200 text-sm font-medium text-center">
                  المبلغ: {parseFloat(rechargeAmount).toLocaleString()} دج
                </p>
              </div>

              <div className="bg-gradient-to-r from-green-500/20 to-emerald-500/20 border border-green-400/30 rounded-lg p-4">
                <div className="flex items-center space-x-2 space-x-reverse text-green-200 text-sm mb-2">
                  <CheckCircle className="w-5 h-5 text-green-400" />
                  <span className="font-medium">
                    سوف نتحقق من المعاملة في أقل من 10 دقائق
                  </span>
                </div>
                <p className="text-green-300 text-xs mr-7">
                  سيتم إضافة المبلغ إلى محفظتك فور التحقق من صحة المعاملة
                </p>
              </div>
            </div>
            <div className="flex gap-3">
              <Button
                onClick={goToPreviousStep}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
              >
                السابق
              </Button>
              <Button
                onClick={handleFinalConfirm}
                disabled={!senderRib.trim()}
                className="flex-1 h-12 bg-green-500 hover:bg-green-600 text-white font-bold"
              >
                تأكيد الشحن
              </Button>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <div className="space-y-6 sm:space-y-8 pb-20 bg-transparent px-2 sm:px-0 max-w-6xl mx-auto">
      {/* Enhanced Page Header - Investment Style */}
      <div className="text-center mb-8">
        <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4 bg-gradient-to-r from-white via-emerald-100 to-white bg-clip-text text-transparent">
          شحن المحفظة
        </h1>
        <p className="text-gray-300 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed">
          ة الشحن المناسبة لك مع أفضل الخدمات المصرفية
        </p>
        <div className="flex items-center justify-center space-x-6 space-x-reverse mt-6">
          <div className="flex items-center space-x-2 space-x-reverse text-green-400">
            <Shield className="w-5 h-5" />
            <span className="text-sm font-medium">آمن ومحمي</span>
          </div>
          <div className="flex items-center space-x-2 space-x-reverse text-emerald-400">
            <Zap className="w-5 h-5" />
            <span className="text-sm font-medium">معاملات فورية</span>
          </div>
          <div className="flex items-center space-x-2 space-x-reverse text-teal-400">
            <Star className="w-5 h-5" />
            <span className="text-sm font-medium">متاح 24/7</span>
          </div>
        </div>
      </div>
      {/* Enhanced Balance Display - Matching Home Style */}
      {/* Recharge Options - Investment Style Cards */}
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3 space-x-reverse">
            <div className="p-2 bg-gradient-to-br from-emerald-500 to-teal-600 rounded-full">
              <Star className="w-6 h-6 text-white" />
            </div>
            <div>
              <h3 className="text-white font-bold text-2xl">
                خيارات الشحن المتاحة
              </h3>
              <p className="text-gray-300 text-sm">
                اختر طريقة الشحن التي تناسب احتياجاتك
              </p>
            </div>
          </div>
        </div>

        {/* Quick Recharge Card */}
        <Card className="bg-gradient-to-br from-emerald-500/20 to-teal-600/20 backdrop-blur-md border border-white/30 hover:bg-white/15 transition-all duration-300 shadow-xl hover:shadow-2xl transform hover:scale-105">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center space-x-3 space-x-reverse">
                <div className="w-12 h-12 bg-gradient-to-r from-emerald-500 to-teal-600 rounded-full flex items-center justify-center shadow-lg">
                  <Plus className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h3 className="text-white font-bold text-base">شحن فوري</h3>
                  <p className="text-gray-300 text-sm">
                    شحن سريع وآمن عبر بريدي موب
                  </p>
                </div>
              </div>
            </div>

            <div className="space-y-3 mb-4">
              <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                <span className="text-gray-300 text-sm font-medium">
                  السرعة
                </span>
                <span className="text-green-400 font-bold text-sm">
                  أقل من 10 دقائق
                </span>
              </div>
              <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                <span className="text-gray-300 text-sm font-medium">
                  الأمان
                </span>
                <span className="text-blue-400 font-bold text-sm">
                  100% آمن
                </span>
              </div>
              <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                <span className="text-gray-300 text-sm font-medium">
                  الحد الأدنى
                </span>
                <span className="text-yellow-400 font-bold text-sm">
                  1,000 دج
                </span>
              </div>
            </div>

            <Button
              onClick={() => setShowRechargeDialog(true)}
              className="w-full bg-gradient-to-r from-emerald-500 to-teal-600 hover:opacity-90 h-12 text-sm font-bold transition-all duration-300 transform hover:scale-105 shadow-xl hover:shadow-2xl border-0 rounded-xl relative overflow-hidden group"
            >
              <div className="absolute inset-0 bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
              <span className="relative z-10 flex items-center justify-center gap-2">
                <Plus className="w-4 h-4" />
                شحن المحفظة الآن
                <DollarSign className="w-4 h-4" />
              </span>
            </Button>
          </CardContent>
        </Card>

        {/* Quick Stats - Investment Style */}
        <Card className="bg-gradient-to-br from-blue-500/20 to-indigo-600/20 backdrop-blur-md border border-blue-400/30"></Card>
      </div>
      {/* Recharge Dialog */}
      <Dialog open={showRechargeDialog} onOpenChange={resetDialog}>
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-purple-900/95 to-slate-900/95 backdrop-blur-md border border-white/20 text-white max-w-md mx-auto">
          <DialogHeader className="text-center relative">
            <Button
              onClick={resetDialog}
              variant="ghost"
              size="sm"
              className="absolute left-0 top-0 text-white/60 hover:text-white hover:bg-white/10 p-1"
            >
              <X className="w-5 h-5" />
            </Button>
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <Banknote className="w-6 h-6 text-green-400" />
              شحن المحفظة
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              الخطوة {currentStep} من 3
            </DialogDescription>
          </DialogHeader>
          <div className="mt-6">{renderStepContent()}</div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default RechargeTab;
