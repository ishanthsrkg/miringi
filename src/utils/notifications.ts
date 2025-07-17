// Notification utilities

export interface Notification {
  id: string;
  type: "success" | "error" | "info" | "warning";
  title: string;
  message: string;
  timestamp: Date;
  read: boolean;
}

// Create notification
export const createNotification = (
  type: Notification["type"],
  title: string,
  message: string,
): Notification => {
  return {
    id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
    type,
    title,
    message,
    timestamp: new Date(),
    read: false,
  };
};

// Show browser notification (if permission granted)
export const showBrowserNotification = (title: string, message: string) => {
  if ("Notification" in window && Notification.permission === "granted") {
    new Notification(title, {
      body: message,
      icon: "/vite.svg",
    });
  }
};

// Request notification permission
export const requestNotificationPermission = async (): Promise<boolean> => {
  if ("Notification" in window) {
    const permission = await Notification.requestPermission();
    return permission === "granted";
  }
  return false;
};
