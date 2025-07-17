import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import {
  Zap,
  Send,
  CheckCircle,
  AlertTriangle,
  Search,
  Clock,
  Shield,
  TrendingUp,
  Sparkles,
  Users,
  ArrowRight,
  Timer,
  Star,
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
import { useAuth } from "../hooks/useAuth";
import { useDatabase } from "../hooks/useDatabase";

interface TransferTabProps {
  balance: { dzd: number; eur: number; usd?: number; gbp?: number };
  onTransfer?: (amount: number, recipientEmail: string) => void;
}

function TransferTab({ balance, onTransfer }: TransferTabProps) {
  const { user } = useAuth();
  const { processTransfer, getInstantTransferStats, checkInstantTransferLimits, searchUsers } = useDatabase(
    user?.id || null,
  );

  const [amount, setAmount] = useState("");
  const [recipientIdentifier, setRecipientIdentifier] = useState("");
  const [description, setDescription] = useState("");
  const [isProcessing, setIsProcessing] = useState(false);
  const [transferComplete, setTransferComplete] = useState(false);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [showErrorDialog, setShowErrorDialog] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [transferResult, setTransferResult] = useState<any>(null);
  const [transferStats, setTransferStats] = useState<any>(null);
  const [searchResults, setSearchResults] = useState<any[]>([]);
  const [showSearchResults, setShowSearchResults] = useState(false);
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [quickAmounts] = useState([500, 1000, 2500, 5000, 10000]);

  // Load transfer stats on component mount
  useEffect(() => {
    const loadStats = async () => {
      const { data } = await getInstantTransferStats();
      if (data) {
        setTransferStats(data);
      }
    };
    loadStats();
  }, [getInstantTransferStats]);

  // Search for users as user types
  useEffect(() => {
    const searchTimeout = setTimeout(async () => {
      if (recipientIdentifier.trim().length >= 2 && !selectedUser) {
        const { data } = await searchUsers(recipientIdentifier);
        setSearchResults(data || []);
        setShowSearchResults(true);
      } else if (recipientIdentifier.trim().length < 2) {
        setSearchResults([]);
        setShowSearchResults(false);
        setSelectedUser(null);
      }
    }, 300);

    return () => clearTimeout(searchTimeout);
  }, [recipientIdentifier, searchUsers, selectedUser]);

  const handleTransfer = async () => {
    if (isProcessing) return;

    if (!amount || !recipientIdentifier) {
      setErrorMessage("يرجى إدخال جميع البيانات المطلوبة");
      setShowErrorDialog(true);
      return;
    }

    const transferAmount = parseFloat(amount);

    if (transferAmount <= 0) {
      setErrorMessage("يرجى إدخال مبلغ صحيح");
      setShowErrorDialog(true);
      return;
    }

    if (transferAmount > balance.dzd) {
      setErrorMessage("الرصيد غير كافي لإجراء هذا التحويل");
      setShowErrorDialog(true);
      return;
    }

    if (transferAmount < 100) {
      setErrorMessage("الحد الأدنى للتحويل هو 100 دج");
      setShowErrorDialog(true);
      return;
    }

    // Check instant transfer limits
    const { data: limitsCheck } = await checkInstantTransferLimits(transferAmount);
    if (limitsCheck && !limitsCheck.can_transfer) {
      setErrorMessage(limitsCheck.error_message);
      setShowErrorDialog(true);
      return;
    }

    setShowConfirmDialog(true);
  };

  const confirmTransfer = async () => {
    if (isProcessing) return;

    setShowConfirmDialog(false);
    setIsProcessing(true);

    try {
      const transferAmount = parseFloat(amount);

      const result = await processTransfer(
        transferAmount,
        recipientIdentifier.trim(),
        description?.trim() || undefined,
      );

      if (result?.error) {
        setErrorMessage(result.error.message || "حدث خطأ غير متوقع أثناء التحويل");
        setShowErrorDialog(true);
        return;
      }

      if (!result?.data) {
        setErrorMessage("لم يتم إرجاع بيانات التحويل");
        setShowErrorDialog(true);
        return;
      }

      setTransferResult(result.data);
      setTransferComplete(true);
      onTransfer?.(transferAmount, recipientIdentifier.trim());

      // Reset form after 5 seconds
      setTimeout(() => {
        setTransferComplete(false);
        setTransferResult(null);
        setAmount("");
        setRecipientIdentifier("");
        setDescription("");
        setSelectedUser(null);
        setSearchResults([]);
        setShowSearchResults(false);
      }, 5000);
    } catch (error: any) {
      setErrorMessage(error.message || "حدث خطأ غير متوقع أثناء التحويل");
      setShowErrorDialog(true);
    } finally {
      setIsProcessing(false);
    }
  };

  if (transferComplete && transferResult) {
    return (
      <Card className="bg-gradient-to-br from-emerald-500/20 to-green-600/20 backdrop-blur-md shadow-xl border border-emerald-400/30">
        <CardContent className="p-8 text-center">
          <div className="w-20 h-20 bg-gradient-to-r from-emerald-500 to-green-600 rounded-full flex items-center justify-center mx-auto mb-6 shadow-lg animate-pulse">
            <Zap className="w-10 h-10 text-white" />
          </div>
          <h2 className="text-3xl font-bold text-white mb-3">
            تحويل ناجح! ⚡
          </h2>
          <p className="text-emerald-200 mb-6 text-lg">
            تم إرسال {amount} دج بنجاح في {transferResult.processingTime || '< 1'} ثانية
          </p>
          {transferResult.reference && (
            <div className="bg-emerald-500/20 border border-emerald-400/30 rounded-lg p-4 mb-6">
              <p className="text-emerald-200 text-sm mb-2">رقم المرجع:</p>
              <p className="text-white font-mono text-xl font-bold">
                {transferResult.reference}
              </p>
            </div>
          )}
          <div className="grid grid-cols-3 gap-4 text-sm text-emerald-200">
            <div className="flex flex-col items-center">
              <Zap className="w-5 h-5 mb-1" />
              <span>فوري</span>
            </div>
            <div className="flex flex-col items-center">
              <Shield className="w-5 h-5 mb-1" />
              <span>آمن</span>
            </div>
            <div className="flex flex-col items-center">
              <Star className="w-5 h-5 mb-1" />
              <span>مضمون</span>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-6 pb-20 bg-transparent px-2 sm:px-0">
      {/* Header */}
      <div className="text-center mb-8">
        <div className="relative flex items-center justify-center mb-6">
          <div className="w-20 h-20 bg-gradient-to-r from-purple-500 via-pink-600 to-red-600 rounded-3xl flex items-center justify-center shadow-2xl transform hover:scale-110 transition-transform duration-300">
            <Zap className="w-10 h-10 text-white" />
          </div>
          <div className="absolute -top-2 -right-2 w-6 h-6 bg-green-500 rounded-full flex items-center justify-center animate-bounce">
            <Sparkles className="w-3 h-3 text-white" />
          </div>
        </div>
        <h2 className="text-4xl font-bold text-white mb-3 bg-gradient-to-r from-purple-400 via-pink-400 to-red-400 bg-clip-text text-transparent">
          تحويل
        </h2>
        <p className="text-gray-300 text-xl font-medium mb-4">
          أرسل الأموال في ثوانٍ معدودة
        </p>
        <div className="flex items-center justify-center gap-8 text-sm text-gray-400">
          <div className="flex items-center gap-2">
            <Timer className="w-4 h-4 text-purple-400" />
            <span>أقل من ثانيتين</span>
          </div>
          <div className="flex items-center gap-2">
            <Shield className="w-4 h-4 text-green-400" />
            <span>آمن ومشفر</span>
          </div>
          <div className="flex items-center gap-2">
            <Star className="w-4 h-4 text-yellow-400" />
            <span>نجاح 99.9%</span>
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <Card className="bg-gradient-to-br from-blue-500/20 to-cyan-600/20 backdrop-blur-md border border-blue-400/30 hover:scale-105 transition-transform duration-300">
          <CardContent className="p-5 text-center">
            <div className="w-12 h-12 bg-gradient-to-r from-blue-500 to-cyan-600 rounded-2xl flex items-center justify-center mx-auto mb-3 shadow-lg">
              <Timer className="w-6 h-6 text-white" />
            </div>
            <p className="text-blue-200 text-sm mb-2 font-medium">متوسط الوقت</p>
            <p className="text-white font-bold text-xl">< 2 ثانية</p>
          </CardContent>
        </Card>
        <Card className="bg-gradient-to-br from-green-500/20 to-emerald-600/20 backdrop-blur-md border border-green-400/30 hover:scale-105 transition-transform duration-300">
          <CardContent className="p-5 text-center">
            <div className="w-12 h-12 bg-gradient-to-r from-green-500 to-emerald-600 rounded-2xl flex items-center justify-center mx-auto mb-3 shadow-lg">
              <TrendingUp className="w-6 h-6 text-white" />
            </div>
            <p className="text-green-200 text-sm mb-2 font-medium">معدل النجاح</p>
            <p className="text-white font-bold text-xl">99.9%</p>
          </CardContent>
        </Card>
        <Card className="bg-gradient-to-br from-purple-500/20 to-pink-600/20 backdrop-blur-md border border-purple-400/30 hover:scale-105 transition-transform duration-300">
          <CardContent className="p-5 text-center">
            <div className="w-12 h-12 bg-gradient-to-r from-purple-500 to-pink-600 rounded-2xl flex items-center justify-center mx-auto mb-3 shadow-lg">
              <Users className="w-6 h-6 text-white" />
            </div>
            <p className="text-purple-200 text-sm mb-2 font-medium">المرسل إليهم</p>
            <p className="text-white font-bold text-xl">{transferStats?.total_transfers_sent || 0}</p>
          </CardContent>
        </Card>
        <Card className="bg-gradient-to-br from-orange-500/20 to-red-600/20 backdrop-blur-md border border-orange-400/30 hover:scale-105 transition-transform duration-300">
          <CardContent className="p-5 text-center">
            <div className="w-12 h-12 bg-gradient-to-r from-orange-500 to-red-600 rounded-2xl flex items-center justify-center mx-auto mb-3 shadow-lg">
              <Sparkles className="w-6 h-6 text-white" />
            </div>
            <p className="text-orange-200 text-sm mb-2 font-medium">الحد اليومي</p>
            <p className="text-white font-bold text-xl">{transferStats?.daily_remaining?.toLocaleString() || '50,000'} دج</p>
          </CardContent>
        </Card>
      </div>

      {/* Balance Display */}
      <Card className="bg-gradient-to-br from-indigo-600/30 via-purple-600/30 to-pink-600/30 backdrop-blur-md shadow-2xl border border-indigo-400/30 text-white relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-indigo-500/10 via-purple-500/10 to-pink-500/10 animate-pulse"></div>
        <CardContent className="p-6 relative z-10">
          <div className="text-center">
            <div className="w-16 h-16 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-2xl">
              <Zap className="w-8 h-8 text-white" />
            </div>
            <p className="text-indigo-200 text-sm mb-3 font-medium">
              الرصيد المتاح للتحويل
            </p>
            <p className="text-5xl font-bold text-white mb-4">
              {balance.dzd.toLocaleString()} دج
            </p>
            <div className="flex items-center justify-center space-x-6 space-x-reverse text-sm text-gray-300">
              <span className="font-medium">€{balance.eur}</span>
              <span className="text-indigo-400">•</span>
              <span className="font-medium">${balance.usd || 0}</span>
              <span className="text-indigo-400">•</span>
              <span className="font-medium">£{balance.gbp?.toFixed(2) || "0.00"}</span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Quick Amount Buttons */}
      <Card className="bg-gradient-to-br from-gray-800/50 via-slate-800/50 to-gray-900/50 backdrop-blur-md border border-gray-600/30 shadow-xl">
        <CardHeader className="pb-4">
          <CardTitle className="text-white text-xl flex items-center gap-3">
            <div className="w-10 h-10 bg-gradient-to-r from-yellow-500 to-orange-600 rounded-2xl flex items-center justify-center shadow-lg">
              <Sparkles className="w-5 h-5 text-white" />
            </div>
            <div>
              <span className="block">مبالغ سريعة</span>
              <span className="text-sm text-gray-400 font-normal">اختر مبلغاً جاهزاً</span>
            </div>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-5 gap-3">
            {quickAmounts.map((quickAmount) => (
              <Button
                key={quickAmount}
                variant="outline"
                size="sm"
                onClick={() => setAmount(quickAmount.toString())}
                className="bg-gradient-to-r from-white/10 to-white/5 border-2 border-white/20 text-white hover:bg-gradient-to-r hover:from-white/20 hover:to-white/10 hover:border-white/40 text-sm font-semibold h-12 rounded-xl transition-all duration-300 hover:scale-105"
              >
                {quickAmount.toLocaleString()}
              </Button>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Transfer Form */}
      <Card className="bg-gradient-to-br from-emerald-500/20 to-green-600/20 backdrop-blur-md shadow-2xl border border-emerald-400/30 text-white relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-emerald-400/5 to-green-500/5 animate-pulse"></div>
        <CardHeader className="pb-4 relative z-10">
          <CardTitle className="text-white text-xl flex items-center justify-center">
            <div className="w-10 h-10 bg-gradient-to-r from-emerald-400/30 to-green-500/30 rounded-xl flex items-center justify-center mr-3 shadow-lg">
              <Zap className="w-6 h-6 text-emerald-400" />
            </div>
            تفاصيل التحويل
          </CardTitle>
        </CardHeader>
        <CardContent className="pt-0 space-y-6 relative z-10">
          {/* Recipient Input */}
          <div className="space-y-2">
            <label className="block text-white text-sm font-medium mb-2 flex items-center">
              <Search className="w-4 h-4 ml-2 text-emerald-400" />
              البريد الإلكتروني أو رقم الحساب
            </label>
            <div className="relative">
              <Input
                type="text"
                placeholder="example@email.com أو ACC123456789"
                value={recipientIdentifier}
                onChange={(e) => {
                  setRecipientIdentifier(e.target.value);
                  if (selectedUser && e.target.value !== selectedUser.email) {
                    setSelectedUser(null);
                  }
                  if (e.target.value.trim().length < 2) {
                    setShowSearchResults(false);
                  }
                }}
                onFocus={() => {
                  if (searchResults.length > 0 && !selectedUser) {
                    setShowSearchResults(true);
                  }
                }}
                className="bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-emerald-400 focus:ring-emerald-400 h-12 pr-10"
              />
              <Search className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />

              {/* Search Results */}
              {showSearchResults && searchResults.length > 0 && !selectedUser && (
                <div className="absolute top-full left-0 right-0 bg-slate-800/95 backdrop-blur-md border border-emerald-400/30 rounded-lg mt-1 max-h-48 overflow-y-auto z-50">
                  {searchResults.map((user, index) => (
                    <div
                      key={index}
                      className="p-3 hover:bg-emerald-500/20 cursor-pointer border-b border-gray-600/30 last:border-b-0 transition-colors duration-200"
                      onClick={() => {
                        setRecipientIdentifier(user.email);
                        setSelectedUser(user);
                        setShowSearchResults(false);
                      }}
                    >
                      <div className="text-white font-medium">{user.full_name}</div>
                      <div className="text-emerald-400 text-sm">{user.email}</div>
                      <div className="text-gray-400 text-xs">{user.account_number}</div>
                    </div>
                  ))}
                </div>
              )}

              {/* Selected User */}
              {selectedUser && (
                <div className="absolute top-full left-0 right-0 bg-emerald-500/20 backdrop-blur-md border border-emerald-400/50 rounded-lg mt-1 z-50">
                  <div className="p-3 flex items-center justify-between">
                    <div>
                      <div className="text-white font-medium">{selectedUser.full_name}</div>
                      <div className="text-emerald-400 text-sm">{selectedUser.email}</div>
                      <div className="text-gray-300 text-xs">{selectedUser.account_number}</div>
                    </div>
                    <button
                      onClick={() => {
                        setSelectedUser(null);
                        setRecipientIdentifier("");
                      }}
                      className="text-gray-400 hover:text-white transition-colors"
                    >
                      ✕
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Description */}
          <div className="space-y-2">
            <label className="block text-white text-sm font-medium mb-2">
              وصف التحويل (اختياري)
            </label>
            <Input
              type="text"
              placeholder="مثال: دفع فاتورة، هدية، إلخ..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-emerald-400 focus:ring-emerald-400 h-12"
            />
          </div>

          {/* Amount */}
          <div className="space-y-2">
            <label className="block text-white text-sm font-medium mb-2 flex items-center">
              <Zap className="w-4 h-4 ml-2 text-emerald-400" />
              المبلغ (دج)
            </label>
            <div className="relative">
              <Input
                type="number"
                placeholder="أدخل المبلغ"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-emerald-400 focus:ring-emerald-400 h-16 text-center text-2xl font-bold"
              />
              <div className="absolute left-3 top-1/2 transform -translate-y-1/2 text-emerald-400 font-bold text-xl">
                دج
              </div>
            </div>
            <div className="flex justify-between text-xs text-gray-400">
              <span>الحد الأدنى: 100 دج</span>
              <span>الحد الأقصى: {transferStats?.daily_remaining?.toLocaleString() || '50,000'} دج</span>
            </div>
          </div>

          {/* Transfer Button */}
          <Button
            onClick={handleTransfer}
            disabled={!amount || !recipientIdentifier || isProcessing}
            className="w-full h-16 bg-gradient-to-r from-emerald-500 to-green-600 hover:from-emerald-600 hover:to-green-700 text-white font-bold shadow-lg disabled:opacity-50 text-xl transition-all duration-300 hover:scale-105"
          >
            {isProcessing ? (
              <div className="flex items-center justify-center">
                <div className="w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin ml-3"></div>
                جاري المعالجة...
              </div>
            ) : (
              <div className="flex items-center justify-center">
                <Zap className="w-6 h-6 ml-3" />
                تحويل
                <ArrowRight className="w-5 h-5 mr-3" />
              </div>
            )}
          </Button>
        </CardContent>
      </Card>

      {/* Confirmation Dialog */}
      <AlertDialog open={showConfirmDialog} onOpenChange={setShowConfirmDialog}>
        <AlertDialogContent className="bg-gradient-to-br from-slate-900/95 via-emerald-900/95 to-slate-900/95 backdrop-blur-md border border-emerald-400/30 text-white max-w-md mx-auto">
          <AlertDialogHeader className="text-center">
            <AlertDialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <Zap className="w-6 h-6 text-emerald-400" />
              تأكيد التحويل
            </AlertDialogTitle>
            <AlertDialogDescription className="text-gray-300">
              سيتم التحويل في ثوانٍ معدودة
            </AlertDialogDescription>
          </AlertDialogHeader>
          <div className="bg-emerald-500/20 border border-emerald-400/30 rounded-lg p-4 my-4 space-y-3">
            <div className="flex justify-between">
              <span className="text-emerald-200">المبلغ:</span>
              <span className="text-white font-bold">
                {parseFloat(amount || "0").toLocaleString()} دج
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-emerald-200">إلى:</span>
              <span className="text-white font-bold text-sm break-all">
                {recipientIdentifier}
              </span>
            </div>
            {description && (
              <div className="flex justify-between">
                <span className="text-emerald-200">الوصف:</span>
                <span className="text-white text-sm">{description}</span>
              </div>
            )}
            <div className="border-t border-emerald-400/30 pt-2 flex justify-between">
              <span className="text-emerald-200">الرصيد بعد التحويل:</span>
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
              onClick={confirmTransfer}
              className="flex-1 h-12 bg-gradient-to-r from-emerald-500 to-green-600 hover:from-emerald-600 hover:to-green-700 text-white"
            >
              تأكيد التحويل ⚡
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
              خطأ في التحويل
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              لا يمكن إتمام العملية
            </DialogDescription>
          </DialogHeader>
          <div className="bg-red-500/20 border border-red-400/30 rounded-lg p-4 my-4">
            <p className="text-red-200 text-center whitespace-pre-line">
              {errorMessage}
            </p>
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

export default TransferTab;