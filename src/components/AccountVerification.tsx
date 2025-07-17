import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select";
import { Textarea } from "./ui/textarea";
import {
  User,
  Calendar,
  MapPin,
  FileText,
  Upload,
  CheckCircle,
  AlertCircle,
  ArrowLeft,
  Shield,
  Clock,
  Coins,
} from "lucide-react";
import { useAuth } from "../hooks/useAuth";
import { submitAccountVerification } from "../lib/supabase";

interface AccountVerificationProps {
  className?: string;
}

function AccountVerification({ className = "" }: AccountVerificationProps) {
  const navigate = useNavigate();
  const { user } = useAuth();

  const [formData, setFormData] = useState({
    country: "",
    date_of_birth: "",
    full_address: "",
    postal_code: "",
    document_type: "",
    document_number: "",
    additional_notes: "",
  });

  const [documents, setDocuments] = useState<File[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [errors, setErrors] = useState<{ [key: string]: string }>({});
  const [message, setMessage] = useState("");
  const [messageType, setMessageType] = useState<"success" | "error">(
    "success",
  );

  const countries = [
    "الجزائر",
    "المغرب",
    "تونس",
    "مصر",
    "السعودية",
    "الإمارات",
    "الكويت",
    "قطر",
    "البحرين",
    "عمان",
    "الأردن",
    "لبنان",
    "سوريا",
    "العراق",
    "فلسطين",
    "ليبيا",
    "السودان",
    "اليمن",
    "فرنسا",
    "ألمانيا",
    "إيطاليا",
    "إسبانيا",
    "بريطانيا",
    "كندا",
    "الولايات المتحدة",
    "أخرى",
  ];

  const documentTypes = [
    { value: "national_id", label: "بطاقة التعريف الوطنية" },
    { value: "passport", label: "جواز السفر" },
    { value: "driving_license", label: "رخصة السياقة" },
  ];

  const validateForm = () => {
    const newErrors: { [key: string]: string } = {};

    if (!formData.country) {
      newErrors.country = "البلد مطلوب";
    }

    if (!formData.date_of_birth) {
      newErrors.date_of_birth = "تاريخ الميلاد مطلوب";
    } else {
      const birthDate = new Date(formData.date_of_birth);
      const today = new Date();
      const age = today.getFullYear() - birthDate.getFullYear();
      if (age < 18) {
        newErrors.date_of_birth = "يجب أن تكون 18 سنة أو أكثر";
      }
    }

    if (!formData.full_address.trim()) {
      newErrors.full_address = "العنوان الكامل مطلوب";
    }

    if (!formData.postal_code.trim()) {
      newErrors.postal_code = "الرقم البريدي مطلوب";
    }

    if (!formData.document_type) {
      newErrors.document_type = "نوع الوثيقة مطلوب";
    }

    if (!formData.document_number.trim()) {
      newErrors.document_number = "رقم الوثيقة مطلوب";
    }

    if (documents.length === 0) {
      newErrors.documents = "يجب رفع صورة الوثيقة";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleInputChange = (field: string, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: "" }));
    }
  };

  const handleFileUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files || []);
    const validFiles = files.filter((file) => {
      const isValidType =
        file.type.startsWith("image/") || file.type === "application/pdf";
      const isValidSize = file.size <= 5 * 1024 * 1024; // 5MB
      return isValidType && isValidSize;
    });

    if (validFiles.length !== files.length) {
      setMessage(
        "بعض الملفات غير صالحة. يُسمح فقط بالصور و PDF بحجم أقل من 5 ميجابايت",
      );
      setMessageType("error");
    }

    setDocuments((prev) => [...prev, ...validFiles].slice(0, 3)); // Max 3 files
    if (errors.documents) {
      setErrors((prev) => ({ ...prev, documents: "" }));
    }
  };

  const removeDocument = (index: number) => {
    setDocuments((prev) => prev.filter((_, i) => i !== index));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) return;

    setIsSubmitting(true);
    setMessage("");
    setErrors({});

    try {
      // Convert files to base64 for storage
      const documentData = await Promise.all(
        documents.map(async (file) => {
          const base64 = await new Promise<string>((resolve) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result as string);
            reader.readAsDataURL(file);
          });

          return {
            name: file.name,
            type: file.type,
            size: file.size,
            data: base64,
          };
        }),
      );

      const verificationData = {
        ...formData,
        documents: documentData,
        submitted_at: new Date().toISOString(),
      };

      const result = await submitAccountVerification(
        user?.id || "",
        verificationData,
      );

      if (result?.error) {
        setMessageType("error");
        setMessage("حدث خطأ في إرسال طلب التوثيق: " + result.error.message);
      } else {
        setIsSubmitted(true);
        setMessageType("success");
        setMessage("تم إرسال طلب التوثيق بنجاح!");
      }
    } catch (error: any) {
      setMessageType("error");
      setMessage("حدث خطأ غير متوقع: " + error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isSubmitted) {
    return (
      <div
        className={`min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 p-4 ${className}`}
      >
        <div className="max-w-2xl mx-auto pt-8">
          <Card className="bg-white/10 backdrop-blur-md border border-white/20 shadow-2xl">
            <CardContent className="p-8 text-center">
              <div className="w-20 h-20 bg-green-500/20 rounded-full flex items-center justify-center mx-auto mb-6">
                <CheckCircle className="w-10 h-10 text-green-400" />
              </div>

              <h2 className="text-2xl font-bold text-white mb-4">
                تم إرسال طلب التوثيق بنجاح
              </h2>

              <div className="bg-blue-500/20 border border-blue-400/30 rounded-lg p-6 mb-6">
                <div className="flex items-center justify-center gap-3 mb-4">
                  <Clock className="w-6 h-6 text-blue-400" />
                  <span className="text-blue-300 font-medium">
                    قيد المراجعة
                  </span>
                </div>

                <p className="text-white text-lg mb-4">سوف ندرس ملفك ونعلمك</p>

                <div className="text-gray-300 text-sm space-y-2">
                  <p>• سيتم مراجعة طلبك خلال 2-5 أيام عمل</p>
                  <p>• سيتم إرسال النتيجة عبر البريد الإلكتروني</p>
                  <p>• يمكنك متابعة حالة الطلب من الملف الشخصي</p>
                </div>
              </div>

              <div className="flex gap-4 justify-center">
                <Button
                  onClick={() => navigate("/home")}
                  className="bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white px-8"
                >
                  العودة للرئيسية
                </Button>

                <Button
                  onClick={() => navigate(-1)}
                  variant="outline"
                  className="bg-white/10 border-white/30 text-white hover:bg-white/20"
                >
                  <ArrowLeft className="w-4 h-4 mr-2" />
                  رجوع
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div
      className={`min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 p-4 ${className}`}
    >
      <div className="max-w-4xl mx-auto pt-8">
        {/* Header */}
        <div className="flex items-center gap-4 mb-6">
          <Button
            onClick={() => navigate(-1)}
            variant="outline"
            size="sm"
            className="bg-white/10 border-white/30 text-white hover:bg-white/20"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            رجوع
          </Button>

          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
              <Shield className="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">توثيق الحساب</h1>
              <p className="text-gray-300 text-sm">
                أكمل المعلومات المطلوبة لتوثيق حسابك
              </p>
            </div>
          </div>
        </div>

        {/* Success/Error Messages */}
        {message && (
          <div
            className={`p-4 rounded-lg flex items-center gap-3 mb-6 ${
              messageType === "success"
                ? "bg-green-500/20 border border-green-500/30 text-green-300"
                : "bg-red-500/20 border border-red-500/30 text-red-300"
            }`}
          >
            {messageType === "success" ? (
              <CheckCircle className="w-5 h-5 flex-shrink-0" />
            ) : (
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
            )}
            <span className="text-right flex-1">{message}</span>
          </div>
        )}

        {/* Security Notice */}
        <Card className="bg-gradient-to-br from-amber-500/20 to-orange-600/20 backdrop-blur-md border border-amber-400/30 shadow-2xl mb-6">
          <CardContent className="p-6">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 bg-gradient-to-br from-amber-500 to-orange-600 rounded-full flex items-center justify-center flex-shrink-0">
                <Shield className="w-6 h-6 text-white" />
              </div>
              <div className="flex-1">
                <h3 className="text-amber-300 font-bold text-lg mb-2">
                  شروط التوثيق الأمنية
                </h3>
                <div className="space-y-3 text-white">
                  <div className="bg-amber-500/20 border border-amber-400/30 rounded-lg p-4">
                    <h4 className="font-semibold text-amber-200 mb-2">
                      متطلبات التوثيق:
                    </h4>
                    <ul className="space-y-2 text-sm">
                      <li className="flex items-center gap-2">
                        <div className="w-2 h-2 bg-amber-400 rounded-full"></div>
                        <span>تعبئة جميع المعلومات الشخصية المطلوبة</span>
                      </li>
                      <li className="flex items-center gap-2">
                        <div className="w-2 h-2 bg-amber-400 rounded-full"></div>
                        <span>رفع صور الوثائق الرسمية</span>
                      </li>
                      <li className="flex items-center gap-2">
                        <div className="w-2 h-2 bg-green-400 rounded-full"></div>
                        <span className="font-medium text-green-300">
                          شحن الرصيد بمبلغ 3,000 دينار جزائري
                        </span>
                      </li>
                    </ul>
                  </div>
                  <div className="bg-green-500/20 border border-green-400/30 rounded-lg p-4">
                    <div className="flex items-center gap-2 mb-2">
                      <CheckCircle className="w-5 h-5 text-green-400" />
                      <h4 className="font-semibold text-green-300">
                        ملاحظة مهمة:
                      </h4>
                    </div>
                    <div className="space-y-1 text-sm text-green-200">
                      <p>
                        • <strong>التوثيق مجاني تماماً</strong> - لا توجد رسوم
                        إضافية
                      </p>
                      <p>
                        • <strong>رصيدك محفوظ</strong> - مبلغ الشحن يبقى في
                        حسابك
                      </p>
                      <p>
                        • <strong>إجراء أمني</strong> - للتأكد من صحة بيانات
                        الحساب
                      </p>
                      <p>
                        • <strong>مرة واحدة فقط</strong> - لا يتطلب شحن إضافي
                        مستقبلاً
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Personal Information */}
          <Card className="bg-white/10 backdrop-blur-md border border-white/20 shadow-2xl">
            <CardHeader>
              <CardTitle className="text-xl font-bold text-white flex items-center gap-2">
                <User className="w-5 h-5 text-blue-400" />
                المعلومات الشخصية
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Country */}
              <div className="space-y-2">
                <Label className="text-white font-medium">البلد *</Label>
                <Select
                  value={formData.country}
                  onValueChange={(value) => handleInputChange("country", value)}
                >
                  <SelectTrigger className="h-12 bg-white/10 border-white/30 text-white">
                    <SelectValue placeholder="اختر البلد" />
                  </SelectTrigger>
                  <SelectContent>
                    {countries.map((country) => (
                      <SelectItem key={country} value={country}>
                        {country}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {errors.country && (
                  <p className="text-red-400 text-xs text-right">
                    {errors.country}
                  </p>
                )}
              </div>

              {/* Date of Birth */}
              <div className="space-y-2">
                <Label className="text-white font-medium flex items-center gap-2">
                  <Calendar className="w-4 h-4 text-gray-400" />
                  تاريخ الميلاد *
                </Label>
                <Input
                  type="date"
                  value={formData.date_of_birth}
                  onChange={(e) =>
                    handleInputChange("date_of_birth", e.target.value)
                  }
                  className="h-12 bg-white/10 border-white/30 text-white"
                />
                {errors.date_of_birth && (
                  <p className="text-red-400 text-xs text-right">
                    {errors.date_of_birth}
                  </p>
                )}
              </div>

              {/* Full Address */}
              <div className="space-y-2">
                <Label className="text-white font-medium flex items-center gap-2">
                  <MapPin className="w-4 h-4 text-gray-400" />
                  العنوان الكامل *
                </Label>
                <Textarea
                  value={formData.full_address}
                  onChange={(e) =>
                    handleInputChange("full_address", e.target.value)
                  }
                  className="min-h-[100px] bg-white/10 border-white/30 text-white placeholder:text-gray-400"
                  placeholder="أدخل عنوانك الكامل بالتفصيل"
                />
                {errors.full_address && (
                  <p className="text-red-400 text-xs text-right">
                    {errors.full_address}
                  </p>
                )}
              </div>

              {/* Postal Code */}
              <div className="space-y-2">
                <Label className="text-white font-medium">
                  الرقم البريدي *
                </Label>
                <Input
                  type="text"
                  value={formData.postal_code}
                  onChange={(e) =>
                    handleInputChange("postal_code", e.target.value)
                  }
                  className="h-12 bg-white/10 border-white/30 text-white placeholder:text-gray-400"
                  placeholder="أدخل الرقم البريدي"
                />
                {errors.postal_code && (
                  <p className="text-red-400 text-xs text-right">
                    {errors.postal_code}
                  </p>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Documents */}
          <Card className="bg-white/10 backdrop-blur-md border border-white/20 shadow-2xl">
            <CardHeader>
              <CardTitle className="text-xl font-bold text-white flex items-center gap-2">
                <FileText className="w-5 h-5 text-blue-400" />
                الوثائق المطلوبة
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Document Type */}
              <div className="space-y-2">
                <Label className="text-white font-medium">نوع الوثيقة *</Label>
                <Select
                  value={formData.document_type}
                  onValueChange={(value) =>
                    handleInputChange("document_type", value)
                  }
                >
                  <SelectTrigger className="h-12 bg-white/10 border-white/30 text-white">
                    <SelectValue placeholder="اختر نوع الوثيقة" />
                  </SelectTrigger>
                  <SelectContent>
                    {documentTypes.map((type) => (
                      <SelectItem key={type.value} value={type.value}>
                        {type.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {errors.document_type && (
                  <p className="text-red-400 text-xs text-right">
                    {errors.document_type}
                  </p>
                )}
              </div>

              {/* Document Number */}
              <div className="space-y-2">
                <Label className="text-white font-medium">رقم الوثيقة *</Label>
                <Input
                  type="text"
                  value={formData.document_number}
                  onChange={(e) =>
                    handleInputChange("document_number", e.target.value)
                  }
                  className="h-12 bg-white/10 border-white/30 text-white placeholder:text-gray-400"
                  placeholder="أدخل رقم الوثيقة"
                />
                {errors.document_number && (
                  <p className="text-red-400 text-xs text-right">
                    {errors.document_number}
                  </p>
                )}
              </div>

              {/* File Upload */}
              <div className="space-y-2">
                <Label className="text-white font-medium">صور الوثيقة *</Label>
                <div className="border-2 border-dashed border-white/30 rounded-lg p-6 text-center">
                  <Upload className="w-8 h-8 text-gray-400 mx-auto mb-2" />
                  <p className="text-gray-300 mb-2">
                    اسحب الملفات هنا أو انقر للاختيار
                  </p>
                  <p className="text-gray-400 text-sm mb-4">
                    الصور أو PDF - حد أقصى 5 ميجابايت لكل ملف
                  </p>
                  <input
                    type="file"
                    multiple
                    accept="image/*,.pdf"
                    onChange={handleFileUpload}
                    className="hidden"
                    id="document-upload"
                  />
                  <Button
                    type="button"
                    onClick={() =>
                      document.getElementById("document-upload")?.click()
                    }
                    variant="outline"
                    className="bg-white/10 border-white/30 text-white hover:bg-white/20"
                  >
                    اختيار الملفات
                  </Button>
                </div>

                {/* Uploaded Files */}
                {documents.length > 0 && (
                  <div className="space-y-2">
                    <p className="text-white text-sm font-medium">
                      الملفات المرفوعة:
                    </p>
                    {documents.map((file, index) => (
                      <div
                        key={index}
                        className="flex items-center justify-between bg-white/5 p-3 rounded-lg"
                      >
                        <div className="flex items-center gap-3">
                          <FileText className="w-4 h-4 text-blue-400" />
                          <div>
                            <p className="text-white text-sm">{file.name}</p>
                            <p className="text-gray-400 text-xs">
                              {(file.size / 1024 / 1024).toFixed(2)} MB
                            </p>
                          </div>
                        </div>
                        <Button
                          type="button"
                          onClick={() => removeDocument(index)}
                          variant="outline"
                          size="sm"
                          className="bg-red-500/20 border-red-400/30 text-red-300 hover:bg-red-500/30"
                        >
                          حذف
                        </Button>
                      </div>
                    ))}
                  </div>
                )}

                {errors.documents && (
                  <p className="text-red-400 text-xs text-right">
                    {errors.documents}
                  </p>
                )}
              </div>

              {/* Additional Notes */}
              <div className="space-y-2">
                <Label className="text-white font-medium">
                  ملاحظات إضافية (اختياري)
                </Label>
                <Textarea
                  value={formData.additional_notes}
                  onChange={(e) =>
                    handleInputChange("additional_notes", e.target.value)
                  }
                  className="min-h-[80px] bg-white/10 border-white/30 text-white placeholder:text-gray-400"
                  placeholder="أي معلومات إضافية تود إضافتها"
                />
              </div>
            </CardContent>
          </Card>

          {/* Submit Button */}
          <div className="flex gap-4 justify-center pt-4">
            <Button
              type="button"
              onClick={() => navigate(-1)}
              variant="outline"
              className="px-8 bg-gray-600/20 hover:bg-gray-500/30 border-gray-400/30 text-gray-300 hover:text-white"
              disabled={isSubmitting}
            >
              إلغاء
            </Button>

            <Button
              type="submit"
              className="px-8 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white"
              disabled={isSubmitting}
            >
              {isSubmitting ? (
                <>
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></div>
                  جاري الإرسال...
                </>
              ) : (
                <>
                  <Shield className="w-4 h-4 mr-2" />
                  إرسال طلب التوثيق
                </>
              )}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}

export default AccountVerification;
