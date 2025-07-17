import { Suspense, useState, useEffect, lazy } from "react";
import { useRoutes, Routes, Route, Navigate } from "react-router-dom";
import routes from "tempo-routes";
import { AppProvider } from "./contexts/AppContext";
import { useAuth } from "./hooks/useAuth";
import { Loader2 } from "lucide-react";

// Lazy load components with preloading for better performance
const LandingPage = lazy(() => import("./components/LandingPage"));
const Home = lazy(() => import("./components/home"));
const DebugAuth = lazy(() => import("./components/DebugAuth"));
const TransfersTab = lazy(() => import("./components/TransfersTab"));
const AccountVerification = lazy(
  () => import("./components/AccountVerification"),
);
const VerificationManagement = lazy(
  () => import("./components/VerificationManagement"),
);
const EmailVerificationPage = lazy(
  () => import("./components/EmailVerificationPage"),
);
const PasswordResetRequestPage = lazy(
  () => import("./components/PasswordResetRequestPage"),
);
const PasswordResetConfirmPage = lazy(
  () => import("./components/PasswordResetConfirmPage"),
);
const PhoneVerification = lazy(() => import("./components/PhoneVerification"));
const ReferralPage = lazy(() => import("./components/SavingsTab"));

// Preload critical components
const preloadCriticalComponents = () => {
  import("./components/LandingPage");
  import("./components/home");
};

function AppContent() {
  const { user, logout, loading } = useAuth();

  const handleSignup = () => {
    console.log("New user signup with Google");
  };

  // Show loading spinner while checking authentication with timeout
  const [showLoadingTimeout, setShowLoadingTimeout] = useState(false);

  useEffect(() => {
    if (loading) {
      const timeout = setTimeout(() => {
        setShowLoadingTimeout(true);
        console.log("⏰ انتهت مهلة التحميل - سيتم عرض خيارات إضافية");
      }, 15000); // 15 seconds

      return () => clearTimeout(timeout);
    } else {
      setShowLoadingTimeout(false);
    }
  }, [loading]);

  // Preload components on app start
  useEffect(() => {
    const timer = setTimeout(() => {
      preloadCriticalComponents();
    }, 2000);
    return () => clearTimeout(timer);
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen w-full bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 flex items-center justify-center">
        <div className="w-20 h-20 relative">
          <div className="absolute inset-0 border-4 border-blue-400/30 rounded-full animate-spin">
            <div className="absolute top-0 left-1/2 w-2 h-2 bg-blue-400 rounded-full transform -translate-x-1/2 -translate-y-1"></div>
          </div>
          <div className="absolute inset-2 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full animate-pulse flex items-center justify-center">
            <Loader2 className="w-8 h-8 text-white animate-spin" />
          </div>
        </div>
      </div>
    );
  }

  return (
    <Suspense
      fallback={
        <div className="min-h-screen w-full bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900 flex items-center justify-center">
          <div className="w-20 h-20 relative">
            <div className="absolute inset-0 border-4 border-blue-400/30 rounded-full animate-spin">
              <div className="absolute top-0 left-1/2 w-2 h-2 bg-blue-400 rounded-full transform -translate-x-1/2 -translate-y-1"></div>
            </div>
            <div className="absolute inset-2 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full animate-pulse flex items-center justify-center">
              <Loader2 className="w-8 h-8 text-white animate-spin" />
            </div>
          </div>
        </div>
      }
    >
      <>
        {/* Tempo routes must come first */}
        {import.meta.env.VITE_TEMPO === "true" && useRoutes(routes)}

        <Routes>
          <Route
            path="/"
            element={user ? <Navigate to="/home" replace /> : <LandingPage />}
          />
          <Route
            path="/login"
            element={
              user ? (
                <Navigate to="/home" replace />
              ) : (
                <Navigate to="/" replace />
              )
            }
          />
          <Route
            path="/signup"
            element={
              user ? (
                <Navigate to="/home" replace />
              ) : (
                <Navigate to="/" replace />
              )
            }
          />
          <Route path="/debug-auth" element={<DebugAuth />} />
          <Route
            path="/home"
            element={
              user ? <Home onLogout={logout} /> : <Navigate to="/" replace />
            }
          />
          <Route
            path="/transfers"
            element={
              user ? (
                <TransfersTab
                  balance={{
                    dzd: 15000,
                    eur: 75,
                    usd: 85,
                    gbt: 65.5,
                    gbp: 65.5,
                  }}
                  onTransfer={(amount, recipient) =>
                    console.log("Transfer:", amount, recipient)
                  }
                  onRecharge={(amount, method, rib) =>
                    console.log("Recharge:", amount, method, rib)
                  }
                  onNotification={(notification) =>
                    console.log("Notification:", notification)
                  }
                />
              ) : (
                <Navigate to="/" replace />
              )
            }
          />
          <Route
            path="/account-verification"
            element={
              user ? <AccountVerification /> : <Navigate to="/" replace />
            }
          />
          <Route
            path="/verification-management"
            element={
              user ? <VerificationManagement /> : <Navigate to="/" replace />
            }
          />
          <Route path="/verify-email" element={<EmailVerificationPage />} />
          <Route
            path="/forgot-password"
            element={<PasswordResetRequestPage />}
          />
          <Route
            path="/reset-password"
            element={<PasswordResetConfirmPage />}
          />
          <Route
            path="/verify-phone"
            element={
              <PhoneVerification
                onVerificationComplete={(verified, phoneNumber) => {
                  if (verified) {
                    console.log("Phone verified:", phoneNumber);
                    // Handle successful verification
                  }
                }}
              />
            }
          />
          <Route
            path="/referral"
            element={
              user ? (
                <ReferralPage
                  balance={{ dzd: 15000, eur: 75, usd: 85, gbt: 65.5 }}
                  onSavingsDeposit={(amount, goalId) =>
                    console.log("Savings deposit:", amount, goalId)
                  }
                  onNotification={(notification) =>
                    console.log("Notification:", notification)
                  }
                />
              ) : (
                <Navigate to="/" replace />
              )
            }
          />

          {/* Add tempo route before catchall */}
          {import.meta.env.VITE_TEMPO === "true" && (
            <Route path="/tempobook/*" />
          )}

          {/* Catch all route */}
          <Route
            path="*"
            element={<Navigate to={user ? "/home" : "/"} replace />}
          />
        </Routes>
      </>
    </Suspense>
  );
}

function App() {
  return (
    <AppProvider>
      <AppContent />
    </AppProvider>
  );
}

export default App;
