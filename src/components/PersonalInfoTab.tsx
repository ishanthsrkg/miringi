import { useState, useEffect } from "react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import {
  User,
  Mail,
  Phone,
  MapPin,
  Calendar,
  Edit3,
  Save,
  X,
  CheckCircle,
  AlertCircle,
} from "lucide-react";
import { useAuth } from "../hooks/useAuth";
import { useDatabase } from "../hooks/useDatabase";
import {
  createNotification,
  showBrowserNotification,
} from "../utils/notifications";

interface PersonalInfoTabProps {
  className?: string;
}

function PersonalInfoTab({ className = "" }: PersonalInfoTabProps) {
  const { user } = useAuth();
  const { profile, updateProfile, loading } = useDatabase(user?.id || null);

  const [isEditing, setIsEditing] = useState(false);
  const [formData, setFormData] = useState({
    full_name: "",
    email: "",
    phone: "",
    address: "",
    username: "",
  });
  const [errors, setErrors] = useState<{ [key: string]: string }>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [message, setMessage] = useState("");
  const [messageType, setMessageType] = useState<"success" | "error">(
    "success",
  );

  // Initialize form data when user or profile changes
  useEffect(() => {
    if (user || profile) {
      setFormData({
        full_name: profile?.full_name || user?.user_metadata?.full_name || "",
        email: user?.email || profile?.email || "",
        phone: profile?.phone || user?.user_metadata?.phone || "",
        address: profile?.address || user?.user_metadata?.address || "",
        username: profile?.username || user?.user_metadata?.username || "",
      });
    }
  }, [user, profile]);

  const validateForm = () => {
    const newErrors: { [key: string]: string } = {};

    if (!formData.full_name.trim()) {
      newErrors.full_name = "الاسم الكامل مطلوب";
    }

    if (!formData.email.trim()) {
      newErrors.email = "البريد الإلكتروني مطلوب";
    } else {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(formData.email.trim())) {
        newErrors.email = "البريد الإلكتروني غير صحيح";
      }
    }

    if (!formData.phone.trim()) {
      newErrors.phone = "رقم الهاتف مطلوب";
    }

    if (!formData.address.trim()) {
      newErrors.address = "العنوان مطلوب";
    }

    if (!formData.username.trim()) {
      newErrors.username = "اسم المستخدم مطلوب";
    } else if (formData.username.trim().length < 3) {
      newErrors.username = "اسم المستخدم يجب أن يكون 3 أحرف على الأقل";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) return;

    setIsSubmitting(true);
    setMessage("");
    setErrors({});

    try {
      const result = await updateProfile({
        full_name: formData.full_name.trim(),
        phone: formData.phone.trim(),
        address: formData.address.trim(),
        username: formData.username.trim(),
        profile_completed: true,
        updated_at: new Date().toISOString(),
      });

      if (result?.error) {
        setMessageType("error");
        setMessage("حدث خطأ في تحديث البيانات: " + result.error.message);
      } else {
        setMessageType("success");
        setMessage("تم تحديث المعلومات الشخصية بنجاح!");
        setIsEditing(false);

        // Show notification
        const notification = createNotification(
          "success",
          "تم تحديث المعلومات الشخصية",
          "تم حفظ معلوماتك الشخصية بنجاح",
        );
        showBrowserNotification(
          "تم تحديث المعلومات الشخصية",
          "تم حفظ معلوماتك الشخصية بنجاح",
        );
      }
    } catch (error: any) {
      setMessageType("error");
      setMessage("حدث خطأ غير متوقع: " + error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleCancel = () => {
    // Reset form data to original values
    setFormData({
      full_name: profile?.full_name || user?.user_metadata?.full_name || "",
      email: user?.email || profile?.email || "",
      phone: profile?.phone || user?.user_metadata?.phone || "",
      address: profile?.address || user?.user_metadata?.address || "",
      username: profile?.username || user?.user_metadata?.username || "",
    });
    setIsEditing(false);
    setErrors({});
    setMessage("");
  };

  const handleInputChange = (field: string, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    // Clear error for this field when user starts typing
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: "" }));
    }
  };

  return (
    <div className={`space-y-4 sm:space-y-6 pb-20 px-3 sm:px-4 ${className}`}>
      <div className="text-center mb-4 sm:mb-6">
        <h2 className="text-xl sm:text-2xl lg:text-3xl font-bold text-white mb-2">
          الملف الشخصي
        </h2>
        <p className="text-sm sm:text-base lg:text-lg text-gray-300">
          إدارة معلوماتك الشخصية
        </p>
      </div>

      {/* Success/Error Messages */}
      {message && (
        <div
          className={`p-3 rounded-lg flex items-center gap-2 text-sm ${
            messageType === "success"
              ? "bg-green-500/20 border border-green-500/30 text-green-300"
              : "bg-red-500/20 border border-red-500/30 text-red-300"
          }`}
        >
          {messageType === "success" ? (
            <CheckCircle className="w-4 h-4 flex-shrink-0" />
          ) : (
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
          )}
          <span className="text-right flex-1">{message}</span>
        </div>
      )}

      {/* Profile Summary Card */}
      <Card className="bg-gradient-to-br from-blue-600/20 to-purple-600/20 backdrop-blur-md border border-white/30 shadow-2xl mb-6">
        <CardContent className="p-6">
          <div className="flex items-center gap-4 mb-4">
            <div className="w-16 h-16 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center overflow-hidden">
              {user?.user_metadata?.avatar_url ? (
                <img
                  src={user.user_metadata.avatar_url}
                  alt="صورة الملف الشخصي"
                  className="w-full h-full object-cover rounded-full"
                  onError={(e) => {
                    e.currentTarget.style.display = "none";
                    e.currentTarget.nextElementSibling.style.display = "flex";
                  }}
                />
              ) : null}
              <User
                className={`w-8 h-8 text-white ${user?.user_metadata?.avatar_url ? "hidden" : "block"}`}
              />
            </div>
            <div className="flex-1">
              <h3 className="text-xl font-bold text-white mb-1">
                {formData.full_name || "اسم المستخدم"}
              </h3>
              <p className="text-blue-300 text-sm mb-1">
                @{formData.username || "username"}
              </p>
              <p className="text-gray-300 text-sm">
                {formData.email || "البريد الإلكتروني"}
              </p>
            </div>
            <div className="text-right space-y-2">
              <div
                className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium ${
                  profile?.profile_completed ||
                  (profile?.full_name && profile?.phone && profile?.address)
                    ? "bg-green-500/20 text-green-300 border border-green-500/30"
                    : "bg-yellow-500/20 text-yellow-300 border border-yellow-500/30"
                }`}
              >
                <div
                  className={`w-2 h-2 rounded-full ${
                    profile?.profile_completed ||
                    (profile?.full_name && profile?.phone && profile?.address)
                      ? "bg-green-400"
                      : "bg-yellow-400"
                  }`}
                ></div>
                {profile?.profile_completed ||
                (profile?.full_name && profile?.phone && profile?.address)
                  ? "مكتمل"
                  : "يحتاج تحديث"}
              </div>

              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium bg-red-500/20 text-red-300 border border-red-500/30">
                <div className="w-2 h-2 rounded-full bg-red-400"></div>
                غير موثق
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4 text-sm">
            <div className="flex items-center gap-2 text-gray-300">
              <Phone className="w-4 h-4 text-blue-400" />
              <span>{formData.phone || "غير محدد"}</span>
            </div>
            <div className="flex items-center gap-2 text-gray-300">
              <MapPin className="w-4 h-4 text-blue-400" />
              <span>{formData.address || "غير محدد"}</span>
            </div>
            <div className="flex items-center gap-2 text-gray-300">
              <Calendar className="w-4 h-4 text-blue-400" />
              <span>
                {profile?.registration_date
                  ? new Date(profile.registration_date).toLocaleDateString(
                      "ar-SA",
                    )
                  : user?.created_at
                    ? new Date(user.created_at).toLocaleDateString("ar-SA")
                    : "غير محدد"}
              </span>
            </div>
            <div className="flex items-center gap-2 text-gray-300">
              <Mail className="w-4 h-4 text-blue-400" />
              <span>مؤكد</span>
            </div>
            {profile?.referral_code && (
              <div className="flex items-center gap-2 text-gray-300">
                <User className="w-4 h-4 text-green-400" />
                <span>كود الإحالة: {profile.referral_code}</span>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      <Card className="bg-white/10 backdrop-blur-md border border-white/20 shadow-2xl">
        <CardHeader className="flex flex-row items-center justify-between pb-4">
          <CardTitle className="text-lg sm:text-xl font-bold text-white flex items-center gap-2">
            <Edit3 className="w-5 h-5 text-blue-400" />
            تعديل المعلومات الشخصية
          </CardTitle>
          {!isEditing && (
            <Button
              onClick={() => setIsEditing(true)}
              variant="outline"
              size="sm"
              className="bg-blue-600/20 hover:bg-blue-500/30 border-blue-400/30 text-blue-300 hover:text-white"
            >
              <Edit3 className="w-4 h-4 mr-2" />
              تعديل
            </Button>
          )}
        </CardHeader>
        <CardContent className="space-y-4 sm:space-y-6">
          <form onSubmit={handleSubmit} className="space-y-4 sm:space-y-6">
            {/* Full Name */}
            <div className="space-y-2">
              <Label className="text-white font-medium flex items-center gap-2">
                <User className="w-4 h-4 text-gray-400" />
                الاسم الكامل
              </Label>
              <Input
                type="text"
                value={formData.full_name}
                onChange={(e) => handleInputChange("full_name", e.target.value)}
                disabled={!isEditing}
                className={`h-12 text-right bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-blue-400 focus:ring-blue-400 ${
                  !isEditing ? "opacity-70 cursor-not-allowed" : ""
                }`}
                placeholder="أدخل اسمك الكامل"
              />
              {errors.full_name && (
                <p className="text-red-400 text-xs text-right">
                  {errors.full_name}
                </p>
              )}
            </div>

            {/* Email */}
            <div className="space-y-2">
              <Label className="text-white font-medium flex items-center gap-2">
                <Mail className="w-4 h-4 text-gray-400" />
                البريد الإلكتروني
              </Label>
              <Input
                type="email"
                value={formData.email}
                onChange={(e) => handleInputChange("email", e.target.value)}
                disabled={true} // Email should not be editable
                className="h-12 text-right bg-white/5 border-white/20 text-gray-400 opacity-70 cursor-not-allowed"
                placeholder="البريد الإلكتروني"
              />
              <p className="text-gray-400 text-xs text-right">
                لا يمكن تغيير البريد الإلكتروني
              </p>
            </div>

            {/* Phone */}
            <div className="space-y-2">
              <Label className="text-white font-medium flex items-center gap-2">
                <Phone className="w-4 h-4 text-gray-400" />
                رقم الهاتف
              </Label>
              <Input
                type="tel"
                value={formData.phone}
                onChange={(e) => handleInputChange("phone", e.target.value)}
                disabled={!isEditing}
                className={`h-12 text-right bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-blue-400 focus:ring-blue-400 ${
                  !isEditing ? "opacity-70 cursor-not-allowed" : ""
                }`}
                placeholder="أدخل رقم هاتفك"
              />
              {errors.phone && (
                <p className="text-red-400 text-xs text-right">
                  {errors.phone}
                </p>
              )}
            </div>

            {/* Address */}
            <div className="space-y-2">
              <Label className="text-white font-medium flex items-center gap-2">
                <MapPin className="w-4 h-4 text-gray-400" />
                العنوان
              </Label>
              <Input
                type="text"
                value={formData.address}
                onChange={(e) => handleInputChange("address", e.target.value)}
                disabled={!isEditing}
                className={`h-12 text-right bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-blue-400 focus:ring-blue-400 ${
                  !isEditing ? "opacity-70 cursor-not-allowed" : ""
                }`}
                placeholder="أدخل عنوانك الكامل"
              />
              {errors.address && (
                <p className="text-red-400 text-xs text-right">
                  {errors.address}
                </p>
              )}
            </div>

            {/* Username */}
            <div className="space-y-2">
              <Label className="text-white font-medium flex items-center gap-2">
                <User className="w-4 h-4 text-gray-400" />
                اسم المستخدم
              </Label>
              <Input
                type="text"
                value={formData.username}
                onChange={(e) => handleInputChange("username", e.target.value)}
                disabled={!isEditing}
                className={`h-12 text-right bg-white/10 border-white/30 text-white placeholder:text-gray-400 focus:border-blue-400 focus:ring-blue-400 ${
                  !isEditing ? "opacity-70 cursor-not-allowed" : ""
                }`}
                placeholder="اختر اسم مستخدم"
              />
              {errors.username && (
                <p className="text-red-400 text-xs text-right">
                  {errors.username}
                </p>
              )}
            </div>

            {/* Registration Date */}
            <div className="space-y-2">
              <Label className="text-white font-medium flex items-center gap-2">
                <Calendar className="w-4 h-4 text-gray-400" />
                تاريخ التسجيل
              </Label>
              <Input
                type="text"
                value={
                  profile?.registration_date
                    ? new Date(profile.registration_date).toLocaleDateString(
                        "ar-SA",
                      )
                    : user?.created_at
                      ? new Date(user.created_at).toLocaleDateString("ar-SA")
                      : "غير محدد"
                }
                disabled={true}
                className="h-12 text-right bg-white/5 border-white/20 text-gray-400 opacity-70 cursor-not-allowed"
              />
            </div>

            {/* Action Buttons */}
            {isEditing && (
              <div className="flex gap-3 pt-4">
                <Button
                  type="button"
                  onClick={handleCancel}
                  variant="outline"
                  className="flex-1 h-12 bg-gray-600/20 hover:bg-gray-500/30 border-gray-400/30 text-gray-300 hover:text-white"
                  disabled={isSubmitting}
                >
                  <X className="w-4 h-4 mr-2" />
                  إلغاء
                </Button>
                <Button
                  type="submit"
                  className="flex-1 h-12 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white"
                  disabled={isSubmitting || loading}
                >
                  {isSubmitting ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></div>
                      جاري الحفظ...
                    </>
                  ) : (
                    <>
                      <Save className="w-4 h-4 mr-2" />
                      حفظ التغييرات
                    </>
                  )}
                </Button>
              </div>
            )}
          </form>
        </CardContent>
      </Card>

      {/* Quick Stats Cards */}
      <div className="grid grid-cols-2 gap-4">
        <Card className="bg-white/5 backdrop-blur-md border border-white/10">
          <CardContent className="p-4 text-center">
            <div className="w-12 h-12 bg-blue-500/20 rounded-full flex items-center justify-center mx-auto mb-2">
              <CheckCircle className="w-6 h-6 text-blue-400" />
            </div>
            <p className="text-white font-medium mb-1">حالة الملف</p>
            <p className="text-sm text-gray-300">
              {profile?.profile_completed ||
              (profile?.full_name && profile?.phone && profile?.address)
                ? "مكتمل 100%"
                : "يحتاج تحديث"}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-white/5 backdrop-blur-md border border-white/10">
          <CardContent className="p-4 text-center">
            <div className="w-12 h-12 bg-green-500/20 rounded-full flex items-center justify-center mx-auto mb-2">
              <Mail className="w-6 h-6 text-green-400" />
            </div>
            <p className="text-white font-medium mb-1">البريد الإلكتروني</p>
            <p className="text-sm text-gray-300">مؤكد</p>
          </CardContent>
        </Card>
      </div>

      {/* Account Verification Card */}
      <Card className="bg-gradient-to-br from-purple-600/20 to-blue-600/20 backdrop-blur-md border border-white/30 shadow-2xl">
        <CardContent className="p-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-600 rounded-full flex items-center justify-center">
                <CheckCircle className="w-8 h-8 text-white" />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white mb-1">
                  توثيق الحساب
                </h3>
                <p className="text-gray-300 text-sm mb-2">
                  قم بتوثيق حسابك للحصول على مزايا إضافية
                </p>
                <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium bg-red-500/20 text-red-300 border border-red-500/30">
                  <div className="w-2 h-2 rounded-full bg-red-400"></div>
                  غير موثق
                </div>
              </div>
            </div>

            <Button
              onClick={() => (window.location.href = "/account-verification")}
              className="px-6 bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700 text-white"
            >
              <CheckCircle className="w-4 h-4 mr-2" />
              توثيق الحساب
            </Button>

            <div className="text-center">
              <div className="w-8 h-8 bg-red-500/20 rounded-full flex items-center justify-center mx-auto mb-2">
                <AlertCircle className="w-5 h-5 text-red-400" />
              </div>
              <p className="text-red-300 text-xs">غير موثق</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default PersonalInfoTab;
