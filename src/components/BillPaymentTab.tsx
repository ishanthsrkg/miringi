import { useState, useCallback, useMemo } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import {
  Receipt,
  Zap,
  Wifi,
  Phone,
  Car,
  Home,
  CheckCircle,
  AlertCircle,
  AlertTriangle,
  Shield,
  Lock,
  Clock,
} from "lucide-react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "./ui/alert-dialog";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "./ui/dialog";
import { validateAmount } from "../utils/security";
import { formatCurrency } from "../utils/currency";
import {
  createNotification,
  showBrowserNotification,
} from "../utils/notifications";

interface BillPaymentTabProps {
  balance: { dzd: number; eur: number };
  onPayment?: (amount: number, billType: string, reference: string) => void;
  onNotification?: (notification: any) => void;
}

function BillPaymentTab({
  balance,
  onPayment,
  onNotification,
}: BillPaymentTabProps) {
  const [selectedBill, setSelectedBill] = useState("");
  const [reference, setReference] = useState("");
  const [amount, setAmount] = useState("");
  const [isProcessing, setIsProcessing] = useState(false);
  const [paymentComplete, setPaymentComplete] = useState(false);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [showErrorDialog, setShowErrorDialog] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [transactionId, setTransactionId] = useState("");
  const [paymentAttempts, setPaymentAttempts] = useState(0);
  const [lastPaymentTime, setLastPaymentTime] = useState<Date | null>(null);
  const [validationErrors, setValidationErrors] = useState<{
    [key: string]: string;
  }>({});

  const billTypes = [
    {
      id: "electricity",
      name: "فاتورة الكهرباء",
      icon: Zap,
      color: "from-yellow-500 to-orange-600",
      provider: "سونلغاز",
      minAmount: 500,
      maxAmount: 50000,
      referencePattern: /^[0-9]{8,12}$/,
      referenceHint: "8-12 رقم",
    },
    {
      id: "internet",
      name: "فاتورة الإنترنت",
      icon: Wifi,
      color: "from-blue-500 to-cyan-600",
      provider: "اتصالات الجزائر",
      minAmount: 1000,
      maxAmount: 15000,
      referencePattern: /^[0-9]{10}$/,
      referenceHint: "10 أرقام",
    },
    {
      id: "phone",
      name: "فاتورة الهاتف",
      icon: Phone,
      color: "from-green-500 to-emerald-600",
      provider: "موبيليس",
      minAmount: 200,
      maxAmount: 10000,
      referencePattern: /^[0-9]{10}$/,
      referenceHint: "رقم الهاتف (10 أرقام)",
    },
    {
      id: "insurance",
      name: "تأمين السيارة",
      icon: Car,
      color: "from-purple-500 to-indigo-600",
      provider: "SAA",
      minAmount: 5000,
      maxAmount: 100000,
      referencePattern: /^[A-Z0-9]{6,10}$/,
      referenceHint: "رقم البوليصة (6-10 أحرف/أرقام)",
    },
  ];

  const validatePaymentData = () => {
    const errors: { [key: string]: string } = {};
    const selectedBillType = billTypes.find((b) => b.id === selectedBill);

    // Validate bill selection
    if (!selectedBill) {
      errors.bill = "يرجى اختيار نوع الفاتورة";
    }

    // Validate reference
    if (!reference.trim()) {
      errors.reference = "يرجى إدخال رقم المرجع";
    } else if (
      selectedBillType &&
      !selectedBillType.referencePattern.test(reference.trim())
    ) {
      errors.reference = `تنسيق رقم المرجع غير صحيح (${selectedBillType.referenceHint})`;
    }

    // Validate amount
    if (!amount.trim()) {
      errors.amount = "يرجى إدخال المبلغ";
    } else {
      const paymentAmount = parseFloat(amount);

      if (isNaN(paymentAmount) || paymentAmount <= 0) {
        errors.amount = "يرجى إدخال مبلغ صحيح";
      } else if (selectedBillType) {
        if (paymentAmount < selectedBillType.minAmount) {
          errors.amount = `الحد الأدنى للدفع هو ${selectedBillType.minAmount.toLocaleString()} دج`;
        } else if (paymentAmount > selectedBillType.maxAmount) {
          errors.amount = `الحد الأقصى للدفع هو ${selectedBillType.maxAmount.toLocaleString()} دج`;
        } else if (paymentAmount > balance.dzd) {
          errors.amount = "الرصيد غير كافي لدفع هذه الفاتورة";
        }
      }
    }

    return errors;
  };

  const checkRateLimit = () => {
    const now = new Date();
    if (lastPaymentTime && now.getTime() - lastPaymentTime.getTime() < 30000) {
      return "يرجى الانتظار 30 ثانية بين كل عملية دفع";
    }
    if (paymentAttempts >= 3) {
      return "تم تجاوز الحد الأقصى لمحاولات الدفع (3 محاولات)";
    }
    return null;
  };

  const handlePayment = useCallback(() => {
    if (isProcessing) return;

    // Rate limiting check
    const rateLimitError = checkRateLimit();
    if (rateLimitError) {
      setErrorMessage(rateLimitError);
      setShowErrorDialog(true);
      return;
    }

    // Validate all input data
    const errors = validatePaymentData();
    setValidationErrors(errors);

    if (Object.keys(errors).length > 0) {
      setErrorMessage(Object.values(errors)[0]);
      setShowErrorDialog(true);
      return;
    }

    setShowConfirmDialog(true);
  }, [
    isProcessing,
    paymentAttempts,
    lastPaymentTime,
    selectedBill,
    reference,
    amount,
    balance.dzd,
  ]);

  const generateTransactionId = () => {
    const timestamp = Date.now().toString();
    const random = Math.random().toString(36).substr(2, 9);
    return `TXN-${timestamp}-${random}`.toUpperCase();
  };

  const confirmPayment = useCallback(() => {
    if (isProcessing) return;

    setShowConfirmDialog(false);
    setIsProcessing(true);
    setPaymentAttempts((prev) => prev + 1);
    setLastPaymentTime(new Date());

    const txnId = generateTransactionId();
    setTransactionId(txnId);

    // Optimized payment processing with reduced time
    const processingTime = Math.random() * 1000 + 1000; // 1-2 seconds (reduced)
    const successRate = 0.97; // Increased success rate

    const paymentTimeout = setTimeout(() => {
      const isSuccess = Math.random() < successRate;

      if (isSuccess) {
        setIsProcessing(false);
        setPaymentComplete(true);
        onPayment?.(parseFloat(amount), selectedBill, reference);

        // Create success notification
        const notification = {
          id: Date.now().toString(),
          type: "success" as const,
          title: "تم دفع الفاتورة بنجاح",
          message: `تم دفع ${parseFloat(amount).toLocaleString()} دج - رقم المعاملة: ${txnId}`,
          timestamp: new Date(),
          read: false,
        };
        onNotification?.(notification);
        showBrowserNotification(notification.title, notification.message);

        // Reset form after success (reduced time)
        const resetTimeout = setTimeout(() => {
          setPaymentComplete(false);
          setSelectedBill("");
          setReference("");
          setAmount("");
          setValidationErrors({});
          setPaymentAttempts(0);
        }, 3000);

        return () => clearTimeout(resetTimeout);
      } else {
        // Payment failed
        setIsProcessing(false);
        setErrorMessage("فشل في معالجة الدفع. يرجى المحاولة مرة أخرى.");
        setShowErrorDialog(true);

        const notification = {
          id: Date.now().toString(),
          type: "error" as const,
          title: "فشل في دفع الفاتورة",
          message: `فشل في دفع ${parseFloat(amount).toLocaleString()} دج - رقم المعاملة: ${txnId}`,
          timestamp: new Date(),
          read: false,
        };
        onNotification?.(notification);
      }
    }, processingTime);

    return () => clearTimeout(paymentTimeout);
  }, [
    amount,
    selectedBill,
    reference,
    onPayment,
    onNotification,
    isProcessing,
  ]);

  if (paymentComplete) {
    return (
      <div className="space-y-4 sm:space-y-6 pb-20 px-2 sm:px-0">
        <div className="text-center py-12">
          <div className="relative">
            <CheckCircle className="w-20 h-20 text-green-400 mx-auto mb-6 animate-pulse" />
            <div className="absolute -top-2 -right-2 w-6 h-6 bg-green-500 rounded-full flex items-center justify-center">
              <Shield className="w-3 h-3 text-white" />
            </div>
          </div>
          <h2 className="text-2xl font-bold text-white mb-4">
            تم دفع الفاتورة بنجاح!
          </h2>
          <div className="bg-green-500/20 border border-green-400/30 rounded-lg p-4 mb-4 space-y-2">
            <p className="text-green-200">
              المبلغ:{" "}
              <span className="font-bold text-white">
                {parseFloat(amount).toLocaleString()} دج
              </span>
            </p>
            <p className="text-green-200">
              المرجع: <span className="font-bold text-white">{reference}</span>
            </p>
            <p className="text-green-200">
              رقم المعاملة:{" "}
              <span className="font-bold text-white">{transactionId}</span>
            </p>
            <p className="text-green-200 text-sm flex items-center justify-center gap-1">
              <Clock className="w-4 h-4" />
              {new Date().toLocaleString("ar-DZ")}
            </p>
          </div>
          <div className="flex items-center justify-center gap-2 text-green-400 text-sm">
            <Lock className="w-4 h-4" />
            <span>معاملة آمنة ومشفرة</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4 sm:space-y-6 pb-20 px-2 sm:px-0">
      <div className="text-center">
        <h2 className="text-xl sm:text-2xl font-bold text-white mb-2">
          دفع الفواتير
        </h2>
        <p className="text-gray-300 text-sm sm:text-base">
          ادفع فواتيرك بسهولة وأمان
        </p>
      </div>

      {/* Balance Display - Matching Home Style */}
      <div className="bg-gradient-to-br from-blue-600/30 to-purple-700/30 backdrop-blur-xl border border-white/40 shadow-2xl overflow-hidden relative rounded-xl sm:rounded-2xl p-6 sm:p-8 mb-6 sm:mb-8">
        <div className="flex items-center justify-between mb-4">
          <div className="text-center flex-1">
            <h3 className="text-xl sm:text-2xl font-bold text-white leading-tight mb-1 drop-shadow-lg">
              الرصيد المتاح
            </h3>
            <p className="text-blue-200/80 text-sm font-medium">
              متاح لدفع الفواتير
            </p>
          </div>
          <div className="text-right">
            <p className="text-blue-200/80 text-sm">الحالة</p>
            <p className="text-2xl font-bold text-green-400">نشط</p>
          </div>
        </div>

        <div className="text-center mb-4">
          <div className="bg-gradient-to-br from-white/15 to-white/5 backdrop-blur-md rounded-2xl p-4 border border-white/30 shadow-xl">
            <p className="text-3xl sm:text-4xl font-bold text-white mb-2 leading-tight tracking-wide drop-shadow-lg">
              {balance.dzd.toLocaleString()}
            </p>
            <p className="text-blue-200 text-lg leading-tight font-semibold drop-shadow-md">
              دينار جزائري
            </p>
            <div className="mt-2 flex items-center justify-center gap-2">
              <div className="w-1.5 h-1.5 bg-green-400 rounded-full animate-pulse"></div>
              <span className="text-green-300 text-xs font-medium">
                متاح للاستخدام
              </span>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-3">
          <div className="bg-gradient-to-br from-blue-500/20 to-indigo-600/20 rounded-xl p-3 text-center border border-blue-400/40 backdrop-blur-sm">
            <p className="text-white font-bold text-lg mb-1 leading-tight drop-shadow-md">
              €{balance.eur || 0}
            </p>
            <p className="text-blue-200 text-xs leading-tight font-semibold">
              يورو
            </p>
          </div>

          <div className="bg-gradient-to-br from-green-500/20 to-emerald-600/20 rounded-xl p-3 text-center border border-green-400/40 backdrop-blur-sm">
            <p className="text-white font-bold text-lg mb-1 leading-tight drop-shadow-md">
              ${balance.usd || 0}
            </p>
            <p className="text-green-200 text-xs leading-tight font-semibold">
              دولار أمريكي
            </p>
          </div>

          <div className="bg-gradient-to-br from-purple-500/20 to-violet-600/20 rounded-xl p-3 text-center border border-purple-400/40 backdrop-blur-sm">
            <p className="text-white font-bold text-lg mb-1 leading-tight drop-shadow-md">
              £{balance.gbp?.toFixed(2) || "0.00"}
            </p>
            <p className="text-purple-200 text-xs leading-tight font-semibold">
              جنيه إسترليني
            </p>
          </div>
        </div>
      </div>

      {/* Bill Types */}
      <Card className="bg-white/10 backdrop-blur-md shadow-xl border border-white/20 text-white">
        <CardHeader className="pb-3">
          <CardTitle className="text-white text-base sm:text-lg">
            نوع الفاتورة
          </CardTitle>
        </CardHeader>
        <CardContent className="pt-0">
          <div className="grid grid-cols-2 gap-3">
            {billTypes.map((bill) => {
              const Icon = bill.icon;
              return (
                <Button
                  key={bill.id}
                  variant={selectedBill === bill.id ? "default" : "outline"}
                  onClick={() => setSelectedBill(bill.id)}
                  className={`h-16 flex flex-col gap-1 ${
                    selectedBill === bill.id
                      ? `bg-gradient-to-r ${bill.color} text-white`
                      : "bg-white/10 hover:bg-white/20 text-white border-white/20"
                  }`}
                >
                  <Icon className="w-5 h-5" />
                  <span className="text-xs font-medium">{bill.name}</span>
                  <span className="text-xs opacity-75">{bill.provider}</span>
                </Button>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* Payment Form */}
      {selectedBill && (
        <Card className="bg-white/10 backdrop-blur-md shadow-xl border border-white/20 text-white">
          <CardHeader className="pb-3">
            <CardTitle className="text-white text-base sm:text-lg">
              تفاصيل الدفع
            </CardTitle>
          </CardHeader>
          <CardContent className="pt-0 space-y-4">
            <div>
              <label className="block text-white text-sm font-medium mb-2">
                رقم المرجع / رقم العداد
                {billTypes.find((b) => b.id === selectedBill) && (
                  <span className="text-gray-400 text-xs ml-2">
                    (
                    {
                      billTypes.find((b) => b.id === selectedBill)
                        ?.referenceHint
                    }
                    )
                  </span>
                )}
              </label>
              <Input
                type="text"
                placeholder={
                  billTypes.find((b) => b.id === selectedBill)?.referenceHint ||
                  "أدخل رقم المرجع"
                }
                value={reference}
                onChange={(e) => {
                  setReference(e.target.value);
                  if (validationErrors.reference) {
                    setValidationErrors((prev) => ({ ...prev, reference: "" }));
                  }
                }}
                className={`bg-white/10 border-white/20 text-white placeholder:text-gray-400 focus:border-blue-400 ${
                  validationErrors.reference
                    ? "border-red-400 focus:border-red-400"
                    : ""
                }`}
              />
              {validationErrors.reference && (
                <p className="text-red-400 text-xs mt-1">
                  {validationErrors.reference}
                </p>
              )}
            </div>
            <div>
              <label className="block text-white text-sm font-medium mb-2">
                المبلغ (دج)
                {billTypes.find((b) => b.id === selectedBill) && (
                  <span className="text-gray-400 text-xs ml-2">
                    (
                    {billTypes
                      .find((b) => b.id === selectedBill)
                      ?.minAmount.toLocaleString()}{" "}
                    -{" "}
                    {billTypes
                      .find((b) => b.id === selectedBill)
                      ?.maxAmount.toLocaleString()}{" "}
                    دج)
                  </span>
                )}
              </label>
              <Input
                type="number"
                placeholder="0.00"
                value={amount}
                onChange={(e) => {
                  setAmount(e.target.value);
                  if (validationErrors.amount) {
                    setValidationErrors((prev) => ({ ...prev, amount: "" }));
                  }
                }}
                className={`bg-white/10 border-white/20 text-white placeholder:text-gray-400 focus:border-blue-400 ${
                  validationErrors.amount
                    ? "border-red-400 focus:border-red-400"
                    : ""
                }`}
              />
              {validationErrors.amount && (
                <p className="text-red-400 text-xs mt-1">
                  {validationErrors.amount}
                </p>
              )}
            </div>
            {/* Security Notice */}
            <div className="bg-blue-500/20 border border-blue-400/30 rounded-lg p-3 flex items-center gap-2">
              <Shield className="w-4 h-4 text-blue-400 flex-shrink-0" />
              <p className="text-blue-200 text-xs">
                جميع المعاملات مشفرة ومحمية بأعلى معايير الأمان
              </p>
            </div>

            <Button
              onClick={handlePayment}
              disabled={
                !selectedBill ||
                !reference ||
                !amount ||
                isProcessing ||
                paymentAttempts >= 3
              }
              className="w-full h-12 bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700 text-white font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isProcessing ? (
                <div className="flex items-center">
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></div>
                  جاري المعالجة الآمنة...
                </div>
              ) : paymentAttempts >= 3 ? (
                <div className="flex items-center">
                  <AlertTriangle className="w-4 h-4 mr-2" />
                  تم تجاوز الحد الأقصى للمحاولات
                </div>
              ) : (
                <div className="flex items-center">
                  <Receipt className="w-4 h-4 mr-2" />
                  <Lock className="w-4 h-4 mr-1" />
                  دفع الفاتورة بأمان
                </div>
              )}
            </Button>

            {paymentAttempts > 0 && paymentAttempts < 3 && (
              <p className="text-yellow-400 text-xs text-center">
                المحاولات المتبقية: {3 - paymentAttempts}
              </p>
            )}
          </CardContent>
        </Card>
      )}

      {/* Payment Confirmation Dialog */}
      <AlertDialog open={showConfirmDialog} onOpenChange={setShowConfirmDialog}>
        <AlertDialogContent className="bg-gradient-to-br from-slate-900/95 via-green-900/95 to-slate-900/95 backdrop-blur-md border border-green-400/30 text-white max-w-md mx-auto">
          <AlertDialogHeader className="text-center">
            <AlertDialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <Receipt className="w-6 h-6 text-green-400" />
              تأكيد دفع الفاتورة
            </AlertDialogTitle>
            <AlertDialogDescription className="text-gray-300">
              يرجى مراجعة تفاصيل الفاتورة قبل الدفع
            </AlertDialogDescription>
          </AlertDialogHeader>
          <div className="bg-green-500/20 border border-green-400/30 rounded-lg p-4 my-4 space-y-3">
            <div className="flex justify-between">
              <span className="text-green-200">نوع الفاتورة:</span>
              <span className="text-white font-bold">
                {billTypes.find((b) => b.id === selectedBill)?.name}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-green-200">المرجع:</span>
              <span className="text-white font-bold">{reference}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-green-200">المبلغ:</span>
              <span className="text-white font-bold">
                {parseFloat(amount || "0").toLocaleString()} دج
              </span>
            </div>
            <div className="border-t border-green-400/30 pt-2 flex justify-between">
              <span className="text-green-200">الرصيد بعد الدفع:</span>
              <span className="text-green-400 font-bold">
                {(balance.dzd - parseFloat(amount || "0")).toLocaleString()} دج
              </span>
            </div>
          </div>
          <AlertDialogFooter className="flex gap-3">
            <AlertDialogCancel className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60">
              إلغاء
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={confirmPayment}
              className="flex-1 h-12 bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 text-white"
            >
              دفع الفاتورة
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Error Dialog */}
      <Dialog open={showErrorDialog} onOpenChange={setShowErrorDialog}>
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-red-900/95 to-slate-900/95 backdrop-blur-md border border-red-400/30 text-white max-w-md mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <AlertTriangle className="w-6 h-6 text-red-400" />
              خطأ في الدفع
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              لا يمكن إتمام عملية الدفع
            </DialogDescription>
          </DialogHeader>
          <div className="bg-red-500/20 border border-red-400/30 rounded-lg p-4 my-4">
            <p className="text-red-200 text-center">{errorMessage}</p>
          </div>
          <Button
            onClick={() => setShowErrorDialog(false)}
            className="w-full h-12 bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700"
          >
            حسناً
          </Button>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export default BillPaymentTab;
