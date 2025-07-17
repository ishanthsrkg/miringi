import { useState, useEffect, useMemo, useCallback } from "react";
import { Button } from "./ui/button";
import { Card, CardContent } from "./ui/card";
import {
  CreditCard,
  Eye,
  EyeOff,
  Lock,
  Unlock,
  Settings,
  Plus,
  TrendingUp,
  Shield,
  Sparkles,
  Copy,
  MoreHorizontal,
  MapPin,
  Clock,
  CheckCircle,
  Zap,
  Globe,
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
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";
import { generateSecureCardNumber, maskCardNumber } from "../utils/security";
import {
  createNotification,
  showBrowserNotification,
} from "../utils/notifications";
import { useAuth } from "../hooks/useAuth";
import { useDatabase } from "../hooks/useDatabase";

interface CardTabProps {
  isActivated?: boolean;
  balance?: {
    dzd: number;
    eur: number;
    usd: number;
    gbp: number;
  };
}

function CardTab({ isActivated = true, balance: propBalance }: CardTabProps) {
  const { user } = useAuth();
  const {
    cards,
    balance: dbBalance,
    updateCardStatus,
    updateBalance,
    loading,
  } = useDatabase(user?.id || null);

  const [showCardDetails, setShowCardDetails] = useState(false);
  const [showFreezeDialog, setShowFreezeDialog] = useState(false);
  const [showChargeDialog, setShowChargeDialog] = useState(false);
  const [showSettingsDialog, setShowSettingsDialog] = useState(false);
  const [showRequestCardDialog, setShowRequestCardDialog] = useState(false);
  const [showActivateCardDialog, setShowActivateCardDialog] = useState(false);
  const [chargeAmount, setChargeAmount] = useState("");
  const [selectedCurrency, setSelectedCurrency] = useState("dzd");
  const [cardBalance, setCardBalance] = useState(0);
  const [cardCurrency, setCardCurrency] = useState("dzd");
  const [cardRequested, setCardRequested] = useState(false);
  const [cardActivated, setCardActivated] = useState(false);
  const [deliveryCountry, setDeliveryCountry] = useState("");
  const [deliveryAddress, setDeliveryAddress] = useState("");
  const [cvvCode, setCvvCode] = useState("");
  const [cvvError, setCvvError] = useState("");
  const [isCardLoading, setIsCardLoading] = useState(false);
  const [imageLoaded, setImageLoaded] = useState(false);
  const [imageError, setImageError] = useState(false);

  // Get the physical card from database
  const physicalCard =
    cards?.find((card) => card.card_type === "solid") || cards?.[0];

  // Memoize the card image URL and preload it
  const cardImageUrl = useMemo(() => {
    return "/images/new-netlify-visa-card.png";
  }, []);

  // Preload the image immediately
  useEffect(() => {
    const preloadImage = () => {
      const img = new Image();
      img.onload = () => {
        setImageLoaded(true);
        setIsCardLoading(false);
      };
      img.onerror = () => {
        setImageError(true);
        setIsCardLoading(false);
      };
      img.src = cardImageUrl;
      // Force immediate loading
      img.loading = "eager";
      img.fetchPriority = "high";
    };

    setIsCardLoading(true);
    preloadImage();
  }, [cardImageUrl]);

  // Use balance from database or props with zero fallback
  const isBalanceLoaded =
    !loading && (dbBalance !== null || propBalance !== null);
  const safeDbBalance = dbBalance || { dzd: 0, eur: 0, usd: 0, gbp: 0 };
  const safePropBalance = propBalance || { dzd: 0, eur: 0, usd: 0, gbp: 0 };
  const fullBalance = isBalanceLoaded
    ? dbBalance
      ? safeDbBalance
      : safePropBalance
    : { dzd: 0, eur: 0, usd: 0, gbp: 0 };

  const getCurrencySymbol = (currency: string) => {
    switch (currency) {
      case "eur":
        return "€";
      case "usd":
        return "$";
      case "gbp":
        return "£";
      case "dzd":
        return "دج";
      default:
        return "دج";
    }
  };

  const copyToClipboard = async (
    text: string,
    message = "تم نسخ المحتوى بنجاح!",
  ) => {
    try {
      // Check if clipboard API is available and we're in a secure context
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
        const notification = createNotification("success", "تم النسخ", message);
        showBrowserNotification("تم النسخ", message);
      } else {
        // Fallback for non-secure contexts or unsupported browsers
        const textArea = document.createElement("textarea");
        textArea.value = text;
        textArea.style.position = "fixed";
        textArea.style.left = "-999999px";
        textArea.style.top = "-999999px";
        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();

        try {
          document.execCommand("copy");
          const notification = createNotification(
            "success",
            "تم النسخ",
            message,
          );
          showBrowserNotification("تم النسخ", message);
        } catch (err) {
          console.warn("Copy failed:", err);
          const notification = createNotification(
            "error",
            "فشل النسخ",
            "لا يمكن نسخ النص في هذا المتصفح",
          );
        }

        document.body.removeChild(textArea);
      }
    } catch (err) {
      console.warn("Copy failed:", err);
      const notification = createNotification(
        "error",
        "فشل النسخ",
        "لا يمكن نسخ النص في هذا المتصفح",
      );
    }
  };

  const copyCardNumber = () => {
    const cardNumber = physicalCard?.card_number || generateSecureCardNumber();
    copyToClipboard(cardNumber, "تم نسخ رقم البطاقة بنجاح!");
  };

  const copyCardholderName = () => {
    const profile = user?.profile;
    const fullName =
      profile?.full_name ||
      user?.user_metadata?.full_name ||
      user?.profile?.username ||
      "اسم المستخدم";
    copyToClipboard(fullName, "تم نسخ اسم حامل البطاقة بنجاح!");
  };

  const handleFreezeCard = async () => {
    if (physicalCard && updateCardStatus) {
      const newFrozenState = !physicalCard.is_frozen;
      await updateCardStatus(physicalCard.id, { is_frozen: newFrozenState });

      const notification = createNotification(
        "success",
        newFrozenState ? "تم تجميد البطاقة" : "تم إلغاء تجميد البطاقة",
        newFrozenState
          ? "تم تجميد البطاقة بنجاح. يمكنك إلغاء التجميد في أي وقت."
          : "تم إلغاء تجميد البطاقة بنجاح. يمكنك الآن استخدامها.",
      );
      showBrowserNotification(
        newFrozenState ? "تم تجميد البطاقة" : "تم إلغاء تجميد البطاقة",
        newFrozenState
          ? "تم تجميد البطاقة بنجاح"
          : "تم إلغاء تجميد البطاقة بنجاح",
      );
    }
    setShowFreezeDialog(false);
  };

  const handleChargeCard = async () => {
    const amount = parseFloat(chargeAmount);
    const availableBalance =
      fullBalance[selectedCurrency as keyof typeof fullBalance] || 0;

    if (amount > 0 && amount <= availableBalance) {
      // Update the selected currency balance in main account
      const newBalance = { ...fullBalance };
      newBalance[selectedCurrency as keyof typeof newBalance] =
        availableBalance - amount;

      // Update balance in database
      await updateBalance(newBalance);

      // Add to card balance
      setCardBalance((prev) => prev + amount);
      setCardCurrency(selectedCurrency);

      // Create notification
      const notification = createNotification(
        "success",
        "تم شحن البطاقة بنجاح",
        `تم تحويل ${amount.toLocaleString()} ${getCurrencySymbol(selectedCurrency)} إلى البطاقة`,
      );
      showBrowserNotification(
        "تم شحن البطاقة بنجاح",
        `تم تحويل ${amount.toLocaleString()} ${getCurrencySymbol(selectedCurrency)} إلى البطاقة`,
      );

      setShowChargeDialog(false);
      setChargeAmount("");
      setSelectedCurrency("dzd");
    }
  };

  return (
    <>
      <div className="space-y-6 sm:space-y-8 pb-20 bg-transparent px-2 sm:px-0 max-w-6xl mx-auto">
        {/* Enhanced Page Header - Investment Style */}
        <div className="text-center mb-8 flex flex-col items-center justify-center">
          <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4 bg-gradient-to-r from-white via-blue-100 to-white bg-clip-text text-transparent text-center">
            بطاقتي المصرفية
          </h1>
          <p className="text-gray-300 text-base sm:text-lg max-w-2xl mx-auto leading-relaxed text-center">
            إدارة بطاقتك المصرفية بسهولة وأمان مع أفضل الخدمات المصرفية
          </p>
          <div className="flex items-center justify-center space-x-6 space-x-reverse mt-6">
            <div className="flex items-center space-x-2 space-x-reverse text-green-400">
              <Shield className="w-5 h-5" />
              <span className="text-sm font-medium">آمنة ومحمية</span>
            </div>
            <div className="flex items-center space-x-2 space-x-reverse text-blue-400">
              <Zap className="w-5 h-5" />
              <span className="text-sm font-medium">معاملات فورية</span>
            </div>
            <div className="flex items-center space-x-2 space-x-reverse text-purple-400">
              <Globe className="w-5 h-5" />
              <span className="text-sm font-medium">استخدام عالمي</span>
            </div>
          </div>
        </div>

        {/* Enhanced Physical Card Visual - Optimized for All Devices */}
        <div className="flex justify-center mb-6 sm:mb-8 px-2 sm:px-4">
          <div className="relative w-full max-w-sm sm:max-w-md md:max-w-lg lg:max-w-xl xl:max-w-2xl">
            {/* Perfect aspect ratio for Visa card */}
            <div className="aspect-[1.586/1]">
              <div
                className={`relative w-full h-full rounded-2xl sm:rounded-3xl lg:rounded-[2rem] shadow-[0_20px_50px_rgba(0,0,0,0.4)] hover:shadow-[0_25px_60px_rgba(0,0,0,0.5)] transform hover:scale-[1.02] transition-all duration-500 overflow-hidden ${!imageLoaded && !physicalCard?.is_frozen ? "animate-pulse" : ""}`}
                style={{
                  backgroundImage: physicalCard?.is_frozen
                    ? "none"
                    : imageLoaded && !imageError
                      ? `url('${cardImageUrl}')`
                      : "none",
                  backgroundSize: "cover",
                  backgroundPosition: "center",
                  backgroundRepeat: "no-repeat",
                  backgroundColor: physicalCard?.is_frozen
                    ? "#374151"
                    : imageLoaded && !imageError
                      ? "transparent"
                      : "#1e293b",
                  imageRendering: "crisp-edges",
                  WebkitImageRendering: "crisp-edges",
                  WebkitBackfaceVisibility: "hidden",
                  backfaceVisibility: "hidden",
                  WebkitTransform: "translateZ(0)",
                  transform: "translateZ(0)",
                  willChange: "transform",
                  contain: "layout style paint",
                }}
              >
                {/* Loading State */}
                {!imageLoaded && !physicalCard?.is_frozen && !imageError && (
                  <div className="absolute inset-0 bg-gradient-to-br from-slate-800 via-slate-700 to-slate-900 rounded-2xl sm:rounded-3xl lg:rounded-[2rem] flex items-center justify-center z-10">
                    <div className="text-center">
                      <div className="w-8 h-8 sm:w-10 sm:h-10 lg:w-12 lg:h-12 border-4 border-white/30 border-t-white rounded-full animate-spin mx-auto"></div>
                    </div>
                  </div>
                )}

                {/* Error State */}
                {imageError && !physicalCard?.is_frozen && (
                  <div className="absolute inset-0 bg-gradient-to-br from-slate-800 via-slate-700 to-slate-900 rounded-2xl sm:rounded-3xl lg:rounded-[2rem] flex items-center justify-center z-10">
                    <div className="text-center">
                      <CreditCard className="w-8 h-8 sm:w-10 sm:h-10 lg:w-12 lg:h-12 text-white/60 mx-auto mb-2" />
                      <p className="text-white/80 text-xs sm:text-sm lg:text-base font-medium">
                        VISA Premium Card
                      </p>
                    </div>
                  </div>
                )}

                {/* Enhanced Frozen Overlay */}
                {physicalCard?.is_frozen && (
                  <div className="absolute inset-0 bg-gray-900/70 backdrop-blur-md rounded-2xl sm:rounded-3xl lg:rounded-[2rem] flex items-center justify-center z-20">
                    <div className="text-center">
                      <Lock className="w-8 h-8 sm:w-10 sm:h-10 lg:w-14 lg:h-14 text-red-400 mx-auto mb-2 sm:mb-3" />
                      <p className="text-red-400 font-bold text-sm sm:text-base lg:text-xl">
                        البطاقة مجمدة
                      </p>
                      <p className="text-gray-300 text-xs sm:text-sm lg:text-base">
                        Card Frozen
                      </p>
                    </div>
                  </div>
                )}

                {/* Card Content - Enhanced Layout */}
                <div className="relative z-10 h-full flex flex-col p-5 sm:p-6 lg:p-8">
                  {/* Card Number - Perfect Positioning */}
                  <div className="mt-4 sm:mt-6 lg:mt-8 mb-8 sm:mb-10 lg:mb-12 flex justify-center">
                    <div className="flex items-center gap-2 sm:gap-3 lg:gap-4">
                      <div
                        className="text-sm sm:text-lg md:text-xl lg:text-2xl xl:text-3xl font-mono tracking-wide sm:tracking-wider lg:tracking-widest text-white drop-shadow-2xl cursor-pointer hover:text-white/90 transition-all duration-300 p-2 sm:p-3 lg:p-4 rounded-lg sm:rounded-xl lg:rounded-2xl hover:bg-white/15 font-bold select-none"
                        onClick={copyCardNumber}
                        title="انقر لنسخ رقم البطاقة"
                      >
                        {showCardDetails
                          ? (
                              physicalCard?.card_number ||
                              generateSecureCardNumber()
                            )
                              .replace(/(\d{4})/g, "$1 ")
                              .trim()
                          : physicalCard?.card_number
                            ? maskCardNumber(physicalCard.card_number)
                            : "**** **** **** 1234"}
                      </div>
                      <Button
                        onClick={() => setShowCardDetails(!showCardDetails)}
                        variant="ghost"
                        size="sm"
                        className="text-white hover:bg-white/25 p-2 sm:p-3 lg:p-4 rounded-lg sm:rounded-xl lg:rounded-2xl transition-all duration-300"
                      >
                        {showCardDetails ? (
                          <EyeOff className="w-4 h-4 sm:w-5 sm:h-5 lg:w-6 lg:h-6" />
                        ) : (
                          <Eye className="w-4 h-4 sm:w-5 sm:h-5 lg:w-6 lg:h-6" />
                        )}
                      </Button>
                    </div>
                  </div>

                  {/* Card Details - Improved Layout with Higher Expiration Date */}
                  <div className="flex justify-between items-start mt-auto mb-2 sm:mb-3 lg:mb-4">
                    <div className="text-left flex flex-col flex-1">
                      <div className="text-[10px] sm:text-xs lg:text-sm text-white/80 font-medium mb-1 tracking-wide">
                        CARDHOLDER NAME
                      </div>
                      <div
                        className="text-xs sm:text-sm md:text-base lg:text-lg xl:text-xl font-mono font-bold text-white drop-shadow-lg cursor-pointer hover:text-white/80 transition-all duration-200 p-1 sm:p-2 lg:p-2 rounded-md hover:bg-white/10 truncate tracking-wide text-left select-none"
                        onClick={copyCardholderName}
                        title="انقر لنسخ اسم حامل البطاقة"
                      >
                        {user?.user_metadata?.full_name ||
                          user?.profile?.full_name ||
                          user?.email?.split("@")[0] ||
                          "اسم المستخدم"}
                      </div>
                    </div>
                    <div className="text-right flex flex-col ml-3 sm:ml-4 lg:ml-6 -mt-1 sm:-mt-2 lg:-mt-3">
                      <div className="text-[10px] sm:text-xs lg:text-sm text-white/80 font-medium mb-1 tracking-wide">
                        VALID THRU
                      </div>
                      <div className="text-xs sm:text-sm md:text-base lg:text-lg xl:text-xl font-mono font-bold text-white drop-shadow-lg tracking-wide">
                        12/28
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Enhanced Action Buttons - Investment Style */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6 justify-center">
          {!cardRequested && (
            <Button
              onClick={() => setShowRequestCardDialog(true)}
              className="bg-purple-500/25 hover:bg-purple-500/40 border border-purple-400/40 text-white backdrop-blur-md transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105 rounded-lg sm:rounded-xl px-4 sm:px-6 py-3 text-sm sm:text-base w-full sm:w-auto"
            >
              <MapPin className="w-4 h-4 sm:w-5 sm:h-5 mr-2" />
              طلب البطاقة
            </Button>
          )}

          {cardRequested && !cardActivated && (
            <Button
              onClick={() => setShowActivateCardDialog(true)}
              className="bg-emerald-500/25 hover:bg-emerald-500/40 border border-emerald-400/40 text-white backdrop-blur-md transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105 rounded-lg sm:rounded-xl px-4 sm:px-6 py-3 text-sm sm:text-base w-full sm:w-auto"
            >
              <CheckCircle className="w-4 h-4 sm:w-5 sm:h-5 mr-2" />
              تفعيل البطاقة
            </Button>
          )}

          {cardActivated && (
            <>
              <Button
                onClick={() => setShowChargeDialog(true)}
                className="bg-green-500/25 hover:bg-green-500/40 border border-green-400/40 text-white backdrop-blur-md transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105 rounded-lg sm:rounded-xl px-4 sm:px-6 py-3 text-sm sm:text-base w-full sm:w-auto"
              >
                <Plus className="w-4 h-4 sm:w-5 sm:h-5 mr-2" />
                شحن البطاقة
              </Button>

              <Button
                onClick={() => setShowFreezeDialog(true)}
                className={`${
                  physicalCard?.is_frozen
                    ? "bg-green-500/25 hover:bg-green-500/40 border-green-400/40"
                    : "bg-red-500/25 hover:bg-red-500/40 border-red-400/40"
                } text-white backdrop-blur-md transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105 rounded-lg sm:rounded-xl px-4 sm:px-6 py-3 text-sm sm:text-base w-full sm:w-auto`}
              >
                {physicalCard?.is_frozen ? (
                  <Unlock className="w-4 h-4 sm:w-5 sm:h-5 mr-2" />
                ) : (
                  <Lock className="w-4 h-4 sm:w-5 sm:h-5 mr-2" />
                )}
                {physicalCard?.is_frozen ? "إلغاء التجميد" : "تجميد البطاقة"}
              </Button>

              <Button
                onClick={() => setShowSettingsDialog(true)}
                className="bg-blue-500/25 hover:bg-blue-500/40 border border-blue-400/40 text-white backdrop-blur-md transition-all duration-300 shadow-lg hover:shadow-xl transform hover:scale-105 rounded-lg sm:rounded-xl px-4 sm:px-6 py-3 text-sm sm:text-base w-full sm:w-auto"
              >
                <Settings className="w-4 h-4 sm:w-5 sm:h-5 mr-2" />
                إعدادات البطاقة
              </Button>
            </>
          )}
        </div>

        {/* Mobile-Optimized Card Status Messages */}
        {cardRequested && !cardActivated && (
          <div className="mt-4 sm:mt-8 bg-gradient-to-r from-blue-500/20 via-purple-500/20 to-pink-500/20 backdrop-blur-md rounded-xl sm:rounded-2xl p-4 sm:p-6 border border-white/30 shadow-2xl text-center">
            <div className="flex items-center justify-center gap-2 sm:gap-3 mb-3 sm:mb-4">
              <div className="p-1.5 sm:p-2 bg-blue-500/30 rounded-lg sm:rounded-xl backdrop-blur-sm border border-blue-400/40">
                <Clock className="w-4 h-4 sm:w-6 sm:h-6 text-blue-300" />
              </div>
              <h3 className="text-white text-base sm:text-xl font-bold">
                البطاقة في الطريق إليك
              </h3>
            </div>
            <p className="text-white/80 text-sm sm:text-lg mb-2">
              تم طلب البطاقة بنجاح وسيتم توصيلها خلال 20-35 يوم
            </p>
            <p className="text-white/60 text-xs sm:text-sm">
              العنوان: {deliveryAddress}, {deliveryCountry}
            </p>
          </div>
        )}

        {cardActivated && (
          <div className="mt-4 sm:mt-8 bg-gradient-to-r from-green-500/20 via-emerald-500/20 to-teal-500/20 backdrop-blur-md rounded-xl sm:rounded-2xl p-4 sm:p-6 border border-white/30 shadow-2xl text-center">
            <div className="flex items-center justify-center gap-2 sm:gap-3 mb-3 sm:mb-4">
              <div className="p-1.5 sm:p-2 bg-green-500/30 rounded-lg sm:rounded-xl backdrop-blur-sm border border-green-400/40">
                <CheckCircle className="w-4 h-4 sm:w-6 sm:h-6 text-green-300" />
              </div>
              <h3 className="text-white text-base sm:text-xl font-bold">
                البطاقة مفعلة ومتاحة للاستخدام
              </h3>
            </div>
            <p className="text-white/80 text-sm sm:text-lg">
              يمكنك الآن استخدام البطاقة في جميع المعاملات
            </p>
          </div>
        )}
      </div>
      {/* Freeze Card Dialog */}
      <AlertDialog open={showFreezeDialog} onOpenChange={setShowFreezeDialog}>
        <AlertDialogContent className="bg-gradient-to-br from-slate-900/95 via-red-900/95 to-slate-900/95 backdrop-blur-md border border-red-400/30 text-white max-w-md mx-auto">
          <AlertDialogHeader className="text-center">
            <AlertDialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              {physicalCard?.is_frozen ? (
                <Unlock className="w-6 h-6 text-green-400" />
              ) : (
                <Lock className="w-6 h-6 text-red-400" />
              )}
              {physicalCard?.is_frozen
                ? "إلغاء تجميد البطاقة"
                : "تجميد البطاقة"}
            </AlertDialogTitle>
            <AlertDialogDescription className="text-gray-300">
              {physicalCard?.is_frozen
                ? "هل أنت متأكد من إلغاء تجميد البطاقة؟"
                : "هل أنت متأكد من تجميد البطاقة؟"}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <div
            className={`${physicalCard?.is_frozen ? "bg-green-500/20 border-green-400/30" : "bg-red-500/20 border-red-400/30"} rounded-lg p-4 my-4`}
          >
            <p
              className={`${physicalCard?.is_frozen ? "text-green-200" : "text-red-200"} text-sm text-center`}
            >
              {physicalCard?.is_frozen
                ? "ستتمكن من استخدام البطاقة بعد إلغاء التجميد."
                : "لن تتمكن من استخدام البطاقة حتى إلغاء التجميد. يمكنك إلغاء التجميد في أي وقت."}
            </p>
          </div>
          <AlertDialogFooter className="flex gap-3">
            <AlertDialogCancel className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60">
              إلغاء
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleFreezeCard}
              className={`flex-1 h-12 ${
                physicalCard?.is_frozen
                  ? "bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700"
                  : "bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700"
              } text-white`}
            >
              {physicalCard?.is_frozen ? "إلغاء التجميد" : "تجميد البطاقة"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
      {/* Charge Card Dialog */}
      <Dialog open={showChargeDialog} onOpenChange={setShowChargeDialog}>
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-green-900/95 to-slate-900/95 backdrop-blur-md border border-green-400/30 text-white max-w-lg mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <Plus className="w-6 h-6 text-green-400" />
              شحن البطاقة
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              حول الأموال من حسابك الرئيسي إلى البطاقة
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-6">
            {/* Currency Selection */}
            <div className="space-y-3">
              <Label className="text-white font-medium">
                اختر العملة من حسابك الرئيسي
              </Label>
              <Select
                value={selectedCurrency}
                onValueChange={setSelectedCurrency}
              >
                <SelectTrigger className="bg-white/10 border-white/30 text-white h-12">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent className="bg-slate-800 border-slate-600">
                  <SelectItem
                    value="dzd"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    <div className="flex justify-between items-center w-full">
                      <span>دينار جزائري (DZD)</span>
                      <span className="text-green-400 font-bold">
                        {fullBalance.dzd?.toLocaleString() || 0} دج
                      </span>
                    </div>
                  </SelectItem>
                  <SelectItem
                    value="eur"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    <div className="flex justify-between items-center w-full">
                      <span>يورو (EUR)</span>
                      <span className="text-green-400 font-bold">
                        €{fullBalance.eur?.toFixed(2) || "0.00"}
                      </span>
                    </div>
                  </SelectItem>
                  <SelectItem
                    value="usd"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    <div className="flex justify-between items-center w-full">
                      <span>دولار أمريكي (USD)</span>
                      <span className="text-green-400 font-bold">
                        ${fullBalance.usd?.toFixed(2) || "0.00"}
                      </span>
                    </div>
                  </SelectItem>
                  <SelectItem
                    value="gbp"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    <div className="flex justify-between items-center w-full">
                      <span>جنيه إسترليني (GBP)</span>
                      <span className="text-green-400 font-bold">
                        £{fullBalance.gbp?.toFixed(2) || "0.00"}
                      </span>
                    </div>
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Amount Input */}
            <div className="space-y-3">
              <Label className="text-white font-medium">
                المبلغ المراد تحويله
              </Label>
              <Input
                type="number"
                placeholder="أدخل المبلغ"
                value={chargeAmount}
                onChange={(e) => setChargeAmount(e.target.value)}
                className="text-center text-xl bg-white/10 border-white/30 text-white placeholder:text-gray-400 h-14 focus:border-green-400 focus:ring-green-400"
              />
              <div className="flex justify-between text-xs text-gray-400">
                <span>
                  الحد الأدنى: 10 {getCurrencySymbol(selectedCurrency)}
                </span>
                <span>
                  المتاح:{" "}
                  {fullBalance[
                    selectedCurrency as keyof typeof fullBalance
                  ]?.toLocaleString() || 0}{" "}
                  {getCurrencySymbol(selectedCurrency)}
                </span>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-3 pt-2">
              <Button
                onClick={() => {
                  setShowChargeDialog(false);
                  setChargeAmount("");
                  setSelectedCurrency("dzd");
                }}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
              >
                إلغاء
              </Button>
              <Button
                onClick={handleChargeCard}
                disabled={
                  !chargeAmount ||
                  parseFloat(chargeAmount) <= 0 ||
                  parseFloat(chargeAmount) >
                    (fullBalance[
                      selectedCurrency as keyof typeof fullBalance
                    ] || 0)
                }
                className="flex-1 h-12 bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 font-bold"
              >
                تأكيد الشحن
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
      {/* Settings Dialog */}
      <Dialog open={showSettingsDialog} onOpenChange={setShowSettingsDialog}>
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-blue-900/95 to-slate-900/95 backdrop-blur-md border border-blue-400/30 text-white max-w-md mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <Settings className="w-6 h-6 text-blue-400" />
              إعدادات البطاقة
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              إدارة إعدادات وخصائص البطاقة
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 mt-6">
            <div className="bg-blue-500/20 border border-blue-400/30 rounded-lg p-4">
              <h3 className="text-white font-semibold mb-2">معلومات البطاقة</h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-300">نوع البطاقة:</span>
                  <span className="text-white">VISA Premium</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-300">الحالة:</span>
                  <span
                    className={
                      physicalCard?.is_frozen
                        ? "text-red-400"
                        : "text-green-400"
                    }
                  >
                    {physicalCard?.is_frozen ? "مجمدة" : "نشطة"}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-300">حد الإنفاق اليومي:</span>
                  <span className="text-white">50,000 دج</span>
                </div>
              </div>
            </div>

            <Button
              onClick={() => setShowSettingsDialog(false)}
              className="w-full h-12 bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700"
            >
              إغلاق
            </Button>
          </div>
        </DialogContent>
      </Dialog>
      {/* Request Card Dialog */}
      <Dialog
        open={showRequestCardDialog}
        onOpenChange={setShowRequestCardDialog}
      >
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-purple-900/95 to-slate-900/95 backdrop-blur-md border border-purple-400/30 text-white max-w-lg mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <MapPin className="w-6 h-6 text-purple-400" />
              طلب البطاقة المصرفية
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              أدخل عنوان التوصيل لإرسال البطاقة إليك
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-6">
            {/* Country Selection */}
            <div className="space-y-3">
              <Label className="text-white font-medium">البلد</Label>
              <Select
                value={deliveryCountry}
                onValueChange={setDeliveryCountry}
              >
                <SelectTrigger className="bg-white/10 border-white/30 text-white h-12">
                  <SelectValue placeholder="اختر البلد" />
                </SelectTrigger>
                <SelectContent className="bg-slate-800 border-slate-600">
                  <SelectItem
                    value="algeria"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    الجزائر
                  </SelectItem>
                  <SelectItem
                    value="tunisia"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    تونس
                  </SelectItem>
                  <SelectItem
                    value="morocco"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    المغرب
                  </SelectItem>
                  <SelectItem
                    value="egypt"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    مصر
                  </SelectItem>
                  <SelectItem
                    value="saudi"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    السعودية
                  </SelectItem>
                  <SelectItem
                    value="uae"
                    className="text-white hover:bg-slate-700 py-3"
                  >
                    الإمارات
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Address Input */}
            <div className="space-y-3">
              <Label className="text-white font-medium">العنوان الكامل</Label>
              <textarea
                placeholder="أدخل العنوان الكامل للتوصيل..."
                value={deliveryAddress}
                onChange={(e) => setDeliveryAddress(e.target.value)}
                className="w-full h-24 bg-white/10 border border-white/30 text-white placeholder:text-gray-400 rounded-lg p-3 focus:border-purple-400 focus:ring-purple-400 resize-none"
              />
            </div>

            {/* Delivery Time Info */}
            <div className="bg-purple-500/20 border border-purple-400/30 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <Clock className="w-5 h-5 text-purple-400" />
                <h3 className="text-white font-semibold">مدة التوصيل</h3>
              </div>
              <p className="text-purple-200 text-sm">
                سيتم توصيل البطاقة خلال 20-35 يوم عمل إلى العنوان المحدد
              </p>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-3 pt-2">
              <Button
                onClick={() => {
                  setShowRequestCardDialog(false);
                  setDeliveryCountry("");
                  setDeliveryAddress("");
                }}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
              >
                إلغاء
              </Button>
              <Button
                onClick={() => {
                  if (deliveryCountry && deliveryAddress.trim()) {
                    setCardRequested(true);
                    setShowRequestCardDialog(false);
                    const notification = createNotification(
                      "success",
                      "تم طلب البطاقة بنجاح",
                      "سيتم توصيل البطاقة خلال 20-35 يوم عمل",
                    );
                    showBrowserNotification(
                      "تم طلب البطاقة بنجاح",
                      "سيتم توصيل البطاقة خلال 20-35 يوم عمل",
                    );
                  }
                }}
                disabled={!deliveryCountry || !deliveryAddress.trim()}
                className="flex-1 h-12 bg-gradient-to-r from-purple-500 to-purple-600 hover:from-purple-600 hover:to-purple-700 font-bold"
              >
                تأكيد الطلب
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
      {/* Activate Card Dialog */}
      <Dialog
        open={showActivateCardDialog}
        onOpenChange={setShowActivateCardDialog}
      >
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-emerald-900/95 to-slate-900/95 backdrop-blur-md border border-emerald-400/30 text-white max-w-md mx-auto">
          <DialogHeader className="text-center">
            <DialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <CheckCircle className="w-6 h-6 text-emerald-400" />
              تفعيل البطاقة
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              أدخل رمز CVV الموجود خلف البطاقة لتفعيلها
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-6">
            {/* CVV Input */}
            <div className="space-y-3">
              <Label className="text-white font-medium">
                رمز CVV (3 أرقام)
              </Label>
              <Input
                type="text"
                placeholder="123"
                value={cvvCode}
                onChange={(e) => {
                  const value = e.target.value.replace(/\D/g, "").slice(0, 3);
                  setCvvCode(value);
                  // Clear error when user starts typing
                  if (cvvError) setCvvError("");
                }}
                className="text-center text-2xl bg-white/10 border-white/30 text-white placeholder:text-gray-400 h-14 focus:border-emerald-400 focus:ring-emerald-400 tracking-widest font-mono"
                maxLength={3}
              />
              <p className="text-xs text-gray-400 text-center">
                الرمز المكون من 3 أرقام الموجود خلف البطاقة
              </p>
              {cvvError && (
                <div className="bg-red-500/20 border border-red-400/30 rounded-lg p-3 mt-2">
                  <p className="text-red-300 text-sm text-center font-medium">
                    {cvvError}
                  </p>
                </div>
              )}
            </div>

            {/* Info Box */}
            <div className="bg-emerald-500/20 border border-emerald-400/30 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <Shield className="w-5 h-5 text-emerald-400" />
                <h3 className="text-white font-semibold">تأمين البطاقة</h3>
              </div>
              <p className="text-emerald-200 text-sm">
                رمز CVV يضمن أمان البطاقة ويمنع الاستخدام غير المصرح به
              </p>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-3 pt-2">
              <Button
                onClick={() => {
                  setShowActivateCardDialog(false);
                  setCvvCode("");
                  setCvvError("");
                }}
                variant="outline"
                className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
              >
                إلغاء
              </Button>
              <Button
                onClick={() => {
                  if (cvvCode.length === 3) {
                    // Simulate CVV validation - in real app, this would be validated against the actual card CVV
                    const correctCVV = "123"; // This would come from the card data in a real application

                    if (cvvCode === correctCVV) {
                      setCardActivated(true);
                      setShowActivateCardDialog(false);
                      setCvvCode("");
                      setCvvError("");
                      const notification = createNotification(
                        "success",
                        "تم تفعيل البطاقة بنجاح",
                        "البطاقة جاهزة للاستخدام في جميع المعاملات",
                      );
                      showBrowserNotification(
                        "تم تفعيل البطاقة بنجاح",
                        "البطاقة جاهزة للاستخدام في جميع المعاملات",
                      );
                    } else {
                      setCvvError(
                        "الرمز خاطئ. تأكد من الرمز الموجود خلف البطاقة",
                      );
                      // Clear error after 3 seconds
                      setTimeout(() => setCvvError(""), 3000);
                    }
                  }
                }}
                disabled={cvvCode.length !== 3}
                className="flex-1 h-12 bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 font-bold"
              >
                تفعيل البطاقة
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}

export default CardTab;
