import { useState, useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Button } from "./ui/button";
import {
  History,
  Zap,
  ArrowUpRight,
  ArrowDownLeft,
  Clock,
  CheckCircle,
  AlertCircle,
  Filter,
  Search,
  Calendar,
  TrendingUp,
  Send,
  Wallet,
} from "lucide-react";
import { Input } from "./ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";
import { useAuth } from "../hooks/useAuth";
import { useDatabase } from "../hooks/useDatabase";
import { maskBalance, isDataLoaded } from "../utils/security";

interface Transaction {
  id: string;
  type: string;
  amount: number;
  currency: string;
  description: string;
  reference?: string;
  recipient?: string;
  status: string;
  created_at: string;
  is_sender?: boolean;
  recipient_name?: string;
  sender_name?: string;
  processing_time_ms?: number;
}

interface InstantTransferHistoryTabProps {
  transactions?: Transaction[];
}

function InstantTransferHistoryTab({
  transactions: propTransactions,
}: InstantTransferHistoryTabProps) {
  const { user } = useAuth();
  const { getInstantTransferHistory, transactions: dbTransactions } =
    useDatabase(user?.id || null);

  const [instantTransfers, setInstantTransfers] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState("all");
  const [searchTerm, setSearchTerm] = useState("");
  const [sortBy, setSortBy] = useState("date");

  // Load instant transfer history
  useEffect(() => {
    const loadHistory = async () => {
      if (!user?.id) return;

      setLoading(true);
      try {
        const { data } = await getInstantTransferHistory(100);
        if (data) {
          setInstantTransfers(data);
        }
      } catch (error) {
        console.error("Error loading instant transfer history:", error);
      } finally {
        setLoading(false);
      }
    };

    loadHistory();
  }, [user?.id, getInstantTransferHistory]);

  // Combine all transactions
  const allTransactions = [
    ...instantTransfers.map((transfer) => ({
      id: transfer.id,
      type: transfer.is_sender ? "transfer_sent" : "instant_transfer_received",
      amount: transfer.is_sender ? -transfer.amount : transfer.amount,
      currency: transfer.currency,
      description:
        transfer.description ||
        (transfer.is_sender ? "تحويل صادر" : "تحويل وارد"),
      reference: transfer.reference_number,
      recipient: transfer.is_sender
        ? transfer.recipient_email
        : transfer.sender_email,
      status: transfer.status,
      created_at: transfer.created_at,
      is_sender: transfer.is_sender,
      recipient_name: transfer.recipient_name,
      sender_name: transfer.sender_name,
      processing_time_ms: transfer.processing_time_ms,
    })),
    ...(dbTransactions || []).filter(
      (t) => !t.type.includes("instant_transfer"),
    ),
  ];

  // Filter and sort transactions
  const filteredTransactions = allTransactions
    .filter((transaction) => {
      if (
        filter === "sent" &&
        !transaction.type.includes("sent") &&
        transaction.amount >= 0
      )
        return false;
      if (
        filter === "received" &&
        !transaction.type.includes("received") &&
        transaction.amount <= 0
      )
        return false;
      if (
        filter === "instant" &&
        !transaction.type.includes("instant_transfer")
      )
        return false;
      if (
        searchTerm &&
        !transaction.description
          .toLowerCase()
          .includes(searchTerm.toLowerCase()) &&
        !transaction.reference?.toLowerCase().includes(searchTerm.toLowerCase())
      )
        return false;
      return true;
    })
    .sort((a, b) => {
      switch (sortBy) {
        case "amount":
          return Math.abs(b.amount) - Math.abs(a.amount);
        case "type":
          return a.type.localeCompare(b.type);
        default:
          return (
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
          );
      }
    });

  const getTransactionIcon = (type: string, amount: number) => {
    if (type.includes("instant_transfer")) {
      return (
        <Zap
          className={`w-5 h-5 ${amount > 0 ? "text-emerald-400" : "text-purple-400"}`}
        />
      );
    }
    switch (type) {
      case "recharge":
        return <ArrowDownLeft className="w-5 h-5 text-green-400" />;
      case "transfer":
        return amount > 0 ? (
          <ArrowDownLeft className="w-5 h-5 text-blue-400" />
        ) : (
          <ArrowUpRight className="w-5 h-5 text-orange-400" />
        );
      default:
        return <Wallet className="w-5 h-5 text-gray-400" />;
    }
  };

  const getTransactionLabel = (
    type: string,
    amount: number,
    isInstant: boolean,
  ) => {
    if (isInstant) {
      return amount > 0 ? "تحويل مستلم" : "تحويل مرسل";
    }
    switch (type) {
      case "recharge":
        return "شحن المحفظة";
      case "transfer":
        return amount > 0 ? "تحويل مستلم" : "تحويل مرسل";
      case "conversion":
        return "تحويل عملة";
      default:
        return "عملية مالية";
    }
  };

  const getTransactionColor = (type: string, amount: number) => {
    if (type.includes("instant_transfer")) {
      return amount > 0
        ? "border-emerald-400/30 bg-emerald-500/10"
        : "border-purple-400/30 bg-purple-500/10";
    }
    switch (type) {
      case "recharge":
        return "border-green-400/30 bg-green-500/10";
      case "transfer":
        return amount > 0
          ? "border-blue-400/30 bg-blue-500/10"
          : "border-orange-400/30 bg-orange-500/10";
      default:
        return "border-gray-400/30 bg-gray-500/10";
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "completed":
        return <CheckCircle className="w-4 h-4 text-green-400" />;
      case "pending":
        return <Clock className="w-4 h-4 text-yellow-400" />;
      case "failed":
        return <AlertCircle className="w-4 h-4 text-red-400" />;
      default:
        return <Clock className="w-4 h-4 text-gray-400" />;
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case "completed":
        return "مكتملة";
      case "pending":
        return "قيد المعالجة";
      case "failed":
        return "فاشلة";
      default:
        return "غير معروف";
    }
  };

  // Calculate statistics
  const stats = {
    total: filteredTransactions.length,
    instant: filteredTransactions.filter((t) =>
      t.type.includes("instant_transfer"),
    ).length,
    sent: filteredTransactions.filter((t) => t.amount < 0).length,
    received: filteredTransactions.filter((t) => t.amount > 0).length,
    totalAmount: filteredTransactions.reduce(
      (sum, t) => sum + Math.abs(t.amount),
      0,
    ),
  };

  return (
    <div className="space-y-6 pb-20 px-2 sm:px-0">
      {/* Header */}
      <div className="text-center mb-8">
        <div className="flex items-center justify-center mb-4">
          <div className="w-16 h-16 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-2xl flex items-center justify-center shadow-lg">
            <History className="w-8 h-8 text-white" />
          </div>
        </div>
        <h2 className="text-3xl font-bold text-white mb-2">سجل المعاملات</h2>
        <p className="text-gray-300 text-lg">
          تاريخ جميع العمليات المالية والتحويلات
        </p>
      </div>

      {/* Statistics Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <Card className="bg-gradient-to-br from-blue-500/20 to-cyan-600/20 backdrop-blur-md border border-blue-400/30">
          <CardContent className="p-4 text-center">
            <History className="w-6 h-6 text-blue-400 mx-auto mb-2" />
            <p className="text-blue-200 text-xs mb-1">إجمالي المعاملات</p>
            <p className="text-white font-bold text-lg">{stats.total}</p>
          </CardContent>
        </Card>
        <Card className="bg-gradient-to-br from-purple-500/20 to-pink-600/20 backdrop-blur-md border border-purple-400/30">
          <CardContent className="p-4 text-center">
            <Zap className="w-6 h-6 text-purple-400 mx-auto mb-2" />
            <p className="text-purple-200 text-xs mb-1">التحويلات</p>
            <p className="text-white font-bold text-lg">{stats.instant}</p>
          </CardContent>
        </Card>
        <Card className="bg-gradient-to-br from-green-500/20 to-emerald-600/20 backdrop-blur-md border border-green-400/30">
          <CardContent className="p-4 text-center">
            <ArrowDownLeft className="w-6 h-6 text-green-400 mx-auto mb-2" />
            <p className="text-green-200 text-xs mb-1">مستلمة</p>
            <p className="text-white font-bold text-lg">{stats.received}</p>
          </CardContent>
        </Card>
        <Card className="bg-gradient-to-br from-orange-500/20 to-red-600/20 backdrop-blur-md border border-orange-400/30">
          <CardContent className="p-4 text-center">
            <ArrowUpRight className="w-6 h-6 text-orange-400 mx-auto mb-2" />
            <p className="text-orange-200 text-xs mb-1">مرسلة</p>
            <p className="text-white font-bold text-lg">{stats.sent}</p>
          </CardContent>
        </Card>
      </div>

      {/* Filters and Search */}
      <Card className="bg-gradient-to-br from-gray-800/50 to-gray-900/50 backdrop-blur-md border border-gray-600/30">
        <CardContent className="p-4">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
              <Input
                placeholder="البحث في المعاملات..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="bg-white/10 border-white/20 text-white placeholder:text-gray-400 pl-10"
              />
            </div>
            <Select value={filter} onValueChange={setFilter}>
              <SelectTrigger className="bg-white/10 border-white/20 text-white">
                <SelectValue placeholder="تصفية حسب النوع" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">جميع المعاملات</SelectItem>
                <SelectItem value="instant">التحويلات</SelectItem>
                <SelectItem value="sent">المرسلة</SelectItem>
                <SelectItem value="received">المستلمة</SelectItem>
              </SelectContent>
            </Select>
            <Select value={sortBy} onValueChange={setSortBy}>
              <SelectTrigger className="bg-white/10 border-white/20 text-white">
                <SelectValue placeholder="ترتيب حسب" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="date">التاريخ</SelectItem>
                <SelectItem value="amount">المبلغ</SelectItem>
                <SelectItem value="type">النوع</SelectItem>
              </SelectContent>
            </Select>
            <Button
              variant="outline"
              onClick={() => {
                setFilter("all");
                setSearchTerm("");
                setSortBy("date");
              }}
              className="bg-white/10 border-white/20 text-white hover:bg-white/20"
            >
              <Filter className="w-4 h-4 mr-2" />
              إعادة تعيين
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Transactions List */}
      <Card className="bg-white/10 backdrop-blur-md shadow-xl border border-white/20 text-white">
        <CardHeader className="pb-4">
          <CardTitle className="text-white text-xl flex items-center gap-2">
            <History className="w-6 h-6" />
            <span>المعاملات ({filteredTransactions.length})</span>
          </CardTitle>
        </CardHeader>
        <CardContent className="pt-0">
          {loading ? (
            <div className="text-center py-8">
              <div className="w-8 h-8 border-2 border-white/30 border-t-white rounded-full animate-spin mx-auto mb-4"></div>
              <p className="text-gray-400">جاري تحميل المعاملات...</p>
            </div>
          ) : filteredTransactions.length > 0 ? (
            <div className="space-y-3">
              {filteredTransactions.map((transaction) => {
                const isInstant = transaction.type.includes("instant_transfer");
                return (
                  <div
                    key={transaction.id}
                    className={`p-4 rounded-lg border backdrop-blur-sm transition-all duration-200 hover:scale-[1.02] ${getTransactionColor(transaction.type, transaction.amount)}`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3 min-w-0 flex-1">
                        {getTransactionIcon(
                          transaction.type,
                          transaction.amount,
                        )}
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-2 mb-1">
                            <p className="font-semibold text-white text-base truncate">
                              {getTransactionLabel(
                                transaction.type,
                                transaction.amount,
                                isInstant,
                              )}
                            </p>
                            {isInstant && (
                              <span className="bg-gradient-to-r from-purple-500 to-pink-500 text-white text-xs px-2 py-1 rounded-full font-bold">
                                ⚡ فوري
                              </span>
                            )}
                          </div>
                          <p className="text-sm text-gray-300 truncate">
                            {transaction.description}
                          </p>
                          <div className="flex items-center gap-4 mt-1 text-xs text-gray-400">
                            <span className="flex items-center gap-1">
                              <Calendar className="w-3 h-3" />
                              {new Date(
                                transaction.created_at,
                              ).toLocaleDateString("ar-DZ", {
                                year: "numeric",
                                month: "short",
                                day: "numeric",
                                hour: "2-digit",
                                minute: "2-digit",
                              })}
                            </span>
                            {transaction.reference && (
                              <span className="font-mono">
                                {transaction.reference}
                              </span>
                            )}
                            {transaction.processing_time_ms && (
                              <span className="flex items-center gap-1">
                                <Zap className="w-3 h-3" />
                                {transaction.processing_time_ms}ms
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                      <div className="text-right flex-shrink-0">
                        <p
                          className={`font-bold text-lg ${
                            transaction.amount > 0
                              ? "text-green-400"
                              : "text-orange-400"
                          }`}
                        >
                          {loading
                            ? maskBalance(0)
                            : `${transaction.amount > 0 ? "+" : ""}${transaction.amount.toLocaleString()} دج`}
                        </p>
                        <div className="flex items-center gap-1 justify-end mt-1">
                          {getStatusIcon(transaction.status)}
                          <span className="text-xs text-gray-300">
                            {getStatusLabel(transaction.status)}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="text-center py-12">
              <History className="w-16 h-16 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-400 text-lg mb-2">
                {searchTerm || filter !== "all"
                  ? "لا توجد معاملات تطابق البحث"
                  : "لا توجد معاملات حتى الآن"}
              </p>
              <p className="text-gray-500 text-sm">
                {searchTerm || filter !== "all"
                  ? "جرب تغيير معايير البحث"
                  : "ابدأ باستخدام محفظتك لرؤية المعاملات هنا"}
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

export default InstantTransferHistoryTab;
