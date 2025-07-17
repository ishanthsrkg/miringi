// Notification helper functions for the application

import { createNotification, showBrowserNotification } from "./notifications";

// Request notification permission on app start
export const initializeNotifications = async () => {
  if ("Notification" in window) {
    if (Notification.permission === "default") {
      const permission = await Notification.requestPermission();
      console.log("Notification permission:", permission);
    }
  }
};

// Create and show notification with browser notification
export const createAndShowNotification = (
  type: "success" | "error" | "info" | "warning",
  title: string,
  message: string,
  onNotificationCreated?: (notification: any) => void,
) => {
  // Create notification object
  const notification = createNotification(type, title, message);

  // Show browser notification if permission granted
  showBrowserNotification(title, message);

  // Call callback if provided
  if (onNotificationCreated) {
    onNotificationCreated(notification);
  }

  return notification;
};

// Notification templates for common operations
export const NotificationTemplates = {
  transfer: {
    success: (amount: number, recipient: string, reference: string) => ({
      type: "success" as const,
      title: "تم التحويل بنجاح",
      message: `تم تحويل ${amount.toLocaleString()} دج إلى ${recipient} برقم المرجع: ${reference}`,
    }),
    failed: (error: string) => ({
      type: "error" as const,
      title: "فشل في التحويل",
      message: error,
    }),
  },

  recharge: {
    success: (amount: number) => ({
      type: "success" as const,
      title: "تم الشحن بنجاح",
      message: `تم شحن ${amount.toLocaleString()} دج في محفظتك`,
    }),
    pending: (amount: number, rib: string) => ({
      type: "info" as const,
      title: "تم استلام طلب الشحن",
      message: `سيتم إضافة ${amount.toLocaleString()} دج من RIB: ${rib} خلال 5-10 دقائق`,
    }),
  },

  investment: {
    success: (amount: number, operation: "invest" | "return") => ({
      type: "success" as const,
      title:
        operation === "invest"
          ? "تم الاستثمار بنجاح"
          : "تم سحب الاستثمار بنجاح",
      message: `تم ${operation === "invest" ? "استثمار" : "سحب"} مبلغ ${amount.toLocaleString()} دج`,
    }),
  },

  bill: {
    success: (amount: number, billType: string, reference: string) => ({
      type: "success" as const,
      title: "تم دفع الفاتورة بنجاح",
      message: `تم دفع فاتورة ${billType} بمبلغ ${amount.toLocaleString()} دج - المرجع: ${reference}`,
    }),
  },

  security: {
    loginSuccess: () => ({
      type: "success" as const,
      title: "تم تسجيل الدخول بنجاح",
      message: "مرحباً بك في محفظتك الرقمية",
    }),

    suspiciousActivity: () => ({
      type: "warning" as const,
      title: "نشاط مشبوه",
      message: "تم اكتشاف محاولة دخول من جهاز غير معروف",
    }),
  },

  system: {
    maintenance: () => ({
      type: "info" as const,
      title: "صيانة النظام",
      message: "سيتم إجراء صيانة للنظام من 2:00 إلى 4:00 صباحاً",
    }),

    update: () => ({
      type: "info" as const,
      title: "تحديث متوفر",
      message: "يتوفر تحديث جديد للتطبيق مع ميزات محسنة",
    }),
  },
};

// Format notification time in Arabic
export const formatNotificationTime = (date: Date): string => {
  const now = new Date();
  const diffInMinutes = Math.floor(
    (now.getTime() - date.getTime()) / (1000 * 60),
  );

  if (diffInMinutes < 1) {
    return "الآن";
  } else if (diffInMinutes < 60) {
    return `منذ ${diffInMinutes} دقيقة`;
  } else if (diffInMinutes < 1440) {
    // Less than 24 hours
    const hours = Math.floor(diffInMinutes / 60);
    return `منذ ${hours} ساعة`;
  } else {
    const days = Math.floor(diffInMinutes / 1440);
    return `منذ ${days} يوم`;
  }
};

// Get notification icon based on type
export const getNotificationIcon = (type: string): string => {
  switch (type) {
    case "success":
      return "✅";
    case "error":
      return "❌";
    case "warning":
      return "⚠️";
    case "info":
      return "ℹ️";
    case "security":
      return "🔒";
    default:
      return "📢";
  }
};
