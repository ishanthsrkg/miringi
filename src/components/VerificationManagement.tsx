import { useState, useEffect } from "react";
import { useDatabase } from "../hooks/useDatabase";
import { useAuth } from "../hooks/useAuth";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "./ui/dialog";
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
import { Button } from "./ui/button";
import { Badge } from "./ui/badge";
import { Textarea } from "./ui/textarea";
import { Label } from "./ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "./ui/tabs";
import {
  Shield,
  Eye,
  CheckCircle,
  XCircle,
  Clock,
  FileText,
  User,
  Calendar,
  MapPin,
  Phone,
  Mail,
  Download,
  AlertTriangle,
  Search,
  Filter,
  RefreshCw,
  Image as ImageIcon,
} from "lucide-react";
import { Input } from "./ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";

interface VerificationManagementProps {
  className?: string;
}

interface VerificationRequest {
  verification_id: string;
  user_id: string;
  user_email: string;
  user_name: string;
  country: string;
  date_of_birth: string;
  full_address: string;
  postal_code: string;
  document_type: string;
  document_number: string;
  documents: any[];
  additional_notes: string;
  status: string;
  submitted_at: string;
  days_pending: number;
  reviewed_at?: string;
  admin_notes?: string;
}

interface VerificationStats {
  total_requests: number;
  pending_requests: number;
  approved_requests: number;
  rejected_requests: number;
  under_review_requests: number;
}

