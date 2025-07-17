import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import {
  ArrowLeftRight,
  Send,
  Plus,
  Zap,
  Building2,
  Wallet,
  Star,
  Shield,
  Clock,
  TrendingUp,
  Sparkles,
  ArrowRight,
  Download,
  Upload,
  ArrowLeft,
  DollarSign,
  CreditCard,
  CheckCircle,
  AlertTriangle,
  AlertCircle,
  Eye,
  Calculator,
} from "lucide-react";
import { Separator } from "./ui/separator";
import InstantTransferTab from "./InstantTransferTab";
import RechargeTab from "./RechargeTab";
import { createNotification, type Notification } from "../utils/notifications";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "./ui/dialog";

interface TransfersTabProps {
  balance: {
    dzd: number;
    eur: number;
    usd: number;
    gbt: number;
    gbp?: number;
  };
  onTransfer?: (amount: number, recipientEmail: string) => void;
  onRecharge?: (amount: number, method: string, rib: string) => void;
  onNotification?: (notification: Notification) => void;
}

function TransfersTab({
  balance = { dzd: 0, eur: 0, usd: 0, gbt: 0, gbp: 0 },
  onTransfer,
  onRecharge,
  onNotification,
}: TransfersTabProps) {
  const [activeTransferType, setActiveTransferType] = useState<
    "main" | "internal" | "external" | "recharge" | "withdraw"
  >("main");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [withdrawRib, setWithdrawRib] = useState("");
  const [showWithdrawSuccess, setShowWithdrawSuccess] = useState(false);
  const [withdrawError, setWithdrawError] = useState("");

  const handleNotification = (notification: Notification) => {
    if (onNotification) {
      onNotification(notification);
    }
  };

  const handleTransfer = (amount: number, recipientEmail: string) => {
    if (onTransfer) {
      onTransfer(amount, recipientEmail);
    }
    // Show success notification
    const notification = createNotification(
      "success",
      "تم التحويل بنجاح",
      `تم إرسال ${amount.toLocaleString()} دج بنجاح`,
    );
    handleNotification(notification);
  };

  const handleRecharge = (amount: number, method: string, rib: string) => {
    if (onRecharge) {
      onRecharge(amount, method, rib);
    }
  };

  const handleWithdraw = () => {
    const amount = parseFloat(withdrawAmount);

    if (!withdrawAmount || amount <= 0) {
      setWithdrawError("يرجى إدخال مبلغ صحيح");
      return;
    }

    if (amount < 1000) {
      setWithdrawError("الحد الأدنى للسحب هو 1000 دج");
      return;
    }

    if (amount > balance.dzd) {
      setWithdrawError("الرصيد غير كافي");
      return;
    }

    if (!withdrawRib.trim()) {
      setWithdrawError("يرجى إدخال رقم الحساب البنكي (RIB)");
      return;
    }

    if (withdrawRib.length < 16) {
      setWithdrawError("رقم الحساب البنكي غير صحيح");
      return;
    }

    setWithdrawError("");
    setShowWithdrawSuccess(true);

    const notification = createNotification(
      "success",
      "تم إرسال طلب السحب",
      `سيتم تحويل ${amount.toLocaleString()} دج إلى حسابك خلال 24 ساعة`,
    );
    handleNotification(notification);

    // Reset form after 3 seconds
    setTimeout(() => {
      setShowWithdrawSuccess(false);
      setWithdrawAmount("");
      setWithdrawRib("");
      setActiveTransferType("main");
    }, 3000);
  };

  // Main transfer selection screen
  if (activeTransferType === "main") {
    return (
      <div className="w-full max-w-sm sm:max-w-md mx-auto space-y-6 pb-20">
        {/* Enhanced Page Header - Investment Style */}
        {/* Enhanced Balance Display - Investment Style */}
        <div className="bg-gradient-to-br from-indigo-500/20 to-purple-600/20 backdrop-blur-md border border-indigo-400/30 shadow-xl rounded-xl sm:rounded-2xl p-6 sm:p-8 mb-6 sm:mb-8">
          <div className="flex items-center justify-center mb-4">
            <div className="text-right">
              <Button
                variant="ghost"
                size="sm"
                className="text-indigo-300 hover:text-white hover:bg-white/20 p-2 rounded-xl transition-all duration-300"
              >
                <Eye className="w-5 h-5" />
              </Button>
            </div>
          </div>

          <div className="text-center mb-6">
            <p className="text-4xl sm:text-5xl font-bold text-white mb-2 bg-gradient-to-r from-white via-indigo-100 to-white bg-clip-text text-transparent">
              {balance.dzd.toLocaleString()}
            </p>
            <p className="text-indigo-300 text-lg">دينار جزائري</p>
          </div>

          <div className="space-y-4">
            <Separator className="bg-white/20" />
            <div className="flex justify-between items-center py-3">
              <div className="text-center">
                <p className="text-white font-bold text-lg mb-1">
                  €{balance.eur || 0}
                </p>
                <p className="text-indigo-300 text-xs">يورو</p>
              </div>
              <Separator orientation="vertical" className="bg-white/20 h-8" />
              <div className="text-center">
                <p className="text-white font-bold text-lg mb-1">
                  ${balance.usd || 0}
                </p>
                <p className="text-green-300 text-xs">دولار أمريكي</p>
              </div>
              <Separator orientation="vertical" className="bg-white/20 h-8" />
              <div className="text-center">
                <p className="text-white font-bold text-lg mb-1">
                  £{balance.gbp?.toFixed(2) || "0.00"}
                </p>
                <p className="text-purple-300 text-xs">جنيه إسترليني</p>
              </div>
            </div>
            <Separator className="bg-white/20" />
          </div>
        </div>
        {/* Quick Actions - Different Colors */}
        <div className="grid grid-cols-2 gap-6">
          {/* Internal Transfer - Blue Theme */}
          <Card
            className="bg-gradient-to-br from-blue-500/20 to-indigo-600/20 backdrop-blur-md border border-blue-400/30 shadow-xl cursor-pointer hover:border-blue-400/50 transition-all duration-300 group h-32 rounded-xl overflow-hidden"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              setActiveTransferType("internal");
            }}
          >
            <CardContent className="p-6 h-full flex flex-col justify-center items-center text-center relative z-10">
              <div className="mb-4">
                <div className="p-3 bg-blue-500/30 rounded-full">
                  <Zap className="w-6 h-6 text-blue-400" />
                </div>
              </div>
              <div>
                <p className="text-white font-bold text-base mb-1">
                  معاملات داخلية
                </p>
                <p className="text-blue-300 text-sm">تحويل فوري</p>
              </div>
            </CardContent>
          </Card>

          {/* External Transfer - Cyan Theme */}
          <Card
            className="bg-gradient-to-br from-cyan-500/20 to-teal-600/20 backdrop-blur-md border border-cyan-400/30 shadow-xl cursor-pointer hover:border-cyan-400/50 transition-all duration-300 group h-32 rounded-xl overflow-hidden"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              setActiveTransferType("external");
            }}
          >
            <CardContent className="p-6 h-full flex flex-col justify-center items-center text-center relative z-10">
              <div className="mb-4">
                <div className="p-3 bg-cyan-500/30 rounded-full">
                  <Building2 className="w-6 h-6 text-cyan-400" />
                </div>
              </div>
              <div>
                <p className="text-white font-bold text-base mb-1">
                  معاملات خارجية
                </p>
                <p className="text-cyan-300 text-sm">شحن وسحب</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Recent Transfers - Matching Home Page Style */}
        <div className="space-y-6">
          <div className="text-center mb-6">
            <div className="flex items-center justify-center space-x-3 space-x-reverse mb-2">
              <div className="p-3 bg-cyan-500/30 rounded-full">
                <ArrowLeftRight className="w-6 h-6 text-cyan-400" />
              </div>
            </div>
            <div>
              <h3 className="text-xl font-bold text-white">
                التحويلات الأخيرة
              </h3>
              <p className="text-cyan-300 text-sm">آخر العمليات المالية</p>
            </div>
          </div>

          <Card className="bg-gradient-to-br from-cyan-500/20 to-blue-600/20 backdrop-blur-md border border-cyan-400/30 shadow-xl rounded-xl">
            <CardContent className="p-6">
              <div className="text-center py-8">
                <div className="p-3 bg-cyan-500/30 rounded-full mx-auto mb-4 w-fit">
                  <ArrowLeftRight className="w-6 h-6 text-cyan-400" />
                </div>
                <p className="text-white font-bold text-base mb-2">
                  لا توجد تحويلات حتى الآن
                </p>
                <p className="text-cyan-300 text-sm">
                  ستظهر تحويلاتك هنا بمجرد البدء
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
        {/* Quick Stats - Investment Style */}
      </div>
    );
  }

  // Internal Transfer (Instant Transfer)
  if (activeTransferType === "internal") {
    return (
      <div className="w-full max-w-sm sm:max-w-md mx-auto space-y-6 pb-20">
        {/* Back Button */}
        <Button
          onClick={() => setActiveTransferType("main")}
          variant="ghost"
          className="text-white hover:bg-white/10 mb-4"
        >
          <ArrowLeft className="w-4 h-4 ml-2" />
          العودة للتحويلات
        </Button>
        <InstantTransferTab balance={balance} onTransfer={handleTransfer} />
      </div>
    );
  }

  // External Transfer Selection
  if (activeTransferType === "external") {
    return (
      <div className="w-full max-w-sm sm:max-w-md mx-auto space-y-6 pb-20">
        {/* Back Button */}
        <Button
          onClick={() => setActiveTransferType("main")}
          variant="ghost"
          className="text-white hover:bg-white/10 mb-4"
        >
          <ArrowLeft className="w-4 h-4 ml-2" />
          العودة للتحويلات
        </Button>
        {/* Enhanced Page Header - Investment Style */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center p-4 bg-gradient-to-br from-blue-500/20 to-cyan-600/20 rounded-full backdrop-blur-sm mb-6"></div>
          <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4 bg-gradient-to-r from-white via-blue-100 to-white bg-clip-text text-transparent">
            المعاملات الخارجية
          </h1>
          <p className="text-gray-300 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed">
            اختر العملية المطلوبة مع أفضل الخدمات المصرفية الخارجية
          </p>
        </div>
        {/* External Transfer Options - Investment Style Cards */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Recharge Option */}
          <Card
            className="bg-gradient-to-br from-emerald-500/20 to-green-600/20 backdrop-blur-md border border-white/30 hover:bg-white/15 transition-all duration-300 shadow-xl hover:shadow-2xl transform hover:scale-105 cursor-pointer"
            onClick={() => setActiveTransferType("recharge")}
          >
            <CardContent className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center space-x-3 space-x-reverse">
                  <div className="w-12 h-12 bg-gradient-to-r from-emerald-500 to-green-600 rounded-full flex items-center justify-center shadow-lg">
                    <Download className="w-6 h-6 text-white" />
                  </div>
                  <div>
                    <h3 className="text-white font-bold text-base">
                      شحن المحفظة
                    </h3>
                    <p className="text-gray-300 text-sm">
                      إضافة أموال من بريدي موب
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
                    خلال 10 دقائق
                  </span>
                </div>
                <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                  <span className="text-gray-300 text-sm font-medium">
                    الأمان
                  </span>
                  <span className="text-blue-400 font-bold text-sm">
                    آمن ومضمون
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

              <Button className="w-full bg-gradient-to-r from-emerald-500 to-green-600 hover:opacity-90 h-12 text-sm font-bold transition-all duration-300 transform hover:scale-105 shadow-xl hover:shadow-2xl border-0 rounded-xl relative overflow-hidden group">
                <div className="absolute inset-0 bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                <span className="relative z-10 flex items-center justify-center gap-2">
                  <Download className="w-4 h-4" />
                  شحن المحفظة
                </span>
              </Button>
            </CardContent>
          </Card>

          {/* Withdraw Option */}
          <Card
            className="bg-gradient-to-br from-orange-500/20 to-red-600/20 backdrop-blur-md border border-white/30 hover:bg-white/15 transition-all duration-300 shadow-xl hover:shadow-2xl transform hover:scale-105 cursor-pointer"
            onClick={() => setActiveTransferType("withdraw")}
          >
            <CardContent className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center space-x-3 space-x-reverse">
                  <div className="w-12 h-12 bg-gradient-to-r from-orange-500 to-red-600 rounded-full flex items-center justify-center shadow-lg">
                    <Upload className="w-6 h-6 text-white" />
                  </div>
                  <div>
                    <h3 className="text-white font-bold text-base">
                      سحب الأموال
                    </h3>
                    <p className="text-gray-300 text-sm">تحويل إلى بريدي موب</p>
                  </div>
                </div>
              </div>

              <div className="space-y-3 mb-4">
                <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                  <span className="text-gray-300 text-sm font-medium">
                    السرعة
                  </span>
                  <span className="text-green-400 font-bold text-sm">
                    خلال 24 ساعة
                  </span>
                </div>
                <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                  <span className="text-gray-300 text-sm font-medium">
                    الأمان
                  </span>
                  <span className="text-blue-400 font-bold text-sm">
                    آمن ومضمون
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

              <Button className="w-full bg-gradient-to-r from-orange-500 to-red-600 hover:opacity-90 h-12 text-sm font-bold transition-all duration-300 transform hover:scale-105 shadow-xl hover:shadow-2xl border-0 rounded-xl relative overflow-hidden group">
                <div className="absolute inset-0 bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                <span className="relative z-10 flex items-center justify-center gap-2">
                  <Upload className="w-4 h-4" />
                  سحب الأموال
                </span>
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  // Recharge Page
  if (activeTransferType === "recharge") {
    return (
      <div className="w-full max-w-sm sm:max-w-md mx-auto space-y-6 pb-20">
        {/* Back Button */}
        <Button
          onClick={() => setActiveTransferType("external")}
          variant="ghost"
          className="text-white hover:bg-white/10 mb-4"
        >
          <ArrowLeft className="w-4 h-4 ml-2" />
          العودة للمعاملات الخارجية
        </Button>
        <RechargeTab
          balance={balance}
          onRecharge={handleRecharge}
          onNotification={handleNotification}
        />
      </div>
    );
  }

  // Withdraw Page
  if (activeTransferType === "withdraw") {
    return (
      <div className="w-full max-w-sm sm:max-w-md mx-auto space-y-6 pb-20">
        {/* Back Button */}
        <Button
          onClick={() => setActiveTransferType("external")}
          variant="ghost"
          className="text-white hover:bg-white/10 mb-4"
        >
          <ArrowLeft className="w-4 h-4 ml-2" />
          العودة للمعاملات الخارجية
        </Button>
        {/* Enhanced Page Header - Investment Style */}
        <div className="text-center mb-8">
          <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4 bg-gradient-to-r from-white via-orange-100 to-white bg-clip-text text-transparent">
            سحب الأموال
          </h1>
          <p className="text-gray-300 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed">
            تحويل الأموال إلى حسابك البنكي بسهولة وأمان
          </p>
          <div className="flex items-center justify-center space-x-6 space-x-reverse mt-6">
            <div className="flex items-center space-x-2 space-x-reverse text-orange-400">
              <Clock className="w-5 h-5" />
              <span className="text-sm font-medium">خلال 24 ساعة</span>
            </div>
            <div className="flex items-center space-x-2 space-x-reverse text-red-400">
              <Shield className="w-5 h-5" />
              <span className="text-sm font-medium">آمن ومضمون</span>
            </div>
          </div>
        </div>
        {/* Enhanced Balance Display - Investment Style */}
        {/* Withdraw Form */}
        <Card className="bg-gradient-to-br from-red-500/20 via-orange-500/20 to-pink-600/20 backdrop-blur-md shadow-2xl border border-red-400/30 text-white relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-r from-red-400/5 via-orange-400/5 to-pink-400/5 animate-pulse"></div>
          <CardHeader className="relative z-10">
            <CardTitle className="text-white text-2xl flex items-center justify-center gap-3">
              <div className="w-12 h-12 bg-gradient-to-r from-red-500 to-orange-600 rounded-2xl flex items-center justify-center shadow-lg">
                <Upload className="w-6 h-6 text-white" />
              </div>
              <div className="text-center">
                <h3 className="text-xl font-bold">بيانات السحب</h3>
                <p className="text-sm text-red-200 font-normal">
                  املأ البيانات أدناه لسحب الأموال
                </p>
              </div>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-8 pt-6 relative z-10">
            {/* Amount */}
            <div className="space-y-4">
              <label className="block text-white text-base font-semibold mb-3 flex items-center gap-3">
                <div className="w-8 h-8 bg-red-500/20 rounded-xl flex items-center justify-center">
                  <DollarSign className="w-4 h-4 text-red-400" />
                </div>
                <div>
                  <span className="block">المبلغ المراد سحبه</span>
                  <span className="text-sm text-red-200 font-normal">
                    بالدينار الجزائري
                  </span>
                </div>
              </label>
              <div className="relative">
                <div className="absolute inset-0 bg-gradient-to-r from-red-500/10 to-orange-500/10 rounded-xl blur-sm"></div>
                <Input
                  type="number"
                  placeholder="0"
                  value={withdrawAmount}
                  onChange={(e) => {
                    setWithdrawAmount(e.target.value);
                    if (withdrawError) setWithdrawError("");
                  }}
                  min="1000"
                  max={balance.dzd}
                  step="1"
                  className="relative bg-white/15 border-2 border-white/20 text-white placeholder:text-gray-300 focus:border-red-400 focus:ring-2 focus:ring-red-400/50 h-16 text-center text-3xl font-bold rounded-xl backdrop-blur-sm"
                />
                <div className="absolute left-4 top-1/2 transform -translate-y-1/2 text-red-400 font-bold text-xl">
                  دج
                </div>
              </div>
              <div className="bg-white/5 rounded-xl p-4 border border-white/10">
                <div className="flex justify-between text-sm text-gray-300 mb-2">
                  <span className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-red-400 rounded-full"></div>
                    الحد الأدنى: 1,000 دج
                  </span>
                  <span className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-orange-400 rounded-full"></div>
                    الحد الأقصى: {balance.dzd.toLocaleString()} دج
                  </span>
                </div>
              </div>
            </div>

            {/* RIB */}
            <div className="space-y-3">
              <label className="block text-white text-base font-semibold mb-3 flex items-center gap-3">
                <div className="w-8 h-8 bg-red-500/20 rounded-xl flex items-center justify-center">
                  <CreditCard className="w-4 h-4 text-red-400" />
                </div>
                <div>
                  <span className="block">رقم الحساب البنكي (RIB)</span>
                  <span className="text-sm text-red-200 font-normal">
                    حساب بريدي موب
                  </span>
                </div>
              </label>
              <div className="relative">
                <div className="absolute inset-0 bg-gradient-to-r from-red-500/10 to-orange-500/10 rounded-xl blur-sm"></div>
                <Input
                  type="text"
                  placeholder="0079999900272354667"
                  value={withdrawRib}
                  onChange={(e) => {
                    setWithdrawRib(e.target.value);
                    if (withdrawError) setWithdrawError("");
                  }}
                  className="relative bg-white/15 border-2 border-white/20 text-white placeholder:text-gray-300 focus:border-red-400 focus:ring-2 focus:ring-red-400/50 h-14 text-base font-medium rounded-xl backdrop-blur-sm"
                />
              </div>
            </div>

            {/* Error Message */}
            {withdrawError && (
              <div className="bg-red-500/20 border border-red-400/30 rounded-lg p-4">
                <div className="flex items-center gap-2">
                  <AlertTriangle className="w-5 h-5 text-red-400" />
                  <p className="text-red-200 text-sm">{withdrawError}</p>
                </div>
              </div>
            )}

            {/* Submit Button */}
            <div className="pt-4">
              <Button
                onClick={handleWithdraw}
                disabled={
                  !withdrawAmount ||
                  !withdrawRib ||
                  parseFloat(withdrawAmount || "0") < 1000 ||
                  parseFloat(withdrawAmount || "0") > balance.dzd
                }
                className="w-full h-16 bg-gradient-to-r from-red-500 via-orange-600 to-pink-600 hover:from-red-600 hover:via-orange-700 hover:to-pink-700 text-white font-bold text-xl disabled:opacity-50 disabled:cursor-not-allowed shadow-2xl transform hover:scale-105 transition-all duration-300 rounded-2xl"
              >
                <div className="flex items-center justify-center gap-3">
                  <Upload className="w-6 h-6" />
                  <span>تأكيد السحب</span>
                  <ArrowRight className="w-5 h-5" />
                </div>
              </Button>
              <p className="text-center text-xs text-gray-400 mt-3">
                سيتم تحويل المبلغ خلال 24 ساعة عمل
              </p>
            </div>
          </CardContent>
        </Card>
        {/* Success Dialog */}
        <Dialog
          open={showWithdrawSuccess}
          onOpenChange={setShowWithdrawSuccess}
        >
          <DialogContent className="bg-gradient-to-br from-slate-900/95 via-green-900/95 to-emerald-900/95 backdrop-blur-md border border-green-400/30 text-white max-w-md mx-auto">
            <DialogHeader className="text-center">
              <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
                <CheckCircle className="w-6 h-6 text-green-400" />
                تم إرسال طلب السحب
              </DialogTitle>
              <DialogDescription className="text-green-200">
                سيتم معالجة طلبك خلال 24 ساعة عمل
              </DialogDescription>
            </DialogHeader>
            <div className="bg-green-500/20 border border-green-400/30 rounded-lg p-4 my-4">
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span className="text-green-200">المبلغ:</span>
                  <span className="text-white font-bold">
                    {parseFloat(withdrawAmount || "0").toLocaleString()} دج
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-green-200">إلى الحساب:</span>
                  <span className="text-white font-mono text-sm">
                    {withdrawRib}
                  </span>
                </div>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>
    );
  }

  // Fallback - should never reach here
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 p-4 pb-24">
      <div className="max-w-lg mx-auto space-y-6">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-white mb-4">خطأ في التحميل</h1>
          <p className="text-gray-300">يرجى المحاولة مرة أخرى</p>
        </div>
      </div>
    </div>
  );
}

export default TransfersTab;
