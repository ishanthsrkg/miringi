import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  ReactNode,
  useMemo,
  useCallback,
} from "react";

interface ProfileData {
  fullName: string;
  email: string;
  phone: string;
  accountNumber: string;
  joinDate: string;
  location: string;
  address: string;
  language: string;
  currency: string;
  profileImage: string;
  referralCode: string;
  referredBy: string;
}

interface AppSettings {
  isDarkMode: boolean;
  notificationsEnabled: boolean;
  soundEnabled: boolean;
  twoFactorEnabled: boolean;
  language: string;
  currency: string;
  timezone: string;
  dateFormat: string;
  fontSize: number;
  colorTheme: string;
  localStorageEnabled: boolean;
  encryptionEnabled: boolean;
  autoBackupEnabled: boolean;
  transactionNotifications: boolean;
  securityNotifications: boolean;
  promotionalNotifications: boolean;
  updateNotifications: boolean;
}

interface AppContextType {
  profileData: ProfileData;
  settings: AppSettings;
  updateProfile: (data: Partial<ProfileData>) => void;
  updateSettings: (settings: Partial<AppSettings>) => void;
  resetSettings: () => void;
  exportData: () => void;
  clearLocalData: () => void;
}

const defaultProfileData: ProfileData = {
  fullName: "",
  email: "",
  phone: "",
  accountNumber: "",
  joinDate: "",
  location: "",
  address: "",
  language: "العربية",
  currency: "دينار جزائري",
  profileImage: "",
  referralCode: "",
  referredBy: "",
};

const defaultSettings: AppSettings = {
  isDarkMode: true,
  notificationsEnabled: true,
  soundEnabled: true,
  twoFactorEnabled: true,
  language: "ar",
  currency: "dzd",
  timezone: "africa/algiers",
  dateFormat: "dd/mm/yyyy",
  fontSize: 60,
  colorTheme: "blue-purple",
  localStorageEnabled: true,
  encryptionEnabled: true,
  autoBackupEnabled: true,
  transactionNotifications: true,
  securityNotifications: true,
  promotionalNotifications: false,
  updateNotifications: true,
};

const AppContext = createContext<AppContextType | undefined>(undefined);

export function useAppContext() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error("useAppContext must be used within an AppProvider");
  }
  return context;
}

interface AppProviderProps {
  children: ReactNode;
}

export function AppProvider({ children }: AppProviderProps) {
  const [profileData, setProfileData] =
    useState<ProfileData>(defaultProfileData);
  const [settings, setSettings] = useState<AppSettings>(defaultSettings);

  // Load data from localStorage on mount
  useEffect(() => {
    const savedProfile = localStorage.getItem("netlify-profile");
    const savedSettings = localStorage.getItem("netlify-settings");

    if (savedProfile) {
      try {
        setProfileData(JSON.parse(savedProfile));
      } catch (error) {
        console.error("Error loading profile data:", error);
      }
    }

    if (savedSettings) {
      try {
        setSettings(JSON.parse(savedSettings));
      } catch (error) {
        console.error("Error loading settings:", error);
      }
    }
  }, []);

  // Apply dark mode to document
  useEffect(() => {
    if (settings.isDarkMode) {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  }, [settings.isDarkMode]);

  // Apply font size
  useEffect(() => {
    const fontSize = settings.fontSize;
    const scale = fontSize / 60; // 60 is the default
    document.documentElement.style.fontSize = `${16 * scale}px`;
  }, [settings.fontSize]);

  const updateProfile = useCallback(
    (data: Partial<ProfileData>) => {
      setProfileData((prevProfile) => {
        const newProfile = { ...prevProfile, ...data };
        if (settings.localStorageEnabled) {
          try {
            localStorage.setItem("netlify-profile", JSON.stringify(newProfile));
          } catch (error) {
            console.error("Failed to save profile data:", error);
          }
        }
        return newProfile;
      });
    },
    [settings.localStorageEnabled],
  );

  const updateSettings = useCallback((newSettings: Partial<AppSettings>) => {
    setSettings((prevSettings) => {
      const updatedSettings = { ...prevSettings, ...newSettings };
      if (updatedSettings.localStorageEnabled) {
        try {
          localStorage.setItem(
            "netlify-settings",
            JSON.stringify(updatedSettings),
          );
        } catch (error) {
          console.error("Failed to save settings:", error);
        }
      }
      return updatedSettings;
    });
  }, []);

  const resetSettings = useCallback(() => {
    setSettings(defaultSettings);
    try {
      localStorage.removeItem("netlify-settings");
    } catch (error) {
      console.error("Failed to clear settings:", error);
    }
  }, []);

  const exportData = useCallback(() => {
    try {
      const data = {
        profile: profileData,
        settings: settings,
        exportDate: new Date().toISOString(),
        version: "1.0.0",
      };

      const blob = new Blob([JSON.stringify(data, null, 2)], {
        type: "application/json",
      });

      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `netlify-account-data-${new Date().toISOString().split("T")[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error("Failed to export data:", error);
    }
  }, [profileData, settings]);

  const clearLocalData = useCallback(() => {
    try {
      localStorage.removeItem("netlify-profile");
      localStorage.removeItem("netlify-settings");
    } catch (error) {
      console.error("Failed to clear local data:", error);
    }
    setProfileData(defaultProfileData);
    setSettings(defaultSettings);
  }, []);

  const contextValue = useMemo(
    () => ({
      profileData,
      settings,
      updateProfile,
      updateSettings,
      resetSettings,
      exportData,
      clearLocalData,
    }),
    [
      profileData,
      settings,
      updateProfile,
      updateSettings,
      resetSettings,
      exportData,
      clearLocalData,
    ],
  );

  return (
    <AppContext.Provider value={contextValue}>{children}</AppContext.Provider>
  );
}
