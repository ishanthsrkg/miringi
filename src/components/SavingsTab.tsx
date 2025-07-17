import { useState, useEffect } from "react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Separator } from "./ui/separator";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "./ui/dialog";
import {
  PiggyBank,
  Target,
  Plus,
  Calendar,
  CheckCircle,
  Gift,
  Home,
  Car,
  Plane,
  GraduationCap,
  Users,
  ArrowLeft,
  Share2,
  Copy,
  User,
  Coins,
  Clock,
  ArrowUpRight,
  Shield,
  AlertTriangle,
  X,
} from "lucide-react";
import { validateAmount } from "../utils/security";
import {
  createNotification,
  showBrowserNotification,
  type Notification,
} from "../utils/notifications";
import { useAuth } from "../hooks/useAuth";
import { useDatabase } from "../hooks/useDatabase";
import AccountVerification from "./AccountVerification";

interface SavingsTabProps {
  balance: { dzd: number; eur: number; usd: number; gbt: number };
  onSavingsDeposit: (amount: number, goalId: string) => void;
  onNotification: (notification: Notification) => void;
  onAddTestBalance?: (amount: number) => void;
}

interface SavingsGoal {
  id: string;
  name: string;
  targetAmount: number;
  currentAmount: number;
  deadline: string;
  icon: any;
  color: string;
  category: string;
}

const savingsGoals: SavingsGoal[] = [];

