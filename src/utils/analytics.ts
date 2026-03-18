/**
 * Google Analytics Configuration
 * Handles initialization and tracking events
 */

const ANALYTICS_ID = import.meta.env.VITE_GOOGLE_ANALYTICS_ID;

/**
 * Initialize Google Analytics
 * Called once on app startup
 */
export const initializeAnalytics = () => {
  if (!ANALYTICS_ID) {
    console.warn("⚠️ Google Analytics ID not configured. Analytics disabled.");
    return;
  }

  // Verify gtag is available (loaded from index.html)
  if (typeof window !== "undefined" && !("gtag" in window)) {
    console.error("❌ Google Analytics script failed to load");
    return;
  }

  console.log("✅ Google Analytics initialized with ID:", ANALYTICS_ID);
};

/**
 * Track a custom event
 * @param eventName - Name of the event
 * @param parameters - Optional event parameters
 */
export const trackEvent = (
  eventName: string,
  parameters?: Record<string, any>
) => {
  if (!ANALYTICS_ID || typeof window === "undefined" || !("gtag" in window)) {
    return;
  }

  try {
    // @ts-ignore - gtag is injected globally
    window.gtag("event", eventName, parameters || {});
    console.log(`📊 Event tracked: ${eventName}`, parameters);
  } catch (error) {
    console.error("Failed to track event:", error);
  }
};

/**
 * Track page view (automatically done by gtag, but can be called manually)
 * @param pagePath - Path of the page
 * @param pageTitle - Title of the page
 */
export const trackPageView = (pagePath: string, pageTitle?: string) => {
  if (!ANALYTICS_ID || typeof window === "undefined" || !("gtag" in window)) {
    return;
  }

  try {
    // @ts-ignore - gtag is injected globally
    window.gtag("config", ANALYTICS_ID, {
      page_path: pagePath,
      page_title: pageTitle,
    });
    console.log(`📊 Page view tracked: ${pagePath}`);
  } catch (error) {
    console.error("Failed to track page view:", error);
  }
};

/**
 * Track user signup event
 */
export const trackSignup = (signupMethod: string) => {
  trackEvent("sign_up", {
    method: signupMethod,
  });
};

/**
 * Track user login event
 */
export const trackLogin = (loginMethod: string) => {
  trackEvent("login", {
    method: loginMethod,
  });
};

/**
 * Track transaction/transfer event
 */
export const trackTransaction = (transactionType: string, amount?: number) => {
  trackEvent("transaction", {
    transaction_type: transactionType,
    value: amount,
  });
};

/**
 * Set user ID for analytics (after authentication)
 */
export const setAnalyticsUserId = (userId: string) => {
  if (!ANALYTICS_ID || typeof window === "undefined" || !("gtag" in window)) {
    return;
  }

  try {
    // @ts-ignore - gtag is injected globally
    window.gtag("config", ANALYTICS_ID, {
      user_id: userId,
    });
    console.log(`📊 Analytics user ID set:`, userId.substring(0, 10) + "...");
  } catch (error) {
    console.error("Failed to set analytics user ID:", error);
  }
};

/**
 * Clear user ID for analytics (on logout)
 */
export const clearAnalyticsUserId = () => {
  if (!ANALYTICS_ID || typeof window === "undefined" || !("gtag" in window)) {
    return;
  }

  try {
    // @ts-ignore - gtag is injected globally
    window.gtag("config", ANALYTICS_ID, {
      user_id: undefined,
    });
    console.log(`📊 Analytics user ID cleared`);
  } catch (error) {
    console.error("Failed to clear analytics user ID:", error);
  }
};