function VerificationManagement({
  className = "",
}: VerificationManagementProps) {
  const { user } = useAuth();
  const {
    getPendingVerifications,
    getVerificationDetails,
    approveVerification,
    rejectVerification,
    getVerificationStats,
  } = useDatabase(user?.id || null);

  const [verifications, setVerifications] = useState<VerificationRequest[]>([]);
  const [stats, setStats] = useState<VerificationStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [selectedVerification, setSelectedVerification] =
    useState<VerificationRequest | null>(null);
  const [showDetails, setShowDetails] = useState(false);
  const [showDocuments, setShowDocuments] = useState(false);
  const [showApproveDialog, setShowApproveDialog] = useState(false);
  const [showRejectDialog, setShowRejectDialog] = useState(false);
  const [adminNotes, setAdminNotes] = useState("");
  const [processing, setProcessing] = useState(false);
  const [filterStatus, setFilterStatus] = useState("all");
  const [searchTerm, setSearchTerm] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(10);

  // Load verification data
  const loadVerifications = async () => {
    setLoading(true);
    try {
      const [verificationsResult, statsResult] = await Promise.all([
        getPendingVerifications(100, 0),
        getVerificationStats(),
      ]);

      if (verificationsResult.data) {
        setVerifications(verificationsResult.data);
      }

      if (statsResult.data) {
        setStats(statsResult.data);
      }
    } catch (error) {
      console.error("Error loading verifications:", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadVerifications();
  }, []);

  // Filter verifications based on status and search term
  const filteredVerifications = verifications.filter((verification) => {
    const matchesStatus =
      filterStatus === "all" || verification.status === filterStatus;
    const matchesSearch =
      verification.user_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      verification.user_email
        .toLowerCase()
        .includes(searchTerm.toLowerCase()) ||
      verification.document_number
        .toLowerCase()
        .includes(searchTerm.toLowerCase());

    return matchesStatus && matchesSearch;
  });

  // Pagination
  const totalPages = Math.ceil(filteredVerifications.length / itemsPerPage);
  const startIndex = (currentPage - 1) * itemsPerPage;
  const paginatedVerifications = filteredVerifications.slice(
    startIndex,
    startIndex + itemsPerPage,
  );

  const handleViewDetails = async (verification: VerificationRequest) => {
    setSelectedVerification(verification);
    setShowDetails(true);
  };

  const handleViewDocuments = (verification: VerificationRequest) => {
    setSelectedVerification(verification);
    setShowDocuments(true);
  };

  const handleApprove = (verification: VerificationRequest) => {
    setSelectedVerification(verification);
    setAdminNotes("");
    setShowApproveDialog(true);
  };

  const handleReject = (verification: VerificationRequest) => {
    setSelectedVerification(verification);
    setAdminNotes("");
    setShowRejectDialog(true);
  };

  const confirmApprove = async () => {
    if (!selectedVerification) return;

    setProcessing(true);
    try {
      const result = await approveVerification(
        selectedVerification.verification_id,
        adminNotes,
        user?.id,
      );

      if (result.error) {
        console.error("Error approving verification:", result.error);
        alert("حدث خطأ في الموافقة على التوثيق");
      } else {
        alert("تم قبول طلب التوثيق بنجاح");
        await loadVerifications();
        setShowApproveDialog(false);
        setSelectedVerification(null);
        setAdminNotes("");
      }
    } catch (error) {
      console.error("Error in confirmApprove:", error);
      alert("حدث خطأ غير متوقع");
    } finally {
      setProcessing(false);
    }
  };

  const confirmReject = async () => {
    if (!selectedVerification) return;

    setProcessing(true);
    try {
      const result = await rejectVerification(
        selectedVerification.verification_id,
        adminNotes,
        user?.id,
      );

      if (result.error) {
        console.error("Error rejecting verification:", result.error);
        alert("حدث خطأ في رفض التوثيق");
      } else {
        alert("تم رفض طلب التوثيق");
        await loadVerifications();
        setShowRejectDialog(false);
        setSelectedVerification(null);
        setAdminNotes("");
      }
    } catch (error) {
      console.error("Error in confirmReject:", error);
      alert("حدث خطأ غير متوقع");
    } finally {
      setProcessing(false);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "pending":
        return (
          <Badge className="bg-yellow-500/20 text-yellow-400 border-yellow-400/30">
            <Clock className="w-3 h-3 mr-1" />
            قيد الانتظار
          </Badge>
        );
      case "under_review":
        return (
          <Badge className="bg-blue-500/20 text-blue-400 border-blue-400/30">
            <Eye className="w-3 h-3 mr-1" />
            تحت المراجعة
          </Badge>
        );
      case "approved":
        return (
          <Badge className="bg-green-500/20 text-green-400 border-green-400/30">
            <CheckCircle className="w-3 h-3 mr-1" />
            موافق عليه
          </Badge>
        );
      case "rejected":
        return (
          <Badge className="bg-red-500/20 text-red-400 border-red-400/30">
            <XCircle className="w-3 h-3 mr-1" />
            مرفوض
          </Badge>
        );
      default:
        return (
          <Badge className="bg-gray-500/20 text-gray-400 border-gray-400/30">
            غير محدد
          </Badge>
        );
    }
  };

  const downloadDocument = (document: any) => {
    if (document.data) {
      const link = document.createElement("a");
      link.href = document.data;
      link.download = document.name || "document";
      link.click();
    }
  };

  return (
    <div
      className={`min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 p-4 ${className}`}
    >
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
              <Shield className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">إدارة التوثيق</h1>
              <p className="text-gray-300 text-sm">
                مراجعة وإدارة طلبات توثيق الحسابات
              </p>
            </div>
          </div>
          <Button
            onClick={loadVerifications}
            disabled={loading}
            className="bg-blue-600 hover:bg-blue-700 text-white"
          >
            <RefreshCw
              className={`w-4 h-4 mr-2 ${loading ? "animate-spin" : ""}`}
            />
            تحديث
          </Button>
        </div>

        {/* Statistics Cards */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4 mb-6">
            <Card className="bg-white/10 backdrop-blur-md border border-white/20">
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-gray-300 text-sm">إجمالي الطلبات</p>
                    <p className="text-2xl font-bold text-white">
                      {stats.total_requests}
                    </p>
                  </div>
                  <FileText className="w-8 h-8 text-blue-400" />
                </div>
              </CardContent>
            </Card>

            <Card className="bg-white/10 backdrop-blur-md border border-white/20">
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-gray-300 text-sm">قيد الانتظار</p>
                    <p className="text-2xl font-bold text-yellow-400">
                      {stats.pending_requests}
                    </p>
                  </div>
                  <Clock className="w-8 h-8 text-yellow-400" />
                </div>
              </CardContent>
            </Card>

            <Card className="bg-white/10 backdrop-blur-md border border-white/20">
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-gray-300 text-sm">تحت المراجعة</p>
                    <p className="text-2xl font-bold text-blue-400">
                      {stats.under_review_requests}
                    </p>
                  </div>
                  <Eye className="w-8 h-8 text-blue-400" />
                </div>
              </CardContent>
            </Card>

            <Card className="bg-white/10 backdrop-blur-md border border-white/20">
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-gray-300 text-sm">موافق عليها</p>
                    <p className="text-2xl font-bold text-green-400">
                      {stats.approved_requests}
                    </p>
                  </div>
                  <CheckCircle className="w-8 h-8 text-green-400" />
                </div>
              </CardContent>
            </Card>

            <Card className="bg-white/10 backdrop-blur-md border border-white/20">
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-gray-300 text-sm">مرفوضة</p>
                    <p className="text-2xl font-bold text-red-400">
                      {stats.rejected_requests}
                    </p>
                  </div>
                  <XCircle className="w-8 h-8 text-red-400" />
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* Filters and Search */}
        <Card className="bg-white/10 backdrop-blur-md border border-white/20 mb-6">
          <CardContent className="p-4">
            <div className="flex flex-col md:flex-row gap-4">
              <div className="flex-1">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                  <Input
                    type="text"
                    placeholder="البحث بالاسم، البريد الإلكتروني، أو رقم الوثيقة..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 bg-white/10 border-white/30 text-white placeholder:text-gray-400"
                  />
                </div>
              </div>
              <div className="w-full md:w-48">
                <Select value={filterStatus} onValueChange={setFilterStatus}>
                  <SelectTrigger className="bg-white/10 border-white/30 text-white">
                    <Filter className="w-4 h-4 mr-2" />
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent className="bg-slate-800 border-slate-600">
                    <SelectItem
                      value="all"
                      className="text-white hover:bg-slate-700"
                    >
                      جميع الحالات
                    </SelectItem>
                    <SelectItem
                      value="pending"
                      className="text-white hover:bg-slate-700"
                    >
                      قيد الانتظار
                    </SelectItem>
                    <SelectItem
                      value="under_review"
                      className="text-white hover:bg-slate-700"
                    >
                      تحت المراجعة
                    </SelectItem>
                    <SelectItem
                      value="approved"
                      className="text-white hover:bg-slate-700"
                    >
                      موافق عليها
                    </SelectItem>
                    <SelectItem
                      value="rejected"
                      className="text-white hover:bg-slate-700"
                    >
                      مرفوضة
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Verification Requests Table */}
        <Card className="bg-white/10 backdrop-blur-md border border-white/20">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <FileText className="w-5 h-5" />
              طلبات التوثيق ({filteredVerifications.length})
            </CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="text-center py-8">
                <RefreshCw className="w-8 h-8 text-blue-400 mx-auto mb-3 animate-spin" />
                <p className="text-gray-300">جاري تحميل البيانات...</p>
              </div>
            ) : paginatedVerifications.length === 0 ? (
              <div className="text-center py-8">
                <FileText className="w-12 h-12 text-gray-400 mx-auto mb-3 opacity-50" />
                <p className="text-gray-400">لا توجد طلبات توثيق</p>
              </div>
            ) : (
              <div className="space-y-4">
                {paginatedVerifications.map((verification) => (
                  <div
                    key={verification.verification_id}
                    className="bg-white/5 border border-white/10 rounded-lg p-4 hover:bg-white/10 transition-colors"
                  >
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
                          <User className="w-5 h-5 text-white" />
                        </div>
                        <div>
                          <h3 className="text-white font-medium">
                            {verification.user_name}
                          </h3>
                          <p className="text-gray-300 text-sm">
                            {verification.user_email}
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        {getStatusBadge(verification.status)}
                        <Badge className="bg-gray-500/20 text-gray-300 border-gray-400/30">
                          {verification.days_pending} يوم
                        </Badge>
                      </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                      <div className="flex items-center gap-2 text-gray-300 text-sm">
                        <MapPin className="w-4 h-4" />
                        <span>{verification.country}</span>
                      </div>
                      <div className="flex items-center gap-2 text-gray-300 text-sm">
                        <FileText className="w-4 h-4" />
                        <span>
                          {verification.document_type === "national_id"
                            ? "بطاقة التعريف"
                            : verification.document_type === "passport"
                              ? "جواز السفر"
                              : "رخصة السياقة"}
                        </span>
                      </div>
                      <div className="flex items-center gap-2 text-gray-300 text-sm">
                        <Calendar className="w-4 h-4" />
                        <span>
                          {new Date(
                            verification.submitted_at,
                          ).toLocaleDateString("ar-SA")}
                        </span>
                      </div>
                    </div>

                    <div className="flex gap-2 flex-wrap">
                      <Button
                        onClick={() => handleViewDetails(verification)}
                        size="sm"
                        variant="outline"
                        className="bg-blue-500/20 border-blue-400/30 text-blue-400 hover:bg-blue-500/30"
                      >
                        <Eye className="w-4 h-4 mr-1" />
                        عرض التفاصيل
                      </Button>
                      <Button
                        onClick={() => handleViewDocuments(verification)}
                        size="sm"
                        variant="outline"
                        className="bg-purple-500/20 border-purple-400/30 text-purple-400 hover:bg-purple-500/30"
                      >
                        <ImageIcon className="w-4 h-4 mr-1" />
                        عرض الوثائق
                      </Button>
                      {(verification.status === "pending" ||
                        verification.status === "under_review") && (
                        <>
                          <Button
                            onClick={() => handleApprove(verification)}
                            size="sm"
                            className="bg-green-600 hover:bg-green-700 text-white"
                          >
                            <CheckCircle className="w-4 h-4 mr-1" />
                            موافقة
                          </Button>
                          <Button
                            onClick={() => handleReject(verification)}
                            size="sm"
                            variant="outline"
                            className="bg-red-500/20 border-red-400/30 text-red-400 hover:bg-red-500/30"
                          >
                            <XCircle className="w-4 h-4 mr-1" />
                            رفض
                          </Button>
                        </>
                      )}
                    </div>
                  </div>
                ))}

                {/* Pagination */}
                {totalPages > 1 && (
                  <div className="flex justify-center gap-2 mt-6">
                    <Button
                      onClick={() =>
                        setCurrentPage(Math.max(1, currentPage - 1))
                      }
                      disabled={currentPage === 1}
                      variant="outline"
                      size="sm"
                      className="bg-white/10 border-white/30 text-white hover:bg-white/20"
                    >
                      السابق
                    </Button>
                    <span className="flex items-center px-3 text-white">
                      {currentPage} من {totalPages}
                    </span>
                    <Button
                      onClick={() =>
                        setCurrentPage(Math.min(totalPages, currentPage + 1))
                      }
                      disabled={currentPage === totalPages}
                      variant="outline"
                      size="sm"
                      className="bg-white/10 border-white/30 text-white hover:bg-white/20"
                    >
                      التالي
                    </Button>
                  </div>
                )}
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Verification Details Dialog */}
      <Dialog open={showDetails} onOpenChange={setShowDetails}>
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-blue-900/95 to-slate-900/95 backdrop-blur-md border border-white/20 text-white max-w-2xl mx-auto max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="text-xl font-bold text-white flex items-center gap-2">
              <User className="w-6 h-6 text-blue-400" />
              تفاصيل طلب التوثيق
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              معلومات مفصلة عن طلب التوثيق
            </DialogDescription>
          </DialogHeader>

          {selectedVerification && (
            <div className="space-y-6 mt-6">
              {/* User Information */}
              <div className="bg-white/10 border border-white/20 rounded-lg p-4">
                <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                  <User className="w-5 h-5 text-blue-400" />
                  معلومات المستخدم
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <Label className="text-gray-300">الاسم الكامل</Label>
                    <p className="text-white font-medium">
                      {selectedVerification.user_name}
                    </p>
                  </div>
                  <div>
                    <Label className="text-gray-300">البريد الإلكتروني</Label>
                    <p className="text-white font-medium">
                      {selectedVerification.user_email}
                    </p>
                  </div>
                  <div>
                    <Label className="text-gray-300">البلد</Label>
                    <p className="text-white font-medium">
                      {selectedVerification.country}
                    </p>
                  </div>
                  <div>
                    <Label className="text-gray-300">تاريخ الميلاد</Label>
                    <p className="text-white font-medium">
                      {new Date(
                        selectedVerification.date_of_birth,
                      ).toLocaleDateString("ar-SA")}
                    </p>
                  </div>
                </div>
              </div>

              {/* Address Information */}
              <div className="bg-white/10 border border-white/20 rounded-lg p-4">
                <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                  <MapPin className="w-5 h-5 text-green-400" />
                  معلومات العنوان
                </h3>
                <div className="space-y-3">
                  <div>
                    <Label className="text-gray-300">العنوان الكامل</Label>
                    <p className="text-white font-medium">
                      {selectedVerification.full_address}
                    </p>
                  </div>
                  <div>
                    <Label className="text-gray-300">الرقم البريدي</Label>
                    <p className="text-white font-medium">
                      {selectedVerification.postal_code}
                    </p>
                  </div>
                </div>
              </div>

              {/* Document Information */}
              <div className="bg-white/10 border border-white/20 rounded-lg p-4">
                <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                  <FileText className="w-5 h-5 text-purple-400" />
                  معلومات الوثيقة
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <Label className="text-gray-300">نوع الوثيقة</Label>
                    <p className="text-white font-medium">
                      {selectedVerification.document_type === "national_id"
                        ? "بطاقة التعريف الوطنية"
                        : selectedVerification.document_type === "passport"
                          ? "جواز السفر"
                          : "رخصة السياقة"}
                    </p>
                  </div>
                  <div>
                    <Label className="text-gray-300">رقم الوثيقة</Label>
                    <p className="text-white font-medium">
                      {selectedVerification.document_number}
                    </p>
                  </div>
                </div>
              </div>

              {/* Additional Notes */}
              {selectedVerification.additional_notes && (
                <div className="bg-white/10 border border-white/20 rounded-lg p-4">
                  <h3 className="text-lg font-semibold text-white mb-4">
                    ملاحظات إضافية
                  </h3>
                  <p className="text-gray-300">
                    {selectedVerification.additional_notes}
                  </p>
                </div>
              )}

              {/* Status Information */}
              <div className="bg-white/10 border border-white/20 rounded-lg p-4">
                <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                  <Clock className="w-5 h-5 text-yellow-400" />
                  معلومات الحالة
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <Label className="text-gray-300">الحالة الحالية</Label>
                    <div className="mt-1">
                      {getStatusBadge(selectedVerification.status)}
                    </div>
                  </div>
                  <div>
                    <Label className="text-gray-300">تاريخ التقديم</Label>
                    <p className="text-white font-medium">
                      {new Date(
                        selectedVerification.submitted_at,
                      ).toLocaleString("ar-SA")}
                    </p>
                  </div>
                  <div>
                    <Label className="text-gray-300">أيام الانتظار</Label>
                    <p className="text-white font-medium">
                      {selectedVerification.days_pending} يوم
                    </p>
                  </div>
                </div>
              </div>
            </div>
          )}

          <div className="flex gap-3 mt-6">
            <Button
              onClick={() => setShowDetails(false)}
              className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
            >
              إغلاق
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Documents Viewer Dialog */}
      <Dialog open={showDocuments} onOpenChange={setShowDocuments}>
        <DialogContent className="bg-gradient-to-br from-slate-900/95 via-blue-900/95 to-slate-900/95 backdrop-blur-md border border-white/20 text-white max-w-4xl mx-auto max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="text-xl font-bold text-white flex items-center gap-2">
              <ImageIcon className="w-6 h-6 text-purple-400" />
              وثائق التوثيق
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              عرض وثائق العميل المرفوعة للتوثيق
            </DialogDescription>
          </DialogHeader>

          {selectedVerification && (
            <div className="space-y-6 mt-6">
              {selectedVerification.documents &&
              selectedVerification.documents.length > 0 ? (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {selectedVerification.documents.map(
                    (document: any, index: number) => (
                      <div
                        key={index}
                        className="bg-white/10 border border-white/20 rounded-lg p-4"
                      >
                        <div className="flex items-center justify-between mb-3">
                          <div className="flex items-center gap-2">
                            <FileText className="w-5 h-5 text-blue-400" />
                            <span className="text-white font-medium">
                              {document.name || `وثيقة ${index + 1}`}
                            </span>
                          </div>
                          <Button
                            onClick={() => downloadDocument(document)}
                            size="sm"
                            variant="outline"
                            className="bg-blue-500/20 border-blue-400/30 text-blue-400 hover:bg-blue-500/30"
                          >
                            <Download className="w-4 h-4 mr-1" />
                            تحميل
                          </Button>
                        </div>

                        <div className="space-y-2 text-sm text-gray-300">
                          <div className="flex justify-between">
                            <span>النوع:</span>
                            <span>{document.type || "غير محدد"}</span>
                          </div>
                          <div className="flex justify-between">
                            <span>الحجم:</span>
                            <span>
                              {document.size
                                ? `${(document.size / 1024 / 1024).toFixed(2)} MB`
                                : "غير محدد"}
                            </span>
                          </div>
                        </div>

                        {/* Document Preview */}
                        {document.data &&
                          document.type?.startsWith("image/") && (
                            <div className="mt-4">
                              <img
                                src={document.data}
                                alt={document.name || "وثيقة"}
                                className="w-full h-48 object-cover rounded-lg border border-white/20"
                              />
                            </div>
                          )}
                      </div>
                    ),
                  )}
                </div>
              ) : (
                <div className="text-center py-8">
                  <ImageIcon className="w-12 h-12 text-gray-400 mx-auto mb-3 opacity-50" />
                  <p className="text-gray-400">لا توجد وثائق مرفوعة</p>
                </div>
              )}
            </div>
          )}

          <div className="flex gap-3 mt-6">
            <Button
              onClick={() => setShowDocuments(false)}
              className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60"
            >
              إغلاق
            </Button>
          </div>
        </DialogContent>
      </Dialog>

      {/* Approve Confirmation Dialog */}
      <AlertDialog open={showApproveDialog} onOpenChange={setShowApproveDialog}>
        <AlertDialogContent className="bg-gradient-to-br from-slate-900/95 via-green-900/95 to-slate-900/95 backdrop-blur-md border border-green-400/30 text-white max-w-md mx-auto">
          <AlertDialogHeader className="text-center">
            <AlertDialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <CheckCircle className="w-6 h-6 text-green-400" />
              موافقة على التوثيق
            </AlertDialogTitle>
            <AlertDialogDescription className="text-gray-300">
              هل أنت متأكد من الموافقة على طلب توثيق هذا الحساب؟
            </AlertDialogDescription>
          </AlertDialogHeader>

          <div className="space-y-4 my-4">
            <div className="bg-green-500/20 border border-green-400/30 rounded-lg p-4">
              <p className="text-green-200 text-sm text-center">
                سيتم تفعيل الحساب وإرسال إشعار للمستخدم
              </p>
            </div>

            <div className="space-y-2">
              <Label className="text-white font-medium">
                ملاحظات إدارية (اختياري)
              </Label>
              <Textarea
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                placeholder="أضف ملاحظات للمستخدم..."
                className="bg-white/10 border-white/30 text-white placeholder:text-gray-400 min-h-[80px]"
              />
            </div>
          </div>

          <AlertDialogFooter className="flex gap-3">
            <AlertDialogCancel className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60">
              إلغاء
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={confirmApprove}
              disabled={processing}
              className="flex-1 h-12 bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700 text-white"
            >
              {processing ? "جاري المعالجة..." : "موافقة"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Reject Confirmation Dialog */}
      <AlertDialog open={showRejectDialog} onOpenChange={setShowRejectDialog}>
        <AlertDialogContent className="bg-gradient-to-br from-slate-900/95 via-red-900/95 to-slate-900/95 backdrop-blur-md border border-red-400/30 text-white max-w-md mx-auto">
          <AlertDialogHeader className="text-center">
            <AlertDialogTitle className="text-xl font-bold text-white flex items-center justify-center gap-2">
              <XCircle className="w-6 h-6 text-red-400" />
              رفض التوثيق
            </AlertDialogTitle>
            <AlertDialogDescription className="text-gray-300">
              هل أنت متأكد من رفض طلب توثيق هذا الحساب؟
            </AlertDialogDescription>
          </AlertDialogHeader>

          <div className="space-y-4 my-4">
            <div className="bg-red-500/20 border border-red-400/30 rounded-lg p-4">
              <p className="text-red-200 text-sm text-center">
                سيتم إرسال إشعار للمستخدم بسبب الرفض
              </p>
            </div>

            <div className="space-y-2">
              <Label className="text-white font-medium">سبب الرفض *</Label>
              <Textarea
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                placeholder="اكتب سبب رفض طلب التوثيق..."
                className="bg-white/10 border-white/30 text-white placeholder:text-gray-400 min-h-[80px]"
                required
              />
            </div>
          </div>

          <AlertDialogFooter className="flex gap-3">
            <AlertDialogCancel className="flex-1 h-12 bg-gray-600/50 border-gray-500/50 text-white hover:bg-gray-500/60">
              إلغاء
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={confirmReject}
              disabled={processing || !adminNotes.trim()}
              className="flex-1 h-12 bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700 text-white"
            >
              {processing ? "جاري المعالجة..." : "رفض"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

export default VerificationManagement;
