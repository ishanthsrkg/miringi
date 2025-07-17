import { useState, useEffect } from "react";
import {
  getUserProfile,
  updateUserProfile,
  getUserBalance,
  updateUserBalance,
  createTransaction,
  getUserTransactions,
  createInvestment,
  getUserInvestments,
  updateInvestment,
  createSavingsGoal,
  getUserSavingsGoals,
  updateSavingsGoal,
  getUserCards,
  updateCard,
  createNotification,
  getUserNotifications,
  markNotificationAsRead,
  createReferral,
  getUserReferrals,
  updateInvestmentBalance,
  getInvestmentBalance,
  supabase,
} from "../lib/supabase";
import { generateSecureCardNumber } from "../utils/security";

export const useDatabase = (userId: string | null) => {
  const [profile, setProfile] = useState<any>(null);
  const [balance, setBalance] = useState<any>(null);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [investments, setInvestments] = useState<any[]>([]);
  const [savingsGoals, setSavingsGoals] = useState<any[]>([]);
  const [cards, setCards] = useState<any[]>([]);
  const [notifications, setNotifications] = useState<any[]>([]);
  const [referrals, setReferrals] = useState<any[]>([]);
  const [investmentBalance, setInvestmentBalance] = useState<number>(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Initialize with sample notifications only (no fake balance)
  useEffect(() => {
    if (userId && !loading) {
      console.log("🔄 Setting initial sample notifications for better UX");
      // Set sample notifications only if none exist and we haven't loaded any yet
      if (notifications.length === 0) {
        setNotifications([
          {
            id: "sample-1",
            type: "success",
            title: "مرحباً بك",
            message: "تم تسجيل دخولك بنجاح",
            created_at: new Date().toISOString(),
            is_read: false,
          },
          {
            id: "sample-2",
            type: "info",
            title: "نصيحة",
            message:
              "قم بتوثيق حسابك كي تتحصل على رقم الحساب التسلسلي والاستفادة من جميع مزايا البنك",
            created_at: new Date(Date.now() - 3600000).toISOString(),
            is_read: false,
          },
        ]);
      }
    }
  }, [userId, loading]);

  // Initialize user cards if they don't exist
  const initializeUserCards = async (userId: string) => {
    try {
      console.log("🃏 Initializing user cards for:", userId);
      const { data: existingCards, error: cardsError } =
        await getUserCards(userId);

      if (cardsError) {
        console.error("❌ Error checking existing cards:", cardsError);
        return;
      }

      if (!existingCards || existingCards.length === 0) {
        console.log("📝 Creating default cards for new user");
        // Create default cards for the user
        const solidCardNumber = generateSecureCardNumber();
        const virtualCardNumber = generateSecureCardNumber();

        const cardInserts = await Promise.allSettled([
          supabase.from("cards").insert({
            user_id: userId,
            card_number: solidCardNumber,
            card_type: "solid",
            is_frozen: false,
            spending_limit: 100000,
            balance: 0,
            currency: "dzd",
          }),
          supabase.from("cards").insert({
            user_id: userId,
            card_number: virtualCardNumber,
            card_type: "virtual",
            is_frozen: false,
            spending_limit: 50000,
            balance: 0,
            currency: "dzd",
          }),
        ]);

        cardInserts.forEach((result, index) => {
          if (result.status === "rejected") {
            console.error(
              `❌ Failed to create card ${index + 1}:`,
              result.reason,
            );
          } else {
            console.log(`✅ Successfully created card ${index + 1}`);
          }
        });
      } else {
        console.log(`✅ User already has ${existingCards.length} cards`);
      }
    } catch (error) {
      console.error("💥 Unexpected error initializing user cards:", error);
    }
  };

  // Initialize user balance if it doesn't exist
  const initializeUserBalance = async (userId: string) => {
    try {
      console.log("💰 Initializing user balance for:", userId);
      const { data: existingBalance, error: balanceError } =
        await getUserBalance(userId);

      if (balanceError && balanceError.code !== "PGRST116") {
        console.error("❌ Error checking existing balance:", balanceError);
        // For Google users, the database trigger should have created the balance
        // Wait and retry once more
        console.log("⏳ انتظار إضافي لإعداد الرصيد من قاعدة البيانات...");
        await new Promise((resolve) => setTimeout(resolve, 2000));

        const { data: retryBalance } = await getUserBalance(userId);
        if (retryBalance) {
          console.log(
            "✅ تم العثور على الرصيد بعد المحاولة الثانية:",
            retryBalance.dzd,
          );
          setBalance(retryBalance);
          return;
        }

        // Set local fallback balance if still no balance found
        console.log("⚠️ Setting zero balance due to error");
        setBalance({
          dzd: 0,
          eur: 0,
          usd: 0,
          gbp: 0,
          investment_balance: 0,
        });
        return;
      }

      if (!existingBalance) {
        console.log("📝 Creating initial balance for new user");
        // Create balance with zero amounts
        const initialBalance = {
          dzd: 0,
          eur: 0,
          usd: 0,
          gbp: 0,
          investment_balance: 0,
        };
        setBalance(initialBalance);

        const { data: newBalance, error: insertError } = await supabase
          .from("balances")
          .insert({
            user_id: userId,
            dzd: 0,
            eur: 0,
            usd: 0,
            gbp: 0,
            investment_balance: 0,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (insertError) {
          console.error("❌ Failed to create initial balance:", insertError);
          // Keep the initial balance in local state
          console.log("⚠️ Keeping initial balance in local state");
        } else {
          console.log("✅ Successfully created initial balance:", newBalance);
          setBalance(newBalance);
        }
      } else {
        console.log("✅ User already has balance:", existingBalance.dzd);
        setBalance(existingBalance);
      }
    } catch (error) {
      console.error("💥 Unexpected error initializing user balance:", error);
      // Set zero balance on any error
      console.log("⚠️ Setting zero balance due to unexpected error");
      setBalance({
        dzd: 0,
        eur: 0,
        usd: 0,
        gbp: 0,
        investment_balance: 0,
      });
    }
  };

  // Initialize user in directory tables for transfers
  const initializeUserInDirectory = async (userId: string) => {
    if (!userId) return;

    try {
      console.log("📁 Initializing user in directory tables for:", userId);

      // Get user profile data
      const { data: userProfile } = await getUserProfile(userId);
      if (!userProfile) {
        console.log(
          "⚠️ No user profile found, skipping directory initialization",
        );
        return;
      }

      const emailNormalized = userProfile.email?.toLowerCase().trim() || "";

      // Insert into user_directory
      const { error: directoryError } = await supabase
        .from("user_directory")
        .upsert(
          {
            user_id: userId,
            email: userProfile.email,
            email_normalized: emailNormalized,
            full_name: userProfile.full_name || "مستخدم جديد",
            account_number: userProfile.account_number,
            phone: userProfile.phone || "",
            can_receive_transfers: true,
            is_active: true,
            updated_at: new Date().toISOString(),
          },
          {
            onConflict: "user_id",
          },
        );

      if (directoryError) {
        console.error(
          "❌ Error inserting into user_directory:",
          directoryError,
        );
      } else {
        console.log("✅ Successfully initialized user in directory");
      }

      // Insert into simple_transfers_users
      const { error: transfersError } = await supabase
        .from("simple_transfers_users")
        .upsert(
          {
            user_id: userId,
            email: userProfile.email,
            email_normalized: emailNormalized,
            full_name: userProfile.full_name || "مستخدم جديد",
            account_number: userProfile.account_number,
            phone: userProfile.phone || "",
            can_receive_transfers: true,
            is_active: true,
            updated_at: new Date().toISOString(),
          },
          {
            onConflict: "user_id",
          },
        );

      if (transfersError) {
        console.error(
          "❌ Error inserting into simple_transfers_users:",
          transfersError,
        );
      } else {
        console.log("✅ Successfully initialized user in transfers table");
      }
    } catch (error) {
      console.error(
        "💥 Unexpected error initializing user in directory:",
        error,
      );
    }
  };

  // Load user data with enhanced error handling for new users
  const loadUserData = async () => {
    if (!userId) {
      console.log("⚠️ No userId provided to loadUserData");
      setLoading(false);
      return;
    }

    console.log("🔄 Loading user data for:", userId);
    setLoading(true);
    setError(null);

    try {
      // Initialize user data if needed with better error handling
      console.log("🔧 Initializing user data...");
      await Promise.allSettled([
        initializeUserBalance(userId),
        initializeUserCards(userId),
        initializeUserInDirectory(userId),
      ]);

      // Add a small delay to ensure database triggers have completed
      await new Promise((resolve) => setTimeout(resolve, 1000));

      // Load all user data in parallel with individual error handling
      console.log("📊 Loading user data from database...");
      const results = await Promise.allSettled([
        getUserProfile(userId),
        getUserBalance(userId),
        getUserTransactions(userId),
        getUserInvestments(userId),
        getUserSavingsGoals(userId),
        getUserCards(userId),
        getUserNotifications(userId),
        getUserReferrals(userId),
        getInvestmentBalance(userId),
      ]);

      // Process results with individual error handling
      const [
        profileRes,
        balanceRes,
        transactionsRes,
        investmentsRes,
        goalsRes,
        cardsRes,
        notificationsRes,
        referralsRes,
        investmentBalanceRes,
      ] = results;

      // Handle profile data
      if (profileRes.status === "fulfilled" && profileRes.value.data) {
        console.log("✅ Profile loaded successfully");
        setProfile(profileRes.value.data);
      } else {
        console.warn(
          "⚠️ Failed to load profile:",
          profileRes.status === "rejected" ? profileRes.reason : "No data",
        );
      }

      // Handle balance data with better error handling
      if (balanceRes.status === "fulfilled" && balanceRes.value.data) {
        console.log(
          "✅ Balance loaded successfully:",
          balanceRes.value.data.dzd,
        );
        setBalance(balanceRes.value.data);
        // Also set investment balance from the main balance record
        if (balanceRes.value.data.investment_balance !== undefined) {
          setInvestmentBalance(balanceRes.value.data.investment_balance);
        }
      } else {
        console.warn(
          "⚠️ Failed to load balance, retrying initialization:",
          balanceRes.status === "rejected" ? balanceRes.reason : "No data",
        );
        // Retry balance initialization
        try {
          await initializeUserBalance(userId);
          const retryBalance = await getUserBalance(userId);
          if (retryBalance.data) {
            console.log("✅ Balance retry successful:", retryBalance.data.dzd);
            setBalance(retryBalance.data);
            setInvestmentBalance(retryBalance.data.investment_balance || 0);
          } else {
            console.log("⚠️ Setting zero balance after retry failed");
            setBalance({
              dzd: 0,
              eur: 0,
              usd: 0,
              gbp: 0,
              investment_balance: 0,
            });
          }
        } catch (retryError) {
          console.error("Failed to retry balance initialization:", retryError);
          console.log("⚠️ Setting zero balance after error");
          setBalance({
            dzd: 0,
            eur: 0,
            usd: 0,
            gbp: 0,
            investment_balance: 0,
          });
        }
      }

      // Handle other data with fallbacks
      if (
        transactionsRes.status === "fulfilled" &&
        transactionsRes.value.data
      ) {
        console.log(
          "✅ Transactions loaded:",
          transactionsRes.value.data.length,
        );
        setTransactions(transactionsRes.value.data);
      } else {
        console.warn("⚠️ Failed to load transactions, using empty array");
        setTransactions([]);
      }

      if (investmentsRes.status === "fulfilled" && investmentsRes.value.data) {
        console.log("✅ Investments loaded:", investmentsRes.value.data.length);
        setInvestments(investmentsRes.value.data);
      } else {
        console.warn("⚠️ Failed to load investments, using empty array");
        setInvestments([]);
      }

      if (goalsRes.status === "fulfilled" && goalsRes.value.data) {
        console.log("✅ Savings goals loaded:", goalsRes.value.data.length);
        setSavingsGoals(goalsRes.value.data);
      } else {
        console.warn("⚠️ Failed to load savings goals, using empty array");
        setSavingsGoals([]);
      }

      if (cardsRes.status === "fulfilled" && cardsRes.value.data) {
        console.log("✅ Cards loaded:", cardsRes.value.data.length);
        setCards(cardsRes.value.data);
      } else {
        console.warn("⚠️ Failed to load cards, retrying initialization");
        try {
          await initializeUserCards(userId);
          const retryCards = await getUserCards(userId);
          if (retryCards.data) {
            console.log("✅ Cards retry successful:", retryCards.data.length);
            setCards(retryCards.data);
          } else {
            setCards([]);
          }
        } catch (retryError) {
          console.error("Failed to retry cards initialization:", retryError);
          setCards([]);
        }
      }

      if (
        notificationsRes.status === "fulfilled" &&
        notificationsRes.value.data &&
        notificationsRes.value.data.length > 0
      ) {
        console.log(
          "✅ Notifications loaded:",
          notificationsRes.value.data.length,
        );
        setNotifications(notificationsRes.value.data);
      } else {
        console.warn(
          "⚠️ Failed to load notifications or no notifications found",
        );
        // Keep existing notifications if we have them, otherwise set sample data
        if (notifications.length === 0) {
          setNotifications([
            {
              id: "sample-1",
              type: "success",
              title: "مرحباً بك",
              message: "تم تسجيل دخولك بنجاح",
              created_at: new Date().toISOString(),
              is_read: false,
            },
            {
              id: "sample-2",
              type: "info",
              title: "نصيحة",
              message:
                "قم بتوثيق حسابك كي تتحصل على رقم الحساب التسلسلي والاستفادة من جميع مزايا البنك",
              created_at: new Date(Date.now() - 3600000).toISOString(),
              is_read: false,
            },
          ]);
        }
      }

      if (referralsRes.status === "fulfilled" && referralsRes.value.data) {
        setReferrals(referralsRes.value.data);
      } else {
        console.warn("⚠️ Failed to load referrals, using empty array");
        setReferrals([]);
      }

      // Handle investment balance separately if not already set from main balance
      if (
        investmentBalanceRes.status === "fulfilled" &&
        investmentBalanceRes.value.data &&
        investmentBalance === 0
      ) {
        setInvestmentBalance(
          investmentBalanceRes.value.data.investment_balance || 0,
        );
      }

      console.log("✅ User data loading completed");
    } catch (err: any) {
      console.error("💥 Unexpected error loading user data:", err);
      setError(err.message || "خطأ في تحميل بيانات المستخدم");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUserData();
  }, [userId]);

  // Profile operations
  const updateProfile = async (updates: any) => {
    if (!userId) return;

    const { data, error } = await updateUserProfile(userId, updates);
    if (error) {
      setError(error.message);
      return { error };
    }

    setProfile(data);
    return { data };
  };

  // Balance operations
  const updateBalance = async (balances: any) => {
    if (!userId) return;

    console.log("updateBalance called with:", {
      userId,
      balances,
      currentBalance: balance,
    });

    try {
      // Only pass the fields that are explicitly being updated
      // This allows the database function to preserve other fields
      const updatedBalances: any = {};

      if (balances.dzd !== undefined)
        updatedBalances.dzd = Math.max(0, balances.dzd);
      if (balances.eur !== undefined)
        updatedBalances.eur = Math.max(0, balances.eur);
      if (balances.usd !== undefined)
        updatedBalances.usd = Math.max(0, balances.usd);
      if (balances.gbp !== undefined)
        updatedBalances.gbp = Math.max(0, balances.gbp);
      if (balances.investment_balance !== undefined) {
        updatedBalances.investment_balance = Math.max(
          0,
          balances.investment_balance,
        );
      }

      const { data, error } = await updateUserBalance(userId, updatedBalances);
      if (error) {
        console.error("Database update error:", error);
        setError(error.message);
        return { error };
      }

      console.log("Database update successful, new data:", data);
      if (data) {
        setBalance(data);
        // Update investment balance state if it was updated
        if (data.investment_balance !== undefined) {
          setInvestmentBalance(data.investment_balance);
        }
      }
      return { data };
    } catch (err: any) {
      console.error("Unexpected error in updateBalance:", err);
      setError(err.message || "خطأ في تحديث الرصيد");
      return { error: { message: err.message || "خطأ في تحديث الرصيد" } };
    }
  };

  // Transaction operations
  const addTransaction = async (transaction: any) => {
    if (!userId) return;

    // التحقق من صحة البيانات قبل الإرسال
    const { validateTransactionData } = await import("../utils/validation");
    const validation = validateTransactionData(transaction);

    if (!validation.isValid) {
      const errorMessage = validation.errors.join(", ");
      setError(errorMessage);
      return { error: { message: errorMessage } };
    }

    const { data, error } = await createTransaction({
      ...transaction,
      user_id: userId,
    });
    if (error) {
      setError(error.message);
      return { error };
    }

    setTransactions((prev) => [data, ...prev]);
    return { data };
  };

  // Investment operations
  const addInvestment = async (investment: any) => {
    if (!userId) return;

    // التحقق من صحة البيانات قبل الإرسال
    const { validateInvestmentData } = await import("../utils/validation");
    const validation = validateInvestmentData(investment);

    if (!validation.isValid) {
      const errorMessage = validation.errors.join(", ");
      setError(errorMessage);
      return { error: { message: errorMessage } };
    }

    const { data, error } = await createInvestment({
      ...investment,
      user_id: userId,
    });
    if (error) {
      setError(error.message);
      return { error };
    }

    setInvestments((prev) => [data, ...prev]);
    return { data };
  };

  const updateInvestmentStatus = async (investmentId: string, updates: any) => {
    const { data, error } = await updateInvestment(investmentId, updates);
    if (error) {
      setError(error.message);
      return { error };
    }

    setInvestments((prev) =>
      prev.map((inv) => (inv.id === investmentId ? data : inv)),
    );
    return { data };
  };

  // Savings goals operations
  const addSavingsGoal = async (goal: any) => {
    if (!userId) return;

    const { data, error } = await createSavingsGoal({
      ...goal,
      user_id: userId,
    });
    if (error) {
      setError(error.message);
      return { error };
    }

    setSavingsGoals((prev) => [data, ...prev]);
    return { data };
  };

  const updateGoal = async (goalId: string, updates: any) => {
    const { data, error } = await updateSavingsGoal(goalId, updates);
    if (error) {
      setError(error.message);
      return { error };
    }

    setSavingsGoals((prev) =>
      prev.map((goal) => (goal.id === goalId ? data : goal)),
    );
    return { data };
  };

  // Card operations
  const updateCardStatus = async (cardId: string, updates: any) => {
    const { data, error } = await updateCard(cardId, updates);
    if (error) {
      setError(error.message);
      return { error };
    }

    setCards((prev) => prev.map((card) => (card.id === cardId ? data : card)));
    return { data };
  };

  // Charge card with any currency including DZD
  const chargeCardWithCurrency = async (
    amount: number,
    currency: "dzd" | "eur" | "usd" | "gbp",
    cardType: "solid" | "virtual",
  ) => {
    if (!userId) return { error: { message: "معرف المستخدم غير متوفر" } };

    try {
      // Check if user has sufficient balance in the selected currency
      const currentBalance = balance || { dzd: 0, eur: 0, usd: 0, gbp: 0 };
      const availableAmount = currentBalance[currency] || 0;

      if (amount > availableAmount) {
        return { error: { message: "الرصيد غير كافي في العملة المحددة" } };
      }

      // Deduct from main account balance
      const newBalance = { ...currentBalance };
      newBalance[currency] = availableAmount - amount;

      const { data, error } = await updateBalance(newBalance);
      if (error) {
        return { error };
      }

      // Create transaction record
      const transactionData = {
        type: "card_charge",
        amount: amount,
        currency: currency,
        description: `شحن البطاقة ${cardType === "solid" ? "الصلبة" : "الافتراضية"} من ${currency.toUpperCase()}`,
        status: "completed",
      };
      await addTransaction(transactionData);

      return { data, error: null };
    } catch (err: any) {
      console.error("Error charging card:", err);
      return { error: { message: err.message || "خطأ في شحن البطاقة" } };
    }
  };

  // Get card balance from database
  const getCardBalance = async (cardId: string) => {
    try {
      const { data, error } = await supabase
        .from("cards")
        .select("balance, currency")
        .eq("id", cardId)
        .single();

      if (error) {
        console.error("Error getting card balance:", error);
        return { data: null, error };
      }

      return { data, error: null };
    } catch (err: any) {
      console.error("Unexpected error in getCardBalance:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // Update card balance in database
  const updateCardBalance = async (
    cardId: string,
    amount: number,
    currency: string,
  ) => {
    try {
      const { data, error } = await supabase
        .from("cards")
        .update({
          balance: amount,
          currency: currency,
          updated_at: new Date().toISOString(),
        })
        .eq("id", cardId)
        .select()
        .single();

      if (error) {
        console.error("Error updating card balance:", error);
        return { data: null, error };
      }

      return { data, error: null };
    } catch (err: any) {
      console.error("Unexpected error in updateCardBalance:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // Notification operations
  const addNotification = async (notification: any) => {
    if (!userId) return;

    try {
      const { data, error } = await createNotification({
        ...notification,
        user_id: userId,
      });
      if (error) {
        console.error("Error creating notification:", error);
        setError(error.message);
        return { error };
      }

      console.log("Notification created successfully:", data);
      setNotifications((prev) => [data, ...prev]);
      return { data };
    } catch (err: any) {
      console.error("Unexpected error in addNotification:", err);
      setError(err.message);
      return { error: { message: err.message } };
    }
  };

  const markAsRead = async (notificationId: string) => {
    try {
      const { data, error } = await markNotificationAsRead(notificationId);
      if (error) {
        console.error("Error marking notification as read:", error);
        setError(error.message);
        return { error };
      }

      console.log("Notification marked as read:", data);
      setNotifications((prev) =>
        prev.map((notif) => (notif.id === notificationId ? data : notif)),
      );
      return { data };
    } catch (err: any) {
      console.error("Unexpected error in markAsRead:", err);
      setError(err.message);
      return { error: { message: err.message } };
    }
  };

  // Create system notification for important events
  const createSystemNotification = async (
    type: "success" | "error" | "info" | "warning",
    title: string,
    message: string,
  ) => {
    if (!userId) return;

    try {
      const notificationData = {
        type,
        title,
        message,
        is_read: false,
      };

      const result = await addNotification(notificationData);

      // Also show browser notification if enabled
      if ("Notification" in window && Notification.permission === "granted") {
        new Notification(title, {
          body: message,
          icon: "/vite.svg",
        });
      }

      return result;
    } catch (error) {
      console.error("Error creating system notification:", error);
    }
  };

  // Referral operations
  const addReferral = async (referral: any) => {
    if (!userId) return;

    const { data, error } = await createReferral({
      ...referral,
      referrer_id: userId,
    });
    if (error) {
      setError(error.message);
      return { error };
    }

    setReferrals((prev) => [data, ...prev]);
    return { data };
  };

  // Investment balance operations
  const updateUserInvestmentBalance = async (
    amount: number,
    operation: "add" | "subtract",
  ) => {
    if (!userId) {
      console.error("No user ID provided for investment balance update");
      return { error: { message: "معرف المستخدم غير متوفر" } };
    }

    console.log(
      `🔄 Updating investment balance: ${operation} ${amount} for user ${userId}`,
    );

    try {
      const { data, error } = await updateInvestmentBalance(
        userId,
        amount,
        operation,
      );

      if (error) {
        console.error("Investment balance update error:", error);
        setError(error.message);
        return { error };
      }

      if (data) {
        console.log("Investment balance updated successfully:", data);
        setInvestmentBalance(data.investment_balance || 0);
        // Also update the main balance state to reflect the change
        setBalance((prev) => ({
          ...prev,
          ...data,
        }));

        // Create notification for investment operation
        const operationText =
          operation === "add" ? "استثمار" : "سحب من الاستثمار";
        await createSystemNotification(
          "success",
          `تم ${operationText} بنجاح`,
          `تم ${operationText} مبلغ ${amount.toLocaleString()} دج`,
        );
      }

      return { data };
    } catch (err: any) {
      console.error("Unexpected error in updateUserInvestmentBalance:", err);
      const errorMessage =
        err.message || "خطأ غير متوقع في تحديث رصيد الاستثمار";
      setError(errorMessage);
      return { error: { message: errorMessage } };
    }
  };

  // TRANSFER OPERATIONS - Unified simplified system
  // عمليات التحويل - النظام الموحد المبسط
  const processTransfer = async (
    amount: number,
    recipientIdentifier: string,
    description?: string,
  ) => {
    if (!profile?.email) {
      console.error("❌ No user email available for transfer");
      return { error: { message: "البريد الإلكتروني غير متوفر" } };
    }

    try {
      console.log(
        `🔄 Processing unified transfer: ${amount} DZD to ${recipientIdentifier}`,
        {
          senderEmail: profile.email,
          amount,
          recipientIdentifier: recipientIdentifier.trim(),
          description,
          timestamp: new Date().toISOString(),
        },
      );

      // INPUT VALIDATION - التحقق من صحة المدخلات
      if (!amount || amount <= 0) {
        return { error: { message: "مبلغ التحويل يجب أن يكون أكبر من صفر" } };
      }

      if (!recipientIdentifier || recipientIdentifier.trim().length === 0) {
        return { error: { message: "معرف المستلم مطلوب" } };
      }

      if (amount < 100) {
        return { error: { message: "الحد الأدنى للتحويل هو 100 دج" } };
      }

      // DATABASE CALL - استدعاء قاعدة البيانات
      // Use the unified simplified transfer function
      const { data, error } = await supabase.rpc("process_simple_transfer", {
        p_sender_email: profile.email,
        p_recipient_identifier: recipientIdentifier.trim(),
        p_amount: parseFloat(amount.toString()),
        p_description: description || "تحويل",
      });

      console.log("🔍 Database response:", { data, error });

      if (error) {
        console.error("❌ Transfer RPC error:", error);
        return {
          error: {
            message: error.message || "فشل في إجراء التحويل",
          },
        };
      }

      if (!data || !Array.isArray(data) || data.length === 0) {
        console.error("❌ No data returned from database function");
        return { error: { message: "لم يتم إرجاع نتيجة من قاعدة البيانات" } };
      }

      const result = data[0];
      console.log("📊 Transfer result:", result);

      if (!result || result.success === false) {
        console.error("❌ Transfer failed:", result);
        return {
          error: {
            message: result?.message || "فشل في معالجة التحويل",
          },
        };
      }

      console.log("✅ Transfer successful:", {
        reference: result.reference_number,
        newBalance: result.sender_new_balance,
      });

      // Create success notification
      await createSystemNotification(
        "success",
        "تم التحويل بنجاح",
        `تم تحويل ${amount.toLocaleString()} دج إلى ${recipientIdentifier} برقم المرجع: ${result.reference_number}`,
      );

      // LOCAL STATE UPDATE - تحديث الحالة المحلية
      // Update local balance state immediately
      if (
        result.sender_new_balance !== undefined &&
        result.sender_new_balance !== null
      ) {
        const newBalance = parseFloat(result.sender_new_balance.toString());
        console.log("💰 Updating local balance to:", newBalance);
        setBalance((prev) => ({
          ...prev,
          dzd: newBalance,
        }));
      }

      // Reload user data to show the new transfer in transactions
      setTimeout(() => {
        console.log("🔄 Reloading user data after transfer");
        loadUserData();
      }, 1000);

      return {
        data: {
          success: true,
          message: result.message || "تم التحويل بنجاح",
          reference: result.reference_number,
          newBalance: result.sender_new_balance,
          processingTime: "< 1 ثانية",
        },
        error: null,
      };
    } catch (error: any) {
      console.error("💥 Unexpected error in processTransfer:", {
        message: error.message,
        stack: error.stack,
        name: error.name,
      });

      // Create error notification
      await createSystemNotification(
        "error",
        "فشل في التحويل",
        error.message || "حدث خطأ غير متوقع أثناء التحويل",
      );

      return {
        error: {
          message: error.message || "حدث خطأ غير متوقع أثناء التحويل",
        },
      };
    }
  };

  // TRANSFER HISTORY - Simplified system
  // تاريخ التحويلات - النظام المبسط
  const getInstantTransferHistory = async (limit: number = 50) => {
    if (!profile?.email)
      return { data: null, error: { message: "البريد الإلكتروني غير متوفر" } };

    try {
      const { data, error } = await supabase.rpc(
        "get_transfer_history_simple",
        {
          p_user_email: profile.email,
        },
      );

      if (error) {
        console.error("Error fetching transfer history:", error);
        return { data: null, error };
      }

      return { data: data || [], error: null };
    } catch (err: any) {
      console.error("Unexpected error in getInstantTransferHistory:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // Get recent transactions for home page
  const getRecentTransactions = async (limit: number = 5) => {
    if (!userId && !profile?.email) {
      return { data: [], error: null };
    }

    try {
      // Get regular transactions from transactions table
      const { data: regularTransactions, error: transError } = await supabase
        .from("transactions")
        .select("*")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(limit);

      if (transError) {
        console.error("Error fetching regular transactions:", transError);
      }

      // Get instant transfers from simple_transfers table
      let instantTransfers = [];
      if (profile?.email) {
        const { data: transferData, error: transferError } = await supabase
          .from("simple_transfers")
          .select("*")
          .or(
            `sender_email.eq.${profile.email},recipient_email.eq.${profile.email}`,
          )
          .order("created_at", { ascending: false })
          .limit(limit);

        if (transferError) {
          console.error("Error fetching instant transfers:", transferError);
        } else if (transferData) {
          // Transform instant transfers to match transaction format
          instantTransfers = transferData.map((transfer) => ({
            id: transfer.id,
            type:
              transfer.sender_email === profile.email
                ? "transfer_sent"
                : "instant_transfer_received",
            amount:
              transfer.sender_email === profile.email
                ? -transfer.amount
                : transfer.amount,
            currency: "dzd",
            description:
              transfer.description ||
              (transfer.sender_email === profile.email
                ? "تحويل صادر"
                : "تحويل وارد"),
            reference: transfer.reference_number,
            recipient:
              transfer.sender_email === profile.email
                ? transfer.recipient_email
                : transfer.sender_email,
            status: transfer.status || "completed",
            created_at: transfer.created_at,
            is_instant: true,
            sender_name: transfer.sender_name,
            recipient_name: transfer.recipient_name,
          }));
        }
      }

      // Combine and sort all transactions
      const allTransactions = [
        ...(regularTransactions || []).map((t) => ({
          ...t,
          is_instant: false,
        })),
        ...instantTransfers,
      ]
        .sort(
          (a, b) =>
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
        )
        .slice(0, limit);

      return { data: allTransactions, error: null };
    } catch (err: any) {
      console.error("Unexpected error in getRecentTransactions:", err);
      return { data: [], error: { message: err.message } };
    }
  };

  // Get transfer history (legacy)
  const getTransferHistory = async () => {
    if (!userId)
      return { data: null, error: { message: "معرف المستخدم غير متوفر" } };

    try {
      const { data, error } = await supabase
        .from("transfer_requests")
        .select(
          `
          *,
          recipient:users!transfer_requests_recipient_id_fkey(full_name, email)
        `,
        )
        .eq("sender_id", userId)
        .order("created_at", { ascending: false })
        .limit(50);

      if (error) {
        console.error("Error fetching transfer history:", error);
        return { data: null, error };
      }

      return { data, error: null };
    } catch (err: any) {
      console.error("Unexpected error in getTransferHistory:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // Get instant transfer stats and limits
  const getInstantTransferStats = async () => {
    if (!userId)
      return { data: null, error: { message: "معرف المستخدم غير متوفر" } };

    try {
      const { data, error } = await supabase.rpc("get_instant_transfer_stats", {
        p_user_id: userId,
      });

      if (error) {
        console.error("Error fetching instant transfer stats:", error);
        return { data: null, error };
      }

      return { data: data?.[0] || null, error: null };
    } catch (err: any) {
      console.error("Unexpected error in getInstantTransferStats:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // Check instant transfer limits
  const checkInstantTransferLimits = async (amount: number) => {
    if (!userId)
      return { data: null, error: { message: "معرف المستخدم غير متوفر" } };

    try {
      const { data, error } = await supabase.rpc(
        "check_instant_transfer_limits",
        {
          p_user_id: userId,
          p_amount: amount,
        },
      );

      if (error) {
        console.error("Error checking instant transfer limits:", error);
        return { data: null, error };
      }

      return { data: data?.[0] || null, error: null };
    } catch (err: any) {
      console.error("Unexpected error in checkInstantTransferLimits:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // Get transfer limits (legacy)
  const getTransferLimits = async () => {
    if (!userId)
      return { data: null, error: { message: "معرف المستخدم غير متوفر" } };

    try {
      const { data, error } = await supabase
        .from("transfer_limits")
        .select("*")
        .eq("user_id", userId)
        .single();

      if (error && error.code !== "PGRST116") {
        // PGRST116 is "not found"
        console.error("Error fetching transfer limits:", error);
        return { data: null, error };
      }

      return { data, error: null };
    } catch (err: any) {
      console.error("Unexpected error in getTransferLimits:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // USER SEARCH - Enhanced unified system with multiple fallbacks
  // البحث عن المستخدمين - النظام الموحد المحسن
  const searchUsers = async (query: string) => {
    if (!query || query.trim().length < 2) {
      return { data: [], error: null };
    }

    try {
      const searchTerm = query.trim();
      console.log("🔍 Searching users with query:", searchTerm);

      // Method 1: Use the enhanced RPC function
      const { data: rpcData, error: rpcError } = await supabase.rpc(
        "find_user_simple",
        {
          p_identifier: searchTerm,
        },
      );

      if (!rpcError && rpcData && rpcData.length > 0) {
        console.log("✅ Found users via RPC:", rpcData);
        const transformedData = rpcData.map((user: any) => ({
          email: user.user_email,
          full_name: user.user_name,
          account_number: user.account_number,
          balance: user.balance,
        }));
        return { data: transformedData, error: null };
      }

      console.log("⚠️ RPC search failed, trying direct database queries");

      // Method 2: Search in user_directory with comprehensive matching
      const { data: directoryData, error: directoryError } = await supabase
        .from("user_directory")
        .select(
          `
          email,
          full_name,
          account_number,
          user_id
        `,
        )
        .or(
          `email.eq.${searchTerm},email_normalized.eq.${searchTerm.toLowerCase()},account_number.eq.${searchTerm},email.ilike.%${searchTerm}%,account_number.ilike.%${searchTerm}%`,
        )
        .eq("is_active", true)
        .eq("can_receive_transfers", true)
        .limit(10);

      if (!directoryError && directoryData && directoryData.length > 0) {
        console.log("✅ Found users via user_directory:", directoryData);

        // Get balances for found users
        const userIds = directoryData.map((u) => u.user_id);
        const { data: balancesData } = await supabase
          .from("balances")
          .select("user_id, dzd")
          .in("user_id", userIds);

        const balanceMap = new Map(
          balancesData?.map((b) => [b.user_id, b.dzd]) || [],
        );

        const transformedData = directoryData.map((user: any) => ({
          email: user.email,
          full_name: user.full_name,
          account_number: user.account_number,
          balance: balanceMap.get(user.user_id) || 0,
        }));
        return { data: transformedData, error: null };
      }

      console.log(
        "⚠️ Directory search failed, trying simple_transfers_users table",
      );

      // Method 3: Search in simple_transfers_users table
      const { data: transfersData, error: transfersError } = await supabase
        .from("simple_transfers_users")
        .select(
          `
          email,
          full_name,
          account_number,
          user_id
        `,
        )
        .or(
          `email.eq.${searchTerm},email_normalized.eq.${searchTerm.toLowerCase()},account_number.eq.${searchTerm}`,
        )
        .eq("is_active", true)
        .eq("can_receive_transfers", true)
        .limit(10);

      if (!transfersError && transfersData && transfersData.length > 0) {
        console.log(
          "✅ Found users via simple_transfers_users:",
          transfersData,
        );

        // Get balances for found users
        const userIds = transfersData.map((u) => u.user_id);
        const { data: balancesData } = await supabase
          .from("balances")
          .select("user_id, dzd")
          .in("user_id", userIds);

        const balanceMap = new Map(
          balancesData?.map((b) => [b.user_id, b.dzd]) || [],
        );

        const transformedData = transfersData.map((user: any) => ({
          email: user.email,
          full_name: user.full_name,
          account_number: user.account_number,
          balance: balanceMap.get(user.user_id) || 0,
        }));
        return { data: transformedData, error: null };
      }

      console.log("⚠️ Transfers table search failed, trying main users table");

      // Method 4: Fallback to main users table with comprehensive search
      const { data: usersData, error: usersError } = await supabase
        .from("users")
        .select(
          `
          email,
          full_name,
          account_number,
          id,
          balances(dzd)
        `,
        )
        .or(
          `email.eq.${searchTerm},account_number.eq.${searchTerm},email.ilike.%${searchTerm}%,account_number.ilike.%${searchTerm}%`,
        )
        .eq("is_active", true)
        .limit(10);

      if (!usersError && usersData && usersData.length > 0) {
        console.log("✅ Found users via main users table:", usersData);
        const transformedData = usersData.map((user: any) => ({
          email: user.email,
          full_name: user.full_name,
          account_number: user.account_number,
          balance: user.balances?.[0]?.dzd || 0,
        }));
        return { data: transformedData, error: null };
      }

      console.log("⚠️ All search methods failed or returned no results");
      return { data: [], error: null };
    } catch (err: any) {
      console.error("💥 Unexpected error in searchUsers:", err);
      return { data: [], error: { message: err.message } };
    }
  };

  // Get user balance by identifier
  const getUserBalanceSimple = async (identifier: string) => {
    try {
      const { data, error } = await supabase.rpc("get_user_balance_simple", {
        p_identifier: identifier,
      });

      if (error) {
        console.error("Error getting user balance:", error);
        return { data: null, error };
      }

      return { data: data?.[0] || null, error: null };
    } catch (err: any) {
      console.error("Unexpected error in getUserBalanceSimple:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // Update user balance
  const updateUserBalanceSimple = async (
    identifier: string,
    newBalance: number,
  ) => {
    try {
      const { data, error } = await supabase.rpc("update_user_balance_simple", {
        p_identifier: identifier,
        p_new_balance: newBalance,
      });

      if (error) {
        console.error("Error updating user balance:", error);
        return { data: null, error };
      }

      return { data: data?.[0] || null, error: null };
    } catch (err: any) {
      console.error("Unexpected error in updateUserBalanceSimple:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  // Support Messages Operations
  const sendSupportMessage = async (
    subject: string,
    message: string,
    category: string = "general",
    priority: string = "normal",
  ) => {
    if (!userId) {
      return { error: { message: "معرف المستخدم غير متوفر" } };
    }

    try {
      const { createSupportMessage } = await import("../lib/supabase");
      const { data, error } = await createSupportMessage(
        userId,
        subject,
        message,
        category,
        priority,
      );

      if (error) {
        setError(error.message);
        return { error };
      }

      // Create success notification with email confirmation message
      await createSystemNotification(
        "success",
        "تم إرسال رسالة الدعم بنجاح",
        `تم إرسال رسالتك بنجاح. سيتم الرد عليك في البريد الإلكتروني خلال 24 ساعة. رقم المرجع: ${data?.reference_number || "غير متوفر"}`,
      );

      // Show browser notification for email confirmation
      if ("Notification" in window && Notification.permission === "granted") {
        new Notification("تم إرسال رسالة الدعم", {
          body: "سيتم الرد عليك في البريد الإلكتروني خلال 24 ساعة",
          icon: "/vite.svg",
        });
      }

      return { data };
    } catch (err: any) {
      console.error("Error sending support message:", err);
      setError(err.message);
      return { error: { message: err.message } };
    }
  };

  const getSupportMessages = async () => {
    if (!userId) {
      return { data: [], error: { message: "معرف المستخدم غير متوفر" } };
    }

    try {
      const { getUserSupportMessages } = await import("../lib/supabase");
      const { data, error } = await getUserSupportMessages(userId);

      if (error) {
        console.error("Error getting support messages:", error);
        return { data: [], error };
      }

      return { data: data || [], error: null };
    } catch (err: any) {
      console.error("Error in getSupportMessages:", err);
      return { data: [], error: { message: err.message } };
    }
  };

  // Account Verification Operations
  const getPendingVerifications = async (
    limit: number = 50,
    offset: number = 0,
  ) => {
    try {
      const { data, error } = await supabase.rpc("get_pending_verifications", {
        p_limit: limit,
        p_offset: offset,
      });

      if (error) {
        console.error("Error getting pending verifications:", error);
        return { data: [], error };
      }

      return { data: data || [], error: null };
    } catch (err: any) {
      console.error("Error in getPendingVerifications:", err);
      return { data: [], error: { message: err.message } };
    }
  };

  const getVerificationDetails = async (verificationId: string) => {
    try {
      const { data, error } = await supabase
        .from("account_verifications")
        .select(
          `
          *,
          users!inner(email, full_name, phone)
        `,
        )
        .eq("id", verificationId)
        .single();

      if (error) {
        console.error("Error getting verification details:", error);
        return { data: null, error };
      }

      return { data, error: null };
    } catch (err: any) {
      console.error("Error in getVerificationDetails:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  const approveVerification = async (
    verificationId: string,
    adminNotes?: string,
    adminId?: string,
  ) => {
    try {
      const { data, error } = await supabase.rpc("approve_verification", {
        p_verification_id: verificationId,
        p_admin_notes: adminNotes,
        p_admin_id: adminId,
      });

      if (error) {
        console.error("Error approving verification:", error);
        return { data: null, error };
      }

      const result = data?.[0];
      if (!result?.success) {
        return {
          data: null,
          error: { message: result?.message || "فشل في الموافقة على التوثيق" },
        };
      }

      return { data: result, error: null };
    } catch (err: any) {
      console.error("Error in approveVerification:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  const rejectVerification = async (
    verificationId: string,
    adminNotes?: string,
    adminId?: string,
  ) => {
    try {
      const { data, error } = await supabase.rpc("reject_verification", {
        p_verification_id: verificationId,
        p_admin_notes: adminNotes,
        p_admin_id: adminId,
      });

      if (error) {
        console.error("Error rejecting verification:", error);
        return { data: null, error };
      }

      const result = data?.[0];
      if (!result?.success) {
        return {
          data: null,
          error: { message: result?.message || "فشل في رفض التوثيق" },
        };
      }

      return { data: result, error: null };
    } catch (err: any) {
      console.error("Error in rejectVerification:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  const getVerificationStats = async () => {
    try {
      const { data, error } = await supabase.rpc("get_verification_stats");

      if (error) {
        console.error("Error getting verification stats:", error);
        return { data: null, error };
      }

      return { data: data?.[0] || null, error: null };
    } catch (err: any) {
      console.error("Error in getVerificationStats:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  const getUserVerificationStatus = async (userId: string) => {
    try {
      const { getUserVerificationStatus } = await import("../lib/supabase");
      const { data, error } = await getUserVerificationStatus(userId);

      if (error) {
        console.error("Error getting user verification status:", error);
        return { data: null, error };
      }

      return { data, error: null };
    } catch (err: any) {
      console.error("Error in getUserVerificationStatus:", err);
      return { data: null, error: { message: err.message } };
    }
  };

  return {
    // Data
    profile,
    balance,
    transactions,
    investments,
    savingsGoals,
    cards,
    notifications,
    referrals,
    investmentBalance,
    loading,
    error,

    // Operations
    loadUserData,
    updateProfile,
    updateBalance,
    addTransaction,
    addInvestment,
    updateInvestmentStatus,
    addSavingsGoal,
    updateGoal,
    updateCardStatus,
    addNotification,
    markAsRead,
    createSystemNotification,
    addReferral,
    updateUserInvestmentBalance,
    processTransfer,
    getRecentTransactions,
    getTransferHistory,
    getTransferLimits,
    getInstantTransferHistory,
    getInstantTransferStats,
    checkInstantTransferLimits,
    searchUsers,
    getUserBalanceSimple,
    updateUserBalanceSimple,
    chargeCardWithCurrency,
    getCardBalance,
    updateCardBalance,
    sendSupportMessage,
    getSupportMessages,
    // Account Verification Operations
    getPendingVerifications,
    getVerificationDetails,
    approveVerification,
    rejectVerification,
    getVerificationStats,
    getUserVerificationStatus,
  };
};
