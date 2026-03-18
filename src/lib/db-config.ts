/**
 * Database Configuration
 * Isolates all database-related environment variables and settings
 * This file serves as a single source of truth for database configuration
 */

// Environment variables for Supabase
export const DB_CONFIG = {
  // Client-side configuration (frontend can access)
  url: import.meta.env.VITE_SUPABASE_URL,
  anonKey: import.meta.env.VITE_SUPABASE_ANON_KEY,

  // Server-side configuration (backend only - not exposed to frontend)
  // These are typically used in edge functions or backend services
  serviceKey: import.meta.env.SUPABASE_SERVICE_KEY,
  projectId: import.meta.env.SUPABASE_PROJECT_ID,

  // Configuration status
  isConfigured: !!(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY),
  isDevelopment: import.meta.env.MODE === "development",
  isProduction: import.meta.env.MODE === "production",

  // Feature flags based on configuration
  features: {
    authentication: !!(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY),
    realtime: !!(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY),
    storage: !!(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY),
  },
};

/**
 * Validate database configuration
 * Checks if all required variables are set
 */
export const validateDBConfig = () => {
  const errors: string[] = [];

  if (!DB_CONFIG.url) {
    errors.push("Missing VITE_SUPABASE_URL environment variable");
  }
  if (!DB_CONFIG.anonKey) {
    errors.push("Missing VITE_SUPABASE_ANON_KEY environment variable");
  }

  if (errors.length > 0) {
    console.warn("⚠️ Database configuration errors:", errors);
    return false;
  }

  console.log("✅ Database configuration is valid");
  return true;
};

/**
 * Get database connection string (for logging/debugging only)
 * Masks sensitive information
 */
export const getDBConnectionInfo = () => {
  return {
    url: DB_CONFIG.url ? `${DB_CONFIG.url.substring(0, 30)}...` : "Not configured",
    anonKeyLength: DB_CONFIG.anonKey?.length || 0,
    configured: DB_CONFIG.isConfigured,
  };
};

/**
 * Check if database feature is available
 */
export const isDBFeatureAvailable = (feature: keyof typeof DB_CONFIG.features): boolean => {
  return DB_CONFIG.isConfigured && DB_CONFIG.features[feature];
};