export default function SavingsTab({
  balance,
  onSavingsDeposit,
  onNotification,
  onAddTestBalance,
}: SavingsTabProps) {
  const { user } = useAuth();
  const {
    savingsGoals: dbSavingsGoals,
    addSavingsGoal,
    updateGoal,
  } = useDatabase(user?.id || null);

  const [showDepositDialog, setShowDepositDialog] = useState(false);
  const [showNewGoalDialog, setShowNewGoalDialog] = useState(false);
  const [selectedGoal, setSelectedGoal] = useState<SavingsGoal | null>(null);
  const [amount, setAmount] = useState("");
  const [isProcessing, setIsProcessing] = useState(false);
  const [errors, setErrors] = useState({ amount: "" });
  const [showSuccess, setShowSuccess] = useState(false);
  const [activeSection, setActiveSection] = useState<string | null>("referral");
  const [showTransferDialog, setShowTransferDialog] = useState(false);
  const [showVerificationDialog, setShowVerificationDialog] = useState(false);
  const [isTransferring, setIsTransferring] = useState(false);
  const [transferError, setTransferError] = useState("");

  // New goal form states
  const [newGoalName, setNewGoalName] = useState("");
  const [newGoalTarget, setNewGoalTarget] = useState("");
  const [newGoalDeadline, setNewGoalDeadline] = useState("");

  // Referral data - get from database
  const [referralStats, setReferralStats] = useState({
    totalReferrals: 0,
    totalEarnings: 0,
    pendingRewards: 0,
    thisMonthReferrals: 0,
  });
  const [userVerificationStatus, setUserVerificationStatus] =
    useState<any>(null);
  const [referralCode, setReferralCode] = useState("");
  const [referralList, setReferralList] = useState([]);

  // Load referral data and verification status
  useEffect(() => {
    const loadReferralData = async () => {
      if (!user?.id) {
        console.log("⚠️ No user ID available for referral data loading");
        return;
      }

      console.log("🔄 Loading referral data for user:", user.id);

      // Load user verification status
      try {
        const verificationResult = await getUserVerificationStatus(user.id);
        if (verificationResult.data) {
          setUserVerificationStatus(verificationResult.data);
          console.log(
            "✅ Verification status loaded:",
            verificationResult.data,
          );
        }
      } catch (error) {
        console.warn("⚠️ Failed to load verification status:", error);
      }

      try {
        // Get user's referral code from profile
        const { getUserProfile, getReferralStats, getUserReferrals } =
          await import("../lib/supabase");

        console.log("📊 Fetching referral data from database...");
        const [profileRes, statsRes, referralsRes] = await Promise.allSettled([
          getUserProfile(user.id),
          getReferralStats(user.id),
          getUserReferrals(user.id),
        ]);

        // Handle profile data
        if (
          profileRes.status === "fulfilled" &&
          profileRes.value.data?.referral_code
        ) {
          console.log(
            "✅ Referral code loaded:",
            profileRes.value.data.referral_code,
          );
          setReferralCode(profileRes.value.data.referral_code);
        } else {
          console.warn(
            "⚠️ Failed to load referral code:",
            profileRes.status === "rejected"
              ? profileRes.reason
              : "No referral code found",
          );
          // Generate a temporary referral code if none exists
          const tempCode = `REF${user.id.slice(-6).toUpperCase()}`;
          setReferralCode(tempCode);
        }

        // Handle stats data
        if (statsRes.status === "fulfilled" && statsRes.value.data) {
          console.log("✅ Referral stats loaded:", statsRes.value.data);
          setReferralStats(statsRes.value.data);
        } else {
          console.warn(
            "⚠️ Failed to load referral stats:",
            statsRes.status === "rejected" ? statsRes.reason : "No stats data",
          );
          // Set default stats
          setReferralStats({
            totalReferrals: 0,
            totalEarnings: 0,
            pendingRewards: 0,
            thisMonthReferrals: 0,
          });
        }

        // Handle referrals list
        if (referralsRes.status === "fulfilled" && referralsRes.value.data) {
          console.log(
            "✅ Referrals list loaded:",
            referralsRes.value.data.length,
            "items",
          );
          setReferralList(referralsRes.value.data);
        } else {
          console.warn(
            "⚠️ Failed to load referrals list:",
            referralsRes.status === "rejected"
              ? referralsRes.reason
              : "No referrals data",
          );
          setReferralList([]);
        }
      } catch (error) {
        console.error("💥 Error loading referral data:", error);
        // Set fallback data
        setReferralStats({
          totalReferrals: 0,
          totalEarnings: 0,
          pendingRewards: 0,
          thisMonthReferrals: 0,
        });
        setReferralList([]);
        if (!referralCode) {
          const tempCode = `REF${user.id.slice(-6).toUpperCase()}`;
          setReferralCode(tempCode);
        }
      }
    };

    loadReferralData();
  }, [user?.id]);

  // Use database savings goals or empty array
  const savingsGoalsExamples: SavingsGoal[] =
    dbSavingsGoals?.map((goal) => ({
      id: goal.id,
      name: goal.name,
      targetAmount: goal.target_amount,
      currentAmount: goal.current_amount,
      deadline: goal.deadline,
      icon: goal.icon,
      color: goal.color,
      category: goal.category,
    })) || [];

  const handleGoalSelect = (goal: SavingsGoal) => {
    setSelectedGoal(goal);
    setShowDepositDialog(true);
    setAmount("");
    setErrors({ amount: "" });
    setShowSuccess(false);
  };

  const handleDeposit = () => {
    const amountError = validateAmount(amount);
    if (amountError) {
      setErrors({ amount: amountError });
      return;
    }

    const depositAmount = parseFloat(amount);
    if (balance.dzd < depositAmount) {
      const notification = createNotification(
        "error",
        "رصيد غير كافي",
        "ليس لديك رصيد كافي لإجراء هذا الإيداع",
      );
      onNotification(notification);
      showBrowserNotification(
        "رصيد غير كافي",
        "ليس لديك رصيد كافي لإجراء هذا الإيداع",
      );
      return;
    }

    setIsProcessing(true);
    setErrors({ amount: "" });

    // Simulate deposit processing
    setTimeout(() => {
      onSavingsDeposit(depositAmount, selectedGoal?.id || "");
      setIsProcessing(false);
      setShowSuccess(true);

      const notification = createNotification(
        "success",
        "تم الإيداع بنجاح",
        `تم إيداع ${depositAmount.toLocaleString()} دج في هدف ${selectedGoal?.name}`,
      );
      onNotification(notification);
      showBrowserNotification(
        "تم الإيداع بنجاح",
        `تم إيداع ${depositAmount.toLocaleString()} دج في هدف ${selectedGoal?.name}`,
      );

      setTimeout(() => {
        setShowDepositDialog(false);
        setShowSuccess(false);
      }, 2000);
    }, 2000);
  };

  // Handle referral balance transfer
  const handleReferralTransfer = async () => {
    if (
      !user?.id ||
      !referralStats.totalEarnings ||
      referralStats.totalEarnings <= 0
    ) {
      return;
    }

    // Check if account is verified
    if (
      !userVerificationStatus ||
      userVerificationStatus.status !== "approved"
    ) {
      setShowVerificationDialog(true);
      setTransferError("الحساب غير موثق - فشل في تحويل الرصيد");

      const notification = createNotification(
        "error",
        "الحساب غير موثق",
        "يجب توثيق حسابك أولاً لتتمكن من تحويل رصيد الإحالة إلى رصيدك الأساسي",
      );
      onNotification(notification);
      showBrowserNotification(
        "الحساب غير موثق",
        "يجب توثيق حسابك أولاً لتتمكن من تحويل رصيد الإحالة",
      );
      return;
    }

    setShowTransferDialog(true);
    setTransferError("");
  };

  // Confirm referral balance transfer
  const confirmReferralTransfer = async () => {
    if (
      !user?.id ||
      !referralStats.totalEarnings ||
      referralStats.totalEarnings <= 0
    ) {
      return;
    }

    setIsTransferring(true);
    setTransferError("");

    try {
      // Update main balance by adding referral earnings
      const currentBalance = balance?.dzd || 0;
      const newBalance = currentBalance + referralStats.totalEarnings;

      const { error: balanceError } = await updateBalance({
        dzd: newBalance,
      });

      if (balanceError) {
        throw new Error(balanceError.message);
      }

      // Reset referral earnings (this would typically be done via API)
      setReferralStats((prev) => ({
        ...prev,
        totalEarnings: 0,
        pendingRewards: 0,
      }));

      // Create success notification
      const notification = createNotification(
        "success",
        "تم التحويل بنجاح",
        `تم تحويل ${referralStats.totalEarnings.toLocaleString()} دج من رصيد الإحالة إلى رصيدك الأساسي`,
      );
      onNotification(notification);
      showBrowserNotification(
        "تم التحويل بنجاح",
        `تم تحويل ${referralStats.totalEarnings.toLocaleString()} دج من رصيد الإحالة`,
      );

      setShowTransferDialog(false);
    } catch (error: any) {
      console.error("Error transferring referral balance:", error);
      setTransferError(error.message || "حدث خطأ أثناء التحويل");

      const notification = createNotification(
        "error",
        "فشل في التحويل",
        error.message || "حدث خطأ أثناء تحويل رصيد الإحالة",
      );
      onNotification(notification);
    } finally {
      setIsTransferring(false);
    }
  };

  const calculateProgress = (current: number, target: number): number => {
    return Math.min((current / target) * 100, 100);
  };

  const calculateDaysLeft = (deadline: string): number => {
    const today = new Date();
    const deadlineDate = new Date(deadline);
    const diffTime = deadlineDate.getTime() - today.getTime();
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  };

  const totalSavings = savingsGoalsExamples.reduce(
    (sum, goal) => sum + goal.currentAmount,
    0,
  );

  const copyReferralCode = async () => {
    if (!referralCode) {
      const notification = createNotification(
        "error",
        "خطأ",
        "كود الإحالة غير متوفر حالياً",
      );
      onNotification(notification);
      return;
    }

    try {
      console.log("📋 Copying referral code:", referralCode);
      // Check if clipboard API is available
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(referralCode);
        const notification = createNotification(
          "success",
          "تم نسخ الكود",
          "تم نسخ كود الإحالة إلى الحافظة",
        );
        onNotification(notification);
      } else {
        // Fallback for browsers that don't support clipboard API
        fallbackCopyTextToClipboard(referralCode);
      }
    } catch (err) {
      console.error("Failed to copy referral code: ", err);
      // Fallback method
      fallbackCopyTextToClipboard(referralCode);
    }
  };

  const fallbackCopyTextToClipboard = (text: string) => {
    try {
      // Create a temporary textarea element
      const textArea = document.createElement("textarea");
      textArea.value = text;
      textArea.style.position = "fixed";
      textArea.style.left = "-999999px";
      textArea.style.top = "-999999px";
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();

      // Try to copy using execCommand
      const successful = document.execCommand("copy");
      document.body.removeChild(textArea);

      if (successful) {
        const notification = createNotification(
          "success",
          "تم نسخ الكود",
          "تم نسخ كود الإحالة إلى الحافظة",
        );
        onNotification(notification);
      } else {
        // If all methods fail, show the code to user
        const notification = createNotification(
          "info",
          "كود الإحالة",
          `كود الإحالة الخاص بك: ${text}`,
        );
        onNotification(notification);
      }
    } catch (err) {
      console.error("Fallback copy failed: ", err);
      // Last resort - show the code to user
      const notification = createNotification(
        "info",
        "كود الإحالة",
        `كود الإحالة الخاص بك: ${text}`,
      );
      onNotification(notification);
    }
  };

  const renderReferralContent = () => (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center mb-6">
        <h1 className="text-2xl sm:text-3xl font-bold text-white mb-2 bg-gradient-to-r from-yellow-400 via-orange-500 to-red-500 bg-clip-text text-transparent">
          {" "}
          اربح المال مع كل صديق تدعوه!
        </h1>
        <p className="text-gray-300 text-sm sm:text-base">
          كلما زاد عدد أصدقائك، زادت أرباحك - بدون حدود!
        </p>
      </div>

      {/* Referral Statistics Card - Matching Home Total Balance Style */}
      <div className="bg-gradient-to-br from-indigo-500/20 to-purple-600/20 backdrop-blur-md border border-indigo-400/30 shadow-xl rounded-xl sm:rounded-2xl p-6 sm:p-8 mb-6 sm:mb-8">
        <div className="text-center mb-6">
          <p className="text-4xl sm:text-5xl font-bold text-white mb-2 bg-gradient-to-r from-white via-indigo-100 to-white bg-clip-text text-transparent">
            {(referralStats.totalEarnings || 0).toLocaleString()}
          </p>
          <p className="text-indigo-300 text-lg">
            دينار جزائري - إجمالي الأرباح
          </p>
        </div>
        <div className="space-y-4">
          <Separator className="bg-white/20" />
          <div className="flex justify-between items-center py-3">
            <div className="text-center">
              <p className="text-white font-bold text-lg mb-1">
                {referralStats.totalReferrals || 0}
              </p>
              <p className="text-green-300 text-xs">إجمالي الإحالات</p>
            </div>
            <Separator orientation="vertical" className="bg-white/20 h-8" />
            <div className="text-center">
              <p className="text-white font-bold text-lg mb-1">
                {referralStats.thisMonthReferrals || 0}
              </p>
              <p className="text-blue-300 text-xs">هذا الشهر</p>
            </div>
            <Separator orientation="vertical" className="bg-white/20 h-8" />
            <div className="text-center">
              <p className="text-white font-bold text-lg mb-1">
                {referralStats.pendingRewards || 0}
              </p>
              <p className="text-purple-300 text-xs">في الانتظار</p>
            </div>
          </div>
          <Separator className="bg-white/20" />
        </div>
      </div>
      {/* Share Referral - Mobile Optimized */}
      <Card className="bg-gradient-to-br from-blue-500/20 to-indigo-600/20 backdrop-blur-md border border-blue-400/30">
        <CardContent className="p-6">
          <h3 className="text-white font-bold text-lg mb-4 text-center">
            💰 شارك واربح الآن
          </h3>
          <div className="text-center space-y-4">
            <div className="bg-white/10 rounded-lg p-4">
              <p className="text-white font-mono text-sm mb-2">
                كود الإحالة: {referralCode || "جاري التحميل..."}
              </p>
            </div>
            <Button
              onClick={() => {
                if (!referralCode) return;
                const shareText = `انضم إلى نتليفاي واستخدم كود الإحالة ${referralCode} للحصول على مكافأة ترحيبية! ${window.location.origin}/signup?ref=${referralCode}`;
                if (navigator.share) {
                  navigator.share({
                    title: "انضم إلى نتليفاي",
                    text: shareText,
                    url: `${window.location.origin}/signup?ref=${referralCode}`,
                  });
                } else {
                  navigator.clipboard?.writeText(shareText).then(() => {
                    const notification = createNotification(
                      "success",
                      "تم النسخ",
                      "تم نسخ رابط الإحالة إلى الحافظة",
                    );
                    onNotification(notification);
                  });
                }
              }}
              className="w-full bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 h-12"
              disabled={!referralCode}
            >
              <Share2 className="w-5 h-5 ml-2" />
              {referralCode ? "مشاركة رابط الإحالة" : "جاري التحميل..."}
            </Button>
          </div>
          <p className="text-gray-300 text-sm text-center mt-3">
            شارك هذا الرابط مع أصدقائك واحصل على 500 دج لكل إحالة ناجحة + مكافآت
            شهرية
          </p>
          {!referralCode && (
            <div className="flex items-center justify-center mt-2">
              <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-400 mr-2"></div>
              <p className="text-blue-400 text-xs">جاري تحميل كود الإحالة...</p>
            </div>
          )}
        </CardContent>
      </Card>
      {/* How it works */}
      <Card className="bg-white/10 backdrop-blur-md border border-white/20">
        <CardContent className="p-6">
          <h3 className="text-white font-bold text-lg mb-4">
            كيف يعمل البرنامج؟
          </h3>
          <div className="space-y-4">
            <div className="flex items-start space-x-3 space-x-reverse">
              <div className="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center flex-shrink-0">
                <span className="text-white font-bold text-sm">1</span>
              </div>
              <div>
                <p className="text-white font-medium">شارك الكود</p>
                <p className="text-gray-300 text-sm">
                  أرسل كود الإحالة لأصدقائك عبر الرسائل أو وسائل التواصل
                </p>
              </div>
            </div>
            <div className="flex items-start space-x-3 space-x-reverse">
              <div className="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center flex-shrink-0">
                <span className="text-white font-bold text-sm">2</span>
              </div>
              <div>
                <p className="text-white font-medium">التسجيل والتفعيل</p>
                <p className="text-gray-300 text-sm">
                  يسجل صديقك باستخدام الكود ويفعل حسابه بنجاح
                </p>
              </div>
            </div>
            <div className="flex items-start space-x-3 space-x-reverse">
              <div className="w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center flex-shrink-0">
                <span className="text-white font-bold text-sm">3</span>
              </div>
              <div>
                <p className="text-white font-medium">احصل على المكافأة</p>
                <p className="text-gray-300 text-sm">
                  تحصل على 500 دج فوراً + مكافآت إضافية عند أول معاملة
                </p>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
      {/* Referral List */}
      <Card className="bg-white/10 backdrop-blur-md border border-white/20">
        <CardContent className="p-6">
          <h3 className="text-white font-bold text-lg mb-4">
            الإحالات الأخيرة
          </h3>
          {referralList.length > 0 ? (
            <div className="space-y-3 max-h-48 overflow-y-auto">
              {referralList.slice(0, 5).map((referral: any) => (
                <div
                  key={referral.id}
                  className="flex items-center justify-between bg-white/5 rounded-lg p-3"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                      <User className="w-4 h-4 text-white" />
                    </div>
                    <div>
                      <p className="text-white font-medium text-sm">
                        {referral.referred_user?.full_name || "مستخدم جديد"}
                      </p>
                      <p className="text-gray-400 text-xs">
                        {new Date(referral.created_at).toLocaleDateString(
                          "ar-SA",
                        )}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-green-400 font-bold text-sm">
                      +{(referral.reward_amount || 0).toLocaleString()} دج
                    </p>
                    <p className="text-gray-400 text-xs">
                      {referral.status === "completed"
                        ? "مكتملة"
                        : "في الانتظار"}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-8">
              <Users className="w-12 h-12 text-gray-400 mx-auto mb-3 opacity-50" />
              <p className="text-gray-400 text-sm">لا توجد إحالات حتى الآن</p>
              <p className="text-gray-500 text-xs mt-1">
                ادع أصدقاءك باستخدام كود الإحالة الخاص بك
              </p>
            </div>
          )}
        </CardContent>
      </Card>
      {/* Transfer Referral Balance Button */}
      {referralStats.totalEarnings > 0 && (
        <Button
          className="w-full bg-gradient-to-r from-yellow-500 to-orange-600 hover:from-yellow-600 hover:to-orange-700 h-12 mb-4"
          onClick={handleReferralTransfer}
        >
          <ArrowUpRight className="w-5 h-5 ml-2" />
          تحويل إلى الرصيد الأساسي (
          {referralStats.totalEarnings.toLocaleString()} دج)
        </Button>
      )}
    </div>
  );

  const renderSavingsContent = () => (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <Button
          variant="ghost"
          onClick={() => setActiveSection(null)}
          className="text-white hover:bg-white/10 p-2"
        >
          <ArrowLeft className="w-5 h-5" />
        </Button>
        <h2 className="text-xl font-bold text-white">أهداف الادخار</h2>
        <Button
          variant="ghost"
          onClick={() => setShowNewGoalDialog(true)}
          className="text-blue-400 hover:bg-blue-500/20 p-2"
        >
          <Plus className="w-5 h-5" />
        </Button>
      </div>

      {/* Total Savings */}
      <Card className="bg-gradient-to-br from-blue-500/20 to-indigo-600/20 backdrop-blur-md border border-blue-400/30">
        <CardContent className="p-6 text-center">
          <PiggyBank className="w-12 h-12 text-blue-400 mx-auto mb-3" />
          <p className="text-blue-300 text-sm">إجمالي المدخرات</p>
          <p className="text-white font-bold text-3xl">
            {totalSavings.toLocaleString()} دج
          </p>
          <p className="text-gray-300 text-sm mt-2">
            من {savingsGoalsExamples.length} أهداف نشطة
          </p>
        </CardContent>
      </Card>

      {/* Savings Goals */}
      <div className="space-y-4">
        {savingsGoalsExamples.length === 0 ? (
          <Card className="bg-white/10 backdrop-blur-md border border-white/20">
            <CardContent className="p-8 text-center">
              <div className="text-gray-400">
                <Target className="w-12 h-12 mx-auto mb-3 opacity-50" />
                <p className="text-sm">لا توجد أهداف ادخار حتى الآن</p>
                <p className="text-xs mt-1">
                  أضف هدف ادخار جديد لتبدأ رحلتك المالية
                </p>
              </div>
            </CardContent>
          </Card>
        ) : (
          savingsGoalsExamples.map((goal) => {
            const progress = calculateProgress(
              goal.currentAmount,
              goal.targetAmount,
            );
            const daysLeft = calculateDaysLeft(goal.deadline);
            const IconComponent = goal.icon;

            return (
              <Card
                key={goal.id}
                className="bg-white/10 backdrop-blur-md border border-white/20 hover:bg-white/15 transition-all duration-300"
              >
                <CardContent className="p-4">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center space-x-3 space-x-reverse">
                      <div
                        className={`w-10 h-10 bg-gradient-to-r ${goal.color} rounded-full flex items-center justify-center`}
                      >
                        <IconComponent className="w-5 h-5 text-white" />
                      </div>
                      <div>
                        <h3 className="text-white font-bold">{goal.name}</h3>
                        <p className="text-gray-300 text-sm">{goal.category}</p>
                      </div>
                    </div>
                    <Button
                      onClick={() => handleGoalSelect(goal)}
                      size="sm"
                      className="bg-blue-600 hover:bg-blue-700"
                    >
                      إيداع
                    </Button>
                  </div>

                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-300">
                        {goal.currentAmount.toLocaleString()} دج
                      </span>
                      <span className="text-gray-300">
                        {goal.targetAmount.toLocaleString()} دج
                      </span>
                    </div>
                    <div className="w-full bg-gray-700 rounded-full h-2">
                      <div
                        className={`bg-gradient-to-r ${goal.color} h-2 rounded-full transition-all duration-300`}
                        style={{ width: `${progress}%` }}
                      ></div>
                    </div>
                    <div className="flex justify-between items-center text-xs">
                      <span className="text-green-400">
                        {progress.toFixed(1)}% مكتمل
                      </span>
                      <span className="text-gray-400">
                        {daysLeft > 0 ? `${daysLeft} يوم متبقي` : "انتهت المدة"}
                      </span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            );
          })
        )}
      </div>

      {/* Add New Goal Button */}
      <Button
        onClick={() => setShowNewGoalDialog(true)}
        className="w-full bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 h-12"
      >
        <Plus className="w-5 h-5 ml-2" />
        إضافة هدف جديد
      </Button>
    </div>
  );

  if (activeSection === "referral") {
    return (
      <div className="space-y-4 sm:space-y-6 pb-20 bg-transparent px-2 sm:px-0">
        {renderReferralContent()}
      </div>
    );
  }

  if (activeSection === "savings") {
    return (
      <div className="space-y-4 sm:space-y-6 pb-20 bg-transparent px-2 sm:px-0">
        {renderSavingsContent()}
      </div>
    );
  }

  return (
    <div className="space-y-4 sm:space-y-6 pb-20 bg-transparent px-2 sm:px-0">
      <div className="text-center">
        <h2 className="text-xl sm:text-2xl font-bold text-white mb-2">
          💰 ادع أصدقاءك واربح 500 دج فوراً!
        </h2>
        <p className="text-gray-300 text-sm sm:text-base">
          كل إحالة ناجحة = 500 دج في جيبك + مكافآت شهرية مضاعفة
        </p>
        {/* Test Balance Button */}
        {onAddTestBalance && <div className="mt-4"></div>}
      </div>
      {/* Three Main Sections */}
      <div className="grid grid-cols-1 gap-4 sm:gap-6">
        {/* Referral Section */}
        <Card
          className="bg-gradient-to-br from-green-500/20 to-emerald-600/20 backdrop-blur-md shadow-xl border border-green-400/30 text-white cursor-pointer hover:from-green-500/30 hover:to-emerald-600/30 transition-all duration-300"
          onClick={() => setActiveSection("referral")}
        >
          <CardContent className="p-6">
            <div className="flex items-center space-x-4 space-x-reverse">
              <div className="w-16 h-16 bg-gradient-to-r from-green-500 to-emerald-600 rounded-full flex items-center justify-center shadow-lg flex-shrink-0">
                <Users className="w-8 h-8 text-white" />
              </div>
              <div className="flex-1">
                <h3 className="text-xl font-bold text-white mb-2">الإحالة</h3>
                <p className="text-green-200 text-sm mb-3">
                  ادع أصدقاءك واحصل على مكافآت فورية ومستمرة
                </p>
                <div className="flex items-center justify-between">
                  <div className="bg-green-500/20 rounded-lg p-3 flex-1 ml-2">
                    <p className="text-green-300 text-xs">عدد الإحالات</p>
                    <p className="text-white font-bold text-2xl">
                      {referralStats.totalReferrals || 0}
                    </p>
                  </div>
                  <Button
                    className="bg-green-600 hover:bg-green-700 text-white px-6 py-2"
                    onClick={() => {
                      setActiveSection("referral");
                    }}
                  >
                    دعوة الأصدقاء
                  </Button>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Savings Section */}
        <Card
          className="bg-gradient-to-br from-blue-500/20 to-indigo-600/20 backdrop-blur-md shadow-xl border border-blue-400/30 text-white cursor-pointer hover:from-blue-500/30 hover:to-indigo-600/30 transition-all duration-300"
          onClick={() => setActiveSection("savings")}
        >
          <CardContent className="p-6">
            <div className="flex items-center space-x-4 space-x-reverse">
              <div className="w-16 h-16 bg-gradient-to-r from-blue-500 to-indigo-600 rounded-full flex items-center justify-center shadow-lg flex-shrink-0">
                <PiggyBank className="w-8 h-8 text-white" />
              </div>
              <div className="flex-1">
                <h3 className="text-xl font-bold text-white mb-2">الادخار</h3>
                <p className="text-blue-200 text-sm mb-3">حقق أهدافك المالية</p>
                <div className="flex items-center justify-between">
                  <div className="bg-blue-500/20 rounded-lg p-3 flex-1 ml-2">
                    <p className="text-blue-300 text-xs">إجمالي المدخرات</p>
                    <p className="text-white font-bold text-2xl">
                      {totalSavings.toLocaleString()} دج
                    </p>
                  </div>
                  <Button
                    className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2"
                    onClick={() => {
                      setActiveSection("savings");
                    }}
                  >
                    اختيار
                  </Button>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
      {/* Transfer Referral Balance Dialog */}
      <Dialog open={showTransferDialog} onOpenChange={setShowTransferDialog}>
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-blue-900/95 to-slate-900/95 backdrop-blur-md border border-white/20 text-white max-w-md mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <ArrowUpRight className="w-6 h-6 text-yellow-400" />
              تحويل رصيد الإحالة
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              تحويل رصيد الإحالة إلى الرصيد الأساسي
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-6 mt-6">
            <div className="bg-yellow-500/20 border border-yellow-400/30 rounded-lg p-4 text-center">
              <Coins className="w-8 h-8 text-yellow-400 mx-auto mb-2" />
              <p className="text-yellow-300 text-sm">المبلغ المراد تحويله</p>
              <p className="text-white font-bold text-2xl">
                {referralStats.totalEarnings.toLocaleString()} دج
              </p>
            </div>

            {transferError && (
              <div className="bg-red-500/20 border border-red-400/30 rounded-lg p-4 text-center">
                <AlertTriangle className="w-6 h-6 text-red-400 mx-auto mb-2" />
                <p className="text-red-400 text-sm">{transferError}</p>
              </div>
            )}

            <div className="flex gap-3">
              <Button
                onClick={() => {
                  setShowTransferDialog(false);
                  setTransferError("");
                }}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
                disabled={isTransferring}
              >
                إلغاء
              </Button>
              <Button
                onClick={confirmReferralTransfer}
                disabled={isTransferring || referralStats.totalEarnings <= 0}
                className="flex-1 h-12 bg-gradient-to-r from-yellow-500 to-orange-600 hover:from-yellow-600 hover:to-orange-700"
              >
                {isTransferring ? "جاري التحويل..." : "تأكيد التحويل"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
      {/* Account Verification Dialog */}
      <Dialog
        open={showVerificationDialog}
        onOpenChange={setShowVerificationDialog}
      >
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-blue-900/95 to-slate-900/95 backdrop-blur-md border border-white/20 text-white max-w-lg mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <Shield className="w-6 h-6 text-red-400" />
              الحساب غير موثق
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              يجب توثيق حسابك لتتمكن من تحويل رصيد الإحالة
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-6 mt-6">
            <div className="bg-red-500/20 border border-red-400/30 rounded-lg p-6 text-center">
              <AlertTriangle className="w-12 h-12 text-red-400 mx-auto mb-4" />
              <h3 className="text-white font-bold text-lg mb-2">
                فشل في تحويل الرصيد
              </h3>
              <p className="text-red-300 text-sm mb-4">
                الحساب غير موثق - لا يمكن تحويل رصيد الإحالة إلى الرصيد الأساسي
              </p>
              <div className="bg-blue-500/20 border border-blue-400/30 rounded-lg p-4">
                <Shield className="w-8 h-8 text-blue-400 mx-auto mb-2" />
                <p className="text-blue-300 text-sm font-medium mb-2">
                  لماذا التوثيق مطلوب؟
                </p>
                <ul className="text-gray-300 text-xs space-y-1 text-right">
                  <li>• حماية حسابك من الاستخدام غير المشروع</li>
                  <li>• ضمان أمان المعاملات المالية</li>
                  <li>• الامتثال للقوانين المصرفية</li>
                  <li>• تفعيل جميع الخدمات المتقدمة</li>
                </ul>
              </div>
            </div>

            <div className="flex gap-3">
              <Button
                onClick={() => setShowVerificationDialog(false)}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
              >
                <X className="w-4 h-4 ml-2" />
                إغلاق
              </Button>
              <Button
                onClick={() => {
                  setShowVerificationDialog(false);
                  // Navigate to verification page
                  window.location.href = "/account-verification";
                }}
                className="flex-1 h-12 bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700"
              >
                <Shield className="w-4 h-4 ml-2" />
                توثيق الحساب الآن
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
      {/* Deposit Dialog */}
      <Dialog open={showDepositDialog} onOpenChange={setShowDepositDialog}>
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-blue-900/95 to-slate-900/95 backdrop-blur-md border border-white/20 text-white max-w-md mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <PiggyBank className="w-6 h-6 text-blue-400" />
              إيداع في الادخار
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              {selectedGoal && `إيداع في هدف: ${selectedGoal.name}`}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-6 mt-6">
            <div className="space-y-2">
              <Label htmlFor="amount" className="text-white font-medium">
                مبلغ الإيداع (دج)
              </Label>
              <Input
                id="amount"
                type="number"
                placeholder="أدخل المبلغ"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="text-center text-lg bg-white/10 border-white/30 text-white placeholder:text-gray-400 h-12 focus:border-blue-400 focus:ring-blue-400"
              />
              {errors.amount && (
                <p className="text-red-400 text-sm text-center">
                  {errors.amount}
                </p>
              )}
            </div>

            {showSuccess && (
              <div className="bg-green-500/20 border border-green-400/30 rounded-lg p-4 text-center">
                <CheckCircle className="w-8 h-8 text-green-400 mx-auto mb-2" />
                <p className="text-green-400 font-medium">تم الإيداع بنجاح!</p>
              </div>
            )}

            <div className="flex gap-3">
              <Button
                onClick={() => {
                  setShowDepositDialog(false);
                  setAmount("");
                  setErrors({ amount: "" });
                  setShowSuccess(false);
                }}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
                disabled={isProcessing}
              >
                إلغاء
              </Button>
              <Button
                onClick={handleDeposit}
                disabled={isProcessing || !amount || parseFloat(amount) <= 0}
                className="flex-1 h-12 bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700"
              >
                {isProcessing ? "جاري المعالجة..." : "إيداع"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
