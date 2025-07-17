import { useState, useEffect, useCallback } from "react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "./ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";
import {
  BarChart3,
  TrendingUp,
  Calendar,
  Clock,
  AlertCircle,
  DollarSign,
  Shield,
  Star,
  Percent,
  Wallet,
  PiggyBank,
  LineChart,
  Timer,
  Target,
} from "lucide-react";
import { Separator } from "./ui/separator";
import { validateAmount } from "../utils/security";
import {
  createNotification,
  showBrowserNotification,
  type Notification,
} from "../utils/notifications";
import { useAuth } from "../hooks/useAuth";
import { useDatabase } from "../hooks/useDatabase";

interface InvestmentTabProps {
  balance: { dzd: number; eur: number; usd: number; gbp: number };
  onSavingsDeposit: (amount: number, goalId: string) => Promise<void>;
  onInvestmentReturn: (amount: number) => void;
  onNotification: (notification: Notification) => void;
}

interface Investment {
  id: string;
  type: "weekly" | "monthly";
  amount: number;
  startDate: Date;
  endDate: Date;
  profitRate: number;
  status: "active" | "completed";
  profit: number;
}

export default function InvestmentTab({
  balance,
  onSavingsDeposit,
  onInvestmentReturn,
  onNotification,
}: InvestmentTabProps) {
  const { user } = useAuth();
  const {
    investments: dbInvestments,
    investmentBalance,
    addInvestment,
    updateInvestmentStatus,
    updateUserInvestmentBalance,
  } = useDatabase(user?.id || null);

  // Investment states - use database data
  const [investments, setInvestments] = useState<Investment[]>([]);
  const [showInvestmentDialog, setShowInvestmentDialog] = useState(false);
  const [selectedInvestmentType, setSelectedInvestmentType] = useState<
    "weekly" | "monthly"
  >("weekly");
  const [investmentAmount, setInvestmentAmount] = useState("5000");
  const [investmentErrors, setInvestmentErrors] = useState({ amount: "" });
  const [isInvestmentProcessing, setIsInvestmentProcessing] = useState(false);

  // Sync database investments with local state
  useEffect(() => {
    if (dbInvestments) {
      const formattedInvestments = dbInvestments.map((inv) => ({
        id: inv.id,
        type: inv.type as "weekly" | "monthly",
        amount: inv.amount,
        startDate: new Date(inv.start_date),
        endDate: new Date(inv.end_date),
        profitRate: inv.profit_rate,
        status: inv.status as "active" | "completed",
        profit: inv.profit,
      }));
      setInvestments(formattedInvestments);
    }
  }, [dbInvestments]);

  // Investment data
  const investmentOptions = [
    {
      id: "weekly",
      type: "weekly" as const,
      name: "الاستثمار الأسبوعي",
      description: "استثمار لمدة أسبوع واحد",
      profitRate: 8,
      duration: "7 أيام",
      color: "from-green-500 to-emerald-600",
      minAmount: 1000,
    },
    {
      id: "monthly",
      type: "monthly" as const,
      name: "الاستثمار الشهري",
      description: "استثمار لمدة شهر واحد",
      profitRate: 25,
      duration: "30 يوماً",
      color: "from-blue-500 to-indigo-600",
      minAmount: 5000,
    },
  ];

  // Investment functions
  const handleInvestmentSelect = useCallback(
    (type: "weekly" | "monthly") => {
      const selectedOption = investmentOptions.find((opt) => opt.type === type);

      // إشعار اختيار نوع الاستثمار
      const selectionNotification = createNotification(
        "info",
        "تم اختيار نوع الاستثمار",
        `تم اختيار ${selectedOption!.name} بربح ${selectedOption!.profitRate}%`,
      );
      onNotification(selectionNotification);

      // التحقق من الرصيد قبل فتح نافذة الاستثمار
      const currentBalance = balance?.dzd || 0;
      if (currentBalance < selectedOption!.minAmount) {
        const notification = createNotification(
          "error",
          "رصيد غير كافي ❌",
          `💰 رصيدك الحالي: ${currentBalance.toLocaleString()} دج\n📋 المطلوب: ${selectedOption!.minAmount.toLocaleString()} دج\n💡 تحتاج إلى ${(selectedOption!.minAmount - currentBalance).toLocaleString()} دج إضافية للاستثمار في ${selectedOption!.name}`,
        );
        onNotification(notification);
        showBrowserNotification(
          "رصيد غير كافي",
          `تحتاج إلى ${selectedOption!.minAmount.toLocaleString()} دج على الأقل للاستثمار`,
        );
        return;
      }

      // إشعار فتح نافذة الاستثمار
      const dialogNotification = createNotification(
        "info",
        "جاهز للاستثمار",
        `يمكنك الآن تحديد مبلغ الاستثمار. الحد الأدنى: ${selectedOption!.minAmount.toLocaleString()} دج`,
      );
      onNotification(dialogNotification);

      // Optimized state updates without setTimeout
      setSelectedInvestmentType(type);
      setInvestmentAmount(selectedOption?.minAmount.toString() || "1000");
      setInvestmentErrors({ amount: "" });
      setIsInvestmentProcessing(false);
      setShowInvestmentDialog(true);
    },
    [balance?.dzd, investmentOptions, onNotification],
  );

  const handleInvestment = useCallback(async () => {
    if (isInvestmentProcessing) return;

    const amountError = validateAmount(investmentAmount);
    if (amountError) {
      setInvestmentErrors({ amount: amountError });
      const notification = createNotification(
        "error",
        "خطأ في المبلغ",
        amountError,
      );
      onNotification(notification);
      return;
    }

    const investAmount = parseFloat(investmentAmount);
    const selectedOption = investmentOptions.find(
      (opt) => opt.type === selectedInvestmentType,
    );

    if (!selectedOption) {
      const notification = createNotification(
        "error",
        "خطأ في النظام",
        "لم يتم العثور على خيار الاستثمار المحدد",
      );
      onNotification(notification);
      return;
    }

    if (investAmount < selectedOption.minAmount) {
      const errorMsg = `الحد الأدنى للاستثمار ${selectedOption.minAmount.toLocaleString()} دج`;
      setInvestmentErrors({ amount: errorMsg });
      const notification = createNotification(
        "error",
        "مبلغ غير كافي",
        errorMsg,
      );
      onNotification(notification);
      return;
    }

    // التحقق من الرصيد قبل البدء
    const currentBalance = balance?.dzd || 0;
    if (currentBalance < investAmount) {
      const notification = createNotification(
        "error",
        "رصيد غير كافي",
        `رصيدك الحالي: ${currentBalance.toLocaleString()} دج. تحتاج إلى: ${investAmount.toLocaleString()} دج`,
      );
      onNotification(notification);
      showBrowserNotification(
        "رصيد غير كافي",
        "ليس لديك رصيد كافي لإجراء هذا الاستثمار",
      );
      return;
    }

    setIsInvestmentProcessing(true);
    setInvestmentErrors({ amount: "" });

    // إشعار بداية العملية
    const startNotification = createNotification(
      "info",
      "جاري معالجة الاستثمار",
      "يتم الآن اقتطاع المبلغ وإنشاء الاستثمار...",
    );
    onNotification(startNotification);

    try {
      if (!user?.id) {
        throw new Error("معرف المستخدم غير متوفر");
      }

      // إشعار اقتطاع المبلغ
      const deductionNotification = createNotification(
        "info",
        "اقتطاع المبلغ",
        `يتم الآن اقتطاع ${investAmount.toLocaleString()} دج من رصيدك وإضافته لرصيد الاستثمار...`,
      );
      onNotification(deductionNotification);

      // استدعاء onSavingsDeposit لتحديث الرصيد في المكون الأب أولاً
      await onSavingsDeposit(investAmount, "investment");

      // إضافة المبلغ إلى رصيد الاستثمار
      if (updateUserInvestmentBalance) {
        await updateUserInvestmentBalance(investAmount, "add");
      }

      // إشعار إنشاء الاستثمار
      const createInvestmentNotification = createNotification(
        "info",
        "إنشاء الاستثمار",
        "يتم الآن إنشاء سجل الاستثمار في النظام...",
      );
      onNotification(createInvestmentNotification);

      // Create investment record in database
      const startDate = new Date();
      const endDate = new Date();
      if (selectedInvestmentType === "weekly") {
        endDate.setDate(startDate.getDate() + 7);
      } else {
        endDate.setDate(startDate.getDate() + 30);
      }

      const investmentData = {
        type: selectedInvestmentType,
        amount: investAmount,
        start_date: startDate.toISOString(),
        end_date: endDate.toISOString(),
        profit_rate: selectedOption.profitRate,
        status: "active",
        profit: (investAmount * selectedOption.profitRate) / 100,
      };

      let investmentId = Date.now().toString();
      if (addInvestment) {
        const investmentResult = await addInvestment(investmentData);
        if (investmentResult.data) {
          investmentId = investmentResult.data.id;
        }
      }

      const newInvestment: Investment = {
        id: investmentId,
        type: selectedInvestmentType,
        amount: investAmount,
        startDate,
        endDate,
        profitRate: selectedOption.profitRate,
        status: "active",
        profit: (investAmount * selectedOption.profitRate) / 100,
      };

      setInvestments((prev) => [...prev, newInvestment]);

      // إشعار نجاح الاستثمار مع تفاصيل كاملة
      const successNotification = createNotification(
        "success",
        "تم الاستثمار بنجاح! 🎉",
        `✅ تم استثمار ${investAmount.toLocaleString()} دج في ${selectedOption.name}\n💰 تم اقتطاع المبلغ من رصيدك\n📈 الربح المتوقع: ${newInvestment.profit.toLocaleString()} دج\n⏰ مدة الاستثمار: ${selectedOption.duration}`,
      );
      onNotification(successNotification);
      showBrowserNotification(
        "تم الاستثمار بنجاح! 🎉",
        `استثمار ${investAmount.toLocaleString()} دج - ربح متوقع: ${newInvestment.profit.toLocaleString()} دج`,
      );

      // إشعار جدولة الإكمال
      const scheduleNotification = createNotification(
        "info",
        "تم جدولة الاستثمار",
        `سيتم إكمال استثمارك تلقائياً في ${endDate.toLocaleDateString("ar-SA")} وإضافة الأرباح إلى رصيدك`,
      );
      onNotification(scheduleNotification);

      // إغلاق النافذة وإعادة تعيين الحالة فوراً
      setShowInvestmentDialog(false);
      setInvestmentAmount("5000");
      setInvestmentErrors({ amount: "" });
      setIsInvestmentProcessing(false);

      // Schedule investment completion for demo purposes
      // Weekly: 15 seconds, Monthly: 30 seconds
      const completionTimeout =
        selectedInvestmentType === "weekly" ? 15000 : 30000;

      const completionTimer = setTimeout(() => {
        console.log(
          `⏰ Scheduled completion for investment ${newInvestment.id}`,
        );
        completeInvestment(newInvestment.id);
      }, completionTimeout);

      // Store timer reference for cleanup if needed
      (window as any)[`investment_timer_${newInvestment.id}`] = completionTimer;
    } catch (error: any) {
      console.error("خطأ في معالجة الاستثمار:", error);

      const notification = createNotification(
        "error",
        "فشل في الاستثمار ❌",
        `حدث خطأ: ${error.message || "خطأ غير معروف"}\nيرجى المحاولة مرة أخرى أو التواصل مع الدعم الفني`,
      );
      onNotification(notification);
      showBrowserNotification(
        "فشل في الاستثمار",
        "حدث خطأ أثناء معالجة الاستثمار",
      );

      setIsInvestmentProcessing(false);
    }
  }, [
    investmentAmount,
    selectedInvestmentType,
    investmentOptions,
    onNotification,
    isInvestmentProcessing,
    user?.id,
    addInvestment,
    balance?.dzd,
    onSavingsDeposit,
  ]);

  const completeInvestment = async (investmentId: string) => {
    console.log(
      `🔄 Starting completion process for investment ${investmentId}`,
    );

    // Find the investment to complete
    const investmentToComplete = investments.find(
      (inv) => inv.id === investmentId && inv.status === "active",
    );

    if (!investmentToComplete) {
      console.log(
        `❌ Investment ${investmentId} not found or already completed`,
      );
      return;
    }

    try {
      // حساب إجمالي العائد = المبلغ الأصلي + الأرباح
      const totalReturn =
        investmentToComplete.amount + investmentToComplete.profit;

      console.log(
        `💰 Completing investment: ${investmentToComplete.amount} + ${investmentToComplete.profit} = ${totalReturn}`,
      );

      // إشعار بداية عملية الإكمال
      const startCompletionNotification = createNotification(
        "info",
        "إكمال الاستثمار",
        "يتم الآن إكمال استثمارك وإضافة الأرباح...",
      );
      onNotification(startCompletionNotification);

      // Update investment status in database first
      if (updateInvestmentStatus) {
        const updateResult = await updateInvestmentStatus(investmentId, {
          status: "completed",
          updated_at: new Date().toISOString(),
        });

        if (updateResult.error) {
          console.error(
            "Failed to update investment status:",
            updateResult.error,
          );
          throw new Error("فشل في تحديث حالة الاستثمار");
        }
      }

      // إرجاع المبلغ الأصلي + الأرباح إلى رصيد المستخدم الأساسي
      onInvestmentReturn(totalReturn);

      // خصم المبلغ من رصيد الاستثمار
      if (updateUserInvestmentBalance) {
        const balanceResult = await updateUserInvestmentBalance(
          investmentToComplete.amount,
          "subtract",
        );
        if (balanceResult.error) {
          console.error(
            "Failed to update investment balance:",
            balanceResult.error,
          );
        }
      }

      // Update local state
      setInvestments((prev) =>
        prev.map((inv) =>
          inv.id === investmentId
            ? { ...inv, status: "completed" as const }
            : inv,
        ),
      );

      // إشعار إكمال مفصل مع إحصائيات
      const completionNotification = createNotification(
        "success",
        "🎉 تهانينا! اكتمل الاستثمار بنجاح",
        `💰 تم إضافة ${totalReturn.toLocaleString()} دج إلى رصيدك\n\n📊 تفاصيل الاستثمار:\n• المبلغ الأصلي: ${investmentToComplete.amount.toLocaleString()} دج\n• الأرباح المحققة: ${investmentToComplete.profit.toLocaleString()} دج\n• نسبة الربح: ${investmentToComplete.profitRate}%\n• نوع الاستثمار: ${investmentToComplete.type === "weekly" ? "أسبوعي" : "شهري"}\n\n✨ شكراً لثقتك في منصتنا!`,
      );
      onNotification(completionNotification);

      showBrowserNotification(
        "🎉 اكتمل الاستثمار بنجاح!",
        `تم إضافة ${totalReturn.toLocaleString()} دج (${investmentToComplete.amount.toLocaleString()} أصل + ${investmentToComplete.profit.toLocaleString()} ربح)`,
      );

      // إشعار تشجيعي للاستثمار مرة أخرى
      setTimeout(() => {
        const encouragementNotification = createNotification(
          "info",
          "💡 نصيحة استثمارية",
          "الآن يمكنك إعادة استثمار أرباحك لتحقيق عوائد أكبر! استثمر بانتظام لبناء ثروتك.",
        );
        onNotification(encouragementNotification);
      }, 3000);

      // Clean up timer if it exists
      const timerKey = `investment_timer_${investmentId}`;
      if ((window as any)[timerKey]) {
        clearTimeout((window as any)[timerKey]);
        delete (window as any)[timerKey];
      }

      console.log(`✅ Investment ${investmentId} completed successfully`);
    } catch (error: any) {
      console.error(`❌ Error completing investment ${investmentId}:`, error);

      const errorNotification = createNotification(
        "error",
        "خطأ في إكمال الاستثمار",
        `حدث خطأ أثناء إكمال الاستثمار: ${error.message || "خطأ غير معروف"}`,
      );
      onNotification(errorNotification);
    }
  };

  const calculateTimeRemaining = (endDate: Date): string => {
    const now = new Date();
    const diff = endDate.getTime() - now.getTime();

    if (diff <= 0) return "انتهى";

    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((diff % (1000 * 60)) / 1000);

    if (days > 0) {
      return `${days} يوم و ${hours} ساعة`;
    } else if (hours > 0) {
      return `${hours} ساعة و ${minutes} دقيقة`;
    } else if (minutes > 0) {
      return `${minutes} دقيقة و ${seconds} ثانية`;
    } else {
      return `${seconds} ثانية`;
    }
  };

  const calculateInvestmentProgress = (
    startDate: Date,
    endDate: Date,
  ): number => {
    const now = new Date();
    const total = endDate.getTime() - startDate.getTime();
    const elapsed = now.getTime() - startDate.getTime();
    return Math.min((elapsed / total) * 100, 100);
  };

  // Check for completed investments on component mount and periodically
  useEffect(() => {
    const checkCompletedInvestments = () => {
      const now = new Date();
      investments.forEach((investment) => {
        if (investment.status === "active" && now >= investment.endDate) {
          console.log(
            `🎯 Investment ${investment.id} has matured, completing...`,
          );
          completeInvestment(investment.id);
        }
      });
    };

    // Check immediately on mount
    if (investments.length > 0) {
      checkCompletedInvestments();
    }

    // Check every 30 seconds for more responsive updates
    const interval = setInterval(checkCompletedInvestments, 30000);
    return () => clearInterval(interval);
  }, [investments]);

  // Auto-complete investments based on their duration (for demo purposes)
  useEffect(() => {
    investments.forEach((investment) => {
      if (investment.status === "active") {
        const timeUntilCompletion =
          investment.endDate.getTime() - new Date().getTime();

        // For demo: complete weekly investments after 15 seconds, monthly after 30 seconds
        const demoCompletionTime = investment.type === "weekly" ? 15000 : 30000;

        if (
          timeUntilCompletion > 0 &&
          timeUntilCompletion <= demoCompletionTime
        ) {
          const timeout = setTimeout(
            () => {
              console.log(
                `⏰ Auto-completing investment ${investment.id} after demo period`,
              );
              completeInvestment(investment.id);
            },
            Math.min(timeUntilCompletion, demoCompletionTime),
          );

          return () => clearTimeout(timeout);
        }
      }
    });
  }, [investments]);

  const totalInvested =
    investments?.reduce((sum, inv) => sum + (inv?.amount || 0), 0) || 0;
  const totalProfit =
    investments
      ?.filter((inv) => inv?.status === "completed")
      ?.reduce((sum, inv) => sum + (inv?.profit || 0), 0) || 0;
  const activeInvestments =
    investments?.filter((inv) => inv?.status === "active") || [];

  return (
    <div className="space-y-6 sm:space-y-8 pb-20 bg-transparent px-2 sm:px-0 max-w-6xl mx-auto">
      {/* Enhanced Page Header */}
      <div className="text-center mb-8 flex flex-col items-center justify-center">
        <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4 bg-gradient-to-r from-white via-purple-100 to-white bg-clip-text text-transparent text-center">
          منصة الاستثمار الذكي
        </h1>
        <p className="text-gray-300 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed text-center">
          استثمر أموالك بذكاء واحصل على عوائد مضمونة مع أفضل الخيارات
          الاستثمارية
        </p>
      </div>
      {/* Investment Performance Overview - Matching Home Style */}
      <div className="bg-gradient-to-br from-indigo-500/20 to-purple-600/20 backdrop-blur-md border border-indigo-400/30 shadow-xl rounded-xl sm:rounded-2xl p-6 sm:p-8 mb-6 sm:mb-8">
        <div className="text-center mb-6">
          <p className="text-4xl sm:text-5xl font-bold text-white mb-2 bg-gradient-to-r from-white via-indigo-100 to-white bg-clip-text text-transparent">
            {(totalInvested + totalProfit).toLocaleString()}
          </p>
          <p className="text-indigo-300 text-lg">القيمة الإجمالية</p>
        </div>
        <div className="space-y-4">
          <Separator className="bg-white/20" />
          <div className="flex justify-between items-center py-3">
            <div className="text-center">
              <p className="text-white font-bold text-lg mb-1">
                {totalInvested.toLocaleString()}
              </p>
              <p className="text-indigo-300 text-xs">إجمالي الاستثمارات</p>
            </div>
            <Separator orientation="vertical" className="bg-white/20 h-8" />
            <div className="text-center">
              <p className="text-white font-bold text-lg mb-1">
                +{totalProfit.toLocaleString()}
              </p>
              <p className="text-green-300 text-xs">إجمالي الأرباح</p>
            </div>
            <Separator orientation="vertical" className="bg-white/20 h-8" />
            <div className="text-center">
              <p className="text-white font-bold text-lg mb-1">
                {balance?.dzd?.toLocaleString() || 0}
              </p>
              <p className="text-purple-300 text-xs">الرصيد المتاح</p>
            </div>
          </div>
          <Separator className="bg-white/20" />
        </div>
      </div>
      {/* Investment Options */}
      <div className="space-y-6">
        <div className="text-center">
          <h3 className="text-white font-bold text-2xl mb-2">
            عروض الاستثمار المتاحة
          </h3>
          <p className="text-gray-300 text-sm">
            اختر الخطة التي تناسب أهدافك المالية
          </p>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-2 gap-4 sm:gap-6">
          {investmentOptions.map((option) => (
            <Card
              key={option.id}
              className={`bg-gradient-to-br ${option.color}/20 backdrop-blur-md border border-${option.type === "weekly" ? "blue" : "indigo"}-400/30 shadow-xl cursor-pointer hover:border-${option.type === "weekly" ? "blue" : "indigo"}-400/50 transition-all duration-300 group h-auto rounded-xl overflow-hidden`}
            >
              <CardContent className="p-6 h-full flex flex-col justify-center items-center text-center relative z-10">
                <div className="mb-4">
                  <div
                    className={`p-3 bg-${option.type === "weekly" ? "blue" : "indigo"}-500/30 rounded-full`}
                  >
                    {option.type === "weekly" ? (
                      <Clock className={`w-6 h-6 text-blue-400`} />
                    ) : (
                      <Calendar className={`w-6 h-6 text-indigo-400`} />
                    )}
                  </div>
                </div>
                <div className="mb-4">
                  <h3 className="text-white font-bold text-base mb-1">
                    {option.name}
                  </h3>
                  <p
                    className={`text-${option.type === "weekly" ? "blue" : "indigo"}-300 text-sm`}
                  >
                    {option.description}
                  </p>
                </div>

                <div className="space-y-3 mb-4 w-full">
                  <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                    <span className="text-gray-300 text-sm font-medium">
                      نسبة الربح
                    </span>
                    <span className="text-green-400 font-bold text-lg">
                      {option.profitRate}%
                    </span>
                  </div>
                  <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                    <span className="text-gray-300 text-sm font-medium">
                      المدة
                    </span>
                    <span
                      className={`text-${option.type === "weekly" ? "blue" : "indigo"}-400 font-bold text-sm`}
                    >
                      {option.duration}
                    </span>
                  </div>
                  <div className="flex justify-between items-center bg-white/10 rounded-lg p-3">
                    <span className="text-gray-300 text-sm font-medium">
                      الحد الأدنى
                    </span>
                    <span className="text-yellow-400 font-bold text-sm">
                      {option.minAmount.toLocaleString()} دج
                    </span>
                  </div>
                </div>

                <Button
                  onClick={() => {
                    const currentBalance = balance?.dzd || 0;
                    console.log("Investment button clicked:", option.type);
                    console.log(
                      "Button disabled?",
                      currentBalance < option.minAmount,
                    );
                    console.log(
                      "Balance:",
                      currentBalance,
                      "Min amount:",
                      option.minAmount,
                    );

                    // إشعار النقر على الزر
                    const clickNotification = createNotification(
                      "info",
                      "تحضير الاستثمار",
                      `يتم تحضير ${option.name} للاستثمار...`,
                    );
                    onNotification(clickNotification);

                    handleInvestmentSelect(option.type);
                  }}
                  className={`w-full bg-gradient-to-r ${option.color} hover:opacity-90 h-12 text-sm font-bold transition-all duration-300 transform hover:scale-105 shadow-xl hover:shadow-2xl disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none border-0 rounded-xl relative overflow-hidden group`}
                  disabled={(balance?.dzd || 0) < option.minAmount}
                >
                  <div className="absolute inset-0 bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                  <span className="relative z-10 flex items-center justify-center gap-2">
                    {(balance?.dzd || 0) >= option.minAmount ? (
                      <>
                        <TrendingUp className="w-4 h-4" />
                        اختر العرض
                      </>
                    ) : (
                      <>
                        <AlertCircle className="w-4 h-4" />
                        رصيد غير كافي
                      </>
                    )}
                  </span>
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
      {/* Active Investments */}
      {activeInvestments.length > 0 && (
        <div className="space-y-4">
          <h3 className="text-white font-bold text-lg text-center">
            الاستثمارات النشطة
          </h3>
          <div className="space-y-3">
            {activeInvestments.map((investment) => {
              const progress = calculateInvestmentProgress(
                investment.startDate,
                investment.endDate,
              );
              const timeRemaining = calculateTimeRemaining(investment.endDate);
              const selectedOption = investmentOptions.find(
                (opt) => opt.type === investment.type,
              );

              return (
                <Card
                  key={investment.id}
                  className="bg-white/10 backdrop-blur-md border border-white/20"
                >
                  <CardContent className="p-4">
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center space-x-3 space-x-reverse">
                        <div
                          className={`w-10 h-10 bg-gradient-to-r ${selectedOption?.color} rounded-full flex items-center justify-center`}
                        >
                          {investment.type === "weekly" ? (
                            <Timer className="w-5 h-5 text-white" />
                          ) : (
                            <Calendar className="w-5 h-5 text-white" />
                          )}
                        </div>
                        <div>
                          <h3 className="text-white font-bold text-sm">
                            {selectedOption?.name || "استثمار"}
                          </h3>
                          <p className="text-gray-300 text-xs">
                            {(investment?.amount || 0).toLocaleString()} دج
                          </p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-green-400 font-bold text-sm">
                          +{(investment?.profit || 0).toLocaleString()} دج
                        </p>
                        <p className="text-gray-400 text-xs">ربح متوقع</p>
                      </div>
                    </div>

                    <div className="space-y-2">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-300">التقدم</span>
                        <span className="text-gray-300">{timeRemaining}</span>
                      </div>
                      <div className="w-full bg-gray-700 rounded-full h-2">
                        <div
                          className={`bg-gradient-to-r ${selectedOption?.color} h-2 rounded-full transition-all duration-300`}
                          style={{ width: `${progress}%` }}
                        ></div>
                      </div>
                      <div className="flex justify-between items-center text-xs">
                        <span className="text-blue-400">
                          {progress.toFixed(1)}% مكتمل
                        </span>
                        <span className="text-gray-400">
                          {investment?.profitRate || 0}% ربح
                        </span>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </div>
      )}
      {/* بنود وشروط الاستثمار */}
      <Card className="bg-gradient-to-br from-red-500/20 to-orange-600/20 backdrop-blur-md border border-red-400/30">
        <CardContent className="p-4 sm:p-6">
          <h3 className="text-white font-bold text-base sm:text-lg mb-4 flex items-center justify-center text-center">
            <AlertCircle className="w-5 h-5 text-red-400 ml-2" />
            بنود وشروط الاستثمار
          </h3>
          <div className="space-y-3 text-right">
            <div className="flex items-start space-x-3 space-x-reverse">
              <DollarSign className="w-4 h-4 sm:w-5 sm:h-5 text-red-400 mt-0.5 flex-shrink-0" />
              <p className="text-gray-300 text-xs sm:text-sm text-right">
                <strong className="text-white">اقتطاع فوري:</strong> يتم اقتطاع
                المبلغ المستثمر من رصيدك فور تأكيد الاستثمار
              </p>
            </div>
            <div className="flex items-start space-x-3 space-x-reverse">
              <TrendingUp className="w-4 h-4 sm:w-5 sm:h-5 text-green-400 mt-0.5 flex-shrink-0" />
              <p className="text-gray-300 text-xs sm:text-sm text-right">
                <strong className="text-white">العائد:</strong> المبلغ الأصلي +
                الأرباح يتم إرجاعهما عند اكتمال المدة
              </p>
            </div>
            <div className="flex items-start space-x-3 space-x-reverse">
              <Clock className="w-4 h-4 sm:w-5 sm:h-5 text-blue-400 mt-0.5 flex-shrink-0" />
              <p className="text-gray-300 text-xs sm:text-sm text-right">
                <strong className="text-white">المدة:</strong> أسبوعي (7 أيام -
                8%) أو شهري (30 يوماً - 25%)
              </p>
            </div>
            <div className="flex items-start space-x-3 space-x-reverse">
              <Shield className="w-4 h-4 sm:w-5 sm:h-5 text-yellow-400 mt-0.5 flex-shrink-0" />
              <p className="text-gray-300 text-xs sm:text-sm text-right">
                <strong className="text-white">تنبيه:</strong> لا يمكن إلغاء
                الاستثمار بعد تأكيده
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
      {/* Investment Tips */}
      <Card className="bg-white/10 backdrop-blur-md border border-white/20">
        <CardContent className="p-4 sm:p-6">
          <h3 className="text-white font-bold text-base sm:text-lg mb-4 flex items-center justify-center text-center">
            <Star className="w-5 h-5 text-yellow-400 ml-2" />
            نصائح الاستثمار
          </h3>
          <div className="space-y-3 text-right">
            <div className="flex items-start space-x-3 space-x-reverse">
              <Shield className="w-4 h-4 sm:w-5 sm:h-5 text-blue-400 mt-0.5 flex-shrink-0" />
              <p className="text-gray-300 text-xs sm:text-sm text-right">
                نوع استثماراتك لتقليل المخاطر
              </p>
            </div>
            <div className="flex items-start space-x-3 space-x-reverse">
              <Clock className="w-4 h-4 sm:w-5 sm:h-5 text-green-400 mt-0.5 flex-shrink-0" />
              <p className="text-gray-300 text-xs sm:text-sm text-right">
                الاستثمار المنتظم يحقق عوائد أفضل
              </p>
            </div>
            <div className="flex items-start space-x-3 space-x-reverse">
              <Percent className="w-4 h-4 sm:w-5 sm:h-5 text-purple-400 mt-0.5 flex-shrink-0" />
              <p className="text-gray-300 text-xs sm:text-sm text-right">
                لا تستثمر أكثر من 70% من مدخراتك
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
      {/* Investment Dialog */}
      <Dialog
        open={showInvestmentDialog}
        onOpenChange={(open) => {
          console.log("Investment dialog onOpenChange:", open);
          setShowInvestmentDialog(open);
        }}
      >
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-purple-900/95 to-slate-900/95 backdrop-blur-md border border-white/20 text-white max-w-md mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <BarChart3 className="w-6 h-6 text-purple-400" />
              استثمار جديد
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              {selectedInvestmentType === "weekly"
                ? "استثمار أسبوعي - 8% ربح"
                : "استثمار شهري - 25% ربح"}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-6 mt-6">
            {/* Investment Type Selection */}
            <div className="space-y-2">
              <Label className="text-white font-medium">نوع الاستثمار</Label>
              <Select
                value={selectedInvestmentType}
                onValueChange={(value: "weekly" | "monthly") =>
                  setSelectedInvestmentType(value)
                }
              >
                <SelectTrigger className="bg-white/10 border-white/30 text-white">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="bg-slate-800 border-white/20">
                  <SelectItem
                    value="weekly"
                    className="text-white hover:bg-white/10"
                  >
                    أسبوعي - 8% ربح (7 أيام)
                  </SelectItem>
                  <SelectItem
                    value="monthly"
                    className="text-white hover:bg-white/10"
                  >
                    شهري - 25% ربح (30 يوماً)
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Investment Amount */}
            <div className="space-y-2">
              <Label
                htmlFor="investmentAmount"
                className="text-white font-medium"
              >
                مبلغ الاستثمار (دج)
              </Label>
              <Input
                id="investmentAmount"
                type="number"
                placeholder="أدخل المبلغ"
                value={investmentAmount}
                onChange={(e) => setInvestmentAmount(e.target.value)}
                className="text-center text-lg bg-white/10 border-white/30 text-white placeholder:text-gray-400 h-12 focus:border-purple-400 focus:ring-purple-400"
              />
              {investmentErrors.amount && (
                <p className="text-red-400 text-sm text-center">
                  {investmentErrors.amount}
                </p>
              )}
            </div>

            {/* Investment Summary */}
            {investmentAmount && parseFloat(investmentAmount) > 0 && (
              <div className="bg-yellow-500/20 border border-yellow-400/30 rounded-lg p-4 text-center">
                <p className="text-yellow-200 text-sm mb-2">رصيدك الحالي:</p>
                <p className="text-2xl font-bold text-white mb-2">
                  {(balance?.dzd || 0).toLocaleString()} دج
                </p>
                <p className="text-yellow-200 text-sm mb-2">ستحصل على:</p>
                <p className="text-xl font-bold text-yellow-400">
                  {Math.floor((balance?.dzd || 0) * 0.05).toLocaleString()} دج
                </p>
              </div>
            )}

            <div className="flex gap-3">
              <Button
                onClick={() => {
                  // إشعار إلغاء الاستثمار
                  const cancelNotification = createNotification(
                    "info",
                    "تم إلغاء الاستثمار",
                    "تم إلغاء عملية الاستثمار. يمكنك المحاولة مرة أخرى في أي وقت.",
                  );
                  onNotification(cancelNotification);

                  setShowInvestmentDialog(false);
                  setInvestmentAmount("5000");
                  setInvestmentErrors({ amount: "" });
                  setIsInvestmentProcessing(false);
                }}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
                disabled={isInvestmentProcessing}
              >
                إلغاء
              </Button>
              <Button
                onClick={handleInvestment}
                disabled={
                  isInvestmentProcessing ||
                  !investmentAmount ||
                  parseFloat(investmentAmount) <= 0
                }
                className="flex-1 h-12 bg-gradient-to-r from-purple-500 to-pink-600 hover:from-purple-600 hover:to-pink-700 transition-all duration-300 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none border-0 rounded-xl relative overflow-hidden group"
              >
                {isInvestmentProcessing ? (
                  <div className="flex items-center gap-2">
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    جاري المعالجة...
                  </div>
                ) : (
                  "تأكيد الاستثمار"
                )}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
