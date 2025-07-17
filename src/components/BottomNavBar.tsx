import {
  Home,
  CreditCard,
  Send,
  TrendingUp,
  Plus,
  BarChart3,
  Users,
} from "lucide-react";

interface BottomNavBarProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
}

function BottomNavBar({ activeTab, onTabChange }: BottomNavBarProps) {
  const tabs = [
    {
      id: "home",
      label: "الرئيسية",
      icon: Home,
    },
    {
      id: "transfers",
      label: "التحويلات",
      icon: Send,
    },
    {
      id: "card",
      label: "البطاقة",
      icon: CreditCard,
    },
    {
      id: "investment",
      label: "الاستثمار",
      icon: BarChart3,
    },
    {
      id: "savings",
      label: "الإحالة",
      icon: Users,
    },
  ];

  return (
    <>
      {/* Mobile Bottom Navigation */}
      <div className="lg:hidden fixed bottom-0 left-0 right-0 bg-white/10 backdrop-blur-md border-t border-white/20 z-50">
        <div className="flex justify-around items-center py-1 px-1 sm:px-2 overflow-x-auto">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;

            return (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className={`flex flex-col items-center justify-center p-1.5 sm:p-2 rounded-lg transition-all duration-300 min-w-[50px] sm:min-w-[60px] flex-shrink-0 ${
                  isActive
                    ? "bg-gradient-to-r from-blue-500/30 to-purple-500/30 text-white shadow-lg transform scale-105"
                    : "text-gray-300 hover:text-white hover:bg-white/10"
                }`}
              >
                <Icon
                  className={`w-4 h-4 sm:w-5 sm:h-5 mb-0.5 sm:mb-1 ${isActive ? "animate-pulse" : ""}`}
                />
                <span className="text-xs font-medium leading-tight">
                  {tab.label}
                </span>
                {isActive && (
                  <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 w-4 sm:w-6 h-0.5 sm:h-1 bg-gradient-to-r from-blue-400 to-purple-400 rounded-full"></div>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Desktop Right Side Navigation */}
      <div className="hidden lg:flex fixed right-0 top-1/2 transform -translate-y-1/2 bg-white/10 backdrop-blur-md border-l border-white/20 z-50 rounded-l-2xl">
        <div className="flex flex-col justify-center items-center py-4 px-2 space-y-2">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;

            return (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className={`flex flex-col items-center justify-center p-3 rounded-xl transition-all duration-300 min-w-[70px] group ${
                  isActive
                    ? "bg-gradient-to-r from-blue-500/30 to-purple-500/30 text-white shadow-lg transform scale-105"
                    : "text-gray-300 hover:text-white hover:bg-white/10"
                }`}
                title={tab.label}
              >
                <Icon
                  className={`w-6 h-6 mb-1 ${isActive ? "animate-pulse" : ""}`}
                />
                <span className="text-xs font-medium leading-tight text-center">
                  {tab.label}
                </span>
                {isActive && (
                  <div className="absolute right-0 top-1/2 transform -translate-y-1/2 w-1 h-8 bg-gradient-to-b from-blue-400 to-purple-400 rounded-l-full"></div>
                )}
              </button>
            );
          })}
        </div>
      </div>
    </>
  );
}

export default BottomNavBar;
