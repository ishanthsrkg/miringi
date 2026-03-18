# Database Isolation & Analytics Configuration

## Overview

This document explains how the database has been isolated from the frontend code and how Google Analytics has been configured properly.

## Database Isolation

### Configuration File Structure

The database configuration has been centralized in **`src/lib/db-config.ts`**, which serves as the single source of truth for all database settings.

#### Key Components:

1. **DB_CONFIG Object** - Centralizes all database environment variables:
   ```typescript
   const DB_CONFIG = {
     url: import.meta.env.VITE_SUPABASE_URL,
     anonKey: import.meta.env.VITE_SUPABASE_ANON_KEY,
     serviceKey: import.meta.env.SUPABASE_SERVICE_KEY,
     projectId: import.meta.env.SUPABASE_PROJECT_ID,
     isConfigured: boolean,
     isDevelopment: boolean,
     isProduction: boolean,
     features: { /* feature flags */ }
   };
   ```

2. **Validation Functions**:
   - `validateDBConfig()` - Checks if all required variables are set
   - `getDBConnectionInfo()` - Returns masked connection info (safe for logging)
   - `isDBFeatureAvailable()` - Checks if a specific database feature is enabled

### How It Works

```
Frontend Code
    ↓
src/lib/db-config.ts (Single Configuration Point)
    ↓
src/lib/supabase.ts (Uses DB_CONFIG)
    ↓
Supabase Client Instance
```

**Benefits:**
- ✅ Centralized configuration management
- ✅ No scattered environment variable access
- ✅ Easy feature flag management
- ✅ Safe logging with masked sensitive data
- ✅ Single point to audit all database access

### Environment Variables Required

Create a `.env.local` file with:

```bash
# Frontend (Vite) - These are exposed to the browser
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here

# Backend only (Not exposed to frontend)
SUPABASE_SERVICE_KEY=your_service_key_here
SUPABASE_PROJECT_ID=your_project_id
```

**Important Security Notes:**
- Only `VITE_*` variables are exposed to the frontend (browser)
- `SUPABASE_SERVICE_KEY` should NEVER be exposed to the frontend
- For production, set these in your deployment platform's secret manager

## Google Analytics Setup

### Configuration

Google Analytics has been properly configured with environment variables.

#### Files Modified:

1. **index.html** - Google Analytics script tag with environment variable support
   ```html
   <script async src="https://www.googletagmanager.com/gtag/js?id=%VITE_GOOGLE_ANALYTICS_ID%"></script>
   ```

2. **src/utils/analytics.ts** - Centralized analytics utilities
   ```typescript
   - initializeAnalytics()      // Initialize on app startup
   - trackEvent()               // Track custom events
   - trackPageView()            // Track page views
   - trackSignup()              // Track signup
   - trackLogin()               // Track login
   - trackTransaction()         // Track transactions
   - setAnalyticsUserId()       // Set user ID after login
   - clearAnalyticsUserId()     // Clear user ID after logout
   ```

3. **src/main.tsx** - Analytics initialized on app startup
   ```typescript
   import { initializeAnalytics } from "@/utils/analytics";
   initializeAnalytics();
   ```

### Environment Variables

Add to `.env.local`:

```bash
VITE_GOOGLE_ANALYTICS_ID=G-TPB0NM2CN3
```

### Usage Examples

#### Initialize Analytics (Automatic)
```typescript
// Already called in src/main.tsx
initializeAnalytics();
```

#### Track Events
```typescript
import { trackEvent, trackSignup, trackLogin } from "@/utils/analytics";

// Custom event
trackEvent("user_upgrade", { plan: "premium" });

// Sign up
trackSignup("google");

// Login
trackLogin("email");
```

#### Track User
```typescript
import { setAnalyticsUserId, clearAnalyticsUserId } from "@/utils/analytics";

// After successful login
setAnalyticsUserId(userId);

// After logout
clearAnalyticsUserId();
```

### Security Considerations

✅ **What's Protected:**
- Database credentials never exposed to frontend
- Service keys kept in backend only
- Analytics ID is public (by design - Google Analytics needs it)

❌ **What NOT to Do:**
- Never hardcode API keys in code
- Never commit `.env.local` to git
- Never expose `SUPABASE_SERVICE_KEY` in frontend

## Deployment Checklist

### For Vercel/Netlify/Production:

1. **Set Environment Variables in Platform Settings:**
   ```
   VITE_SUPABASE_URL=<your_value>
   VITE_SUPABASE_ANON_KEY=<your_value>
   VITE_GOOGLE_ANALYTICS_ID=<your_value>
   ```

2. **Backend-only Variables (if using edge functions):**
   ```
   SUPABASE_SERVICE_KEY=<your_value>
   SUPABASE_PROJECT_ID=<your_value>
   ```

3. **Verify Configuration:**
   - Check browser console for "✅ Google Analytics initialized"
   - Check for "✅ Database configuration is valid"
   - No warnings about missing environment variables

### Testing

1. **Local Development:**
   ```bash
   npm run dev
   # Check console logs for configuration status
   ```

2. **Production:**
   - Set all environment variables in deployment platform
   - Verify analytics ID works in Google Analytics dashboard
   - Test database connectivity in production

## File Structure

```
src/
├── lib/
│   ├── db-config.ts          ← Database configuration (NEW)
│   ├── supabase.ts           ← Updated to use db-config
│   └── utils.ts
├── utils/
│   ├── analytics.ts          ← Analytics utilities (NEW)
│   └── ...
├── main.tsx                  ← Analytics initialization
└── ...

.env.example                  ← Updated with analytics ID
index.html                    ← Updated with analytics script
```

## Troubleshooting

### Database Issues
```
❌ "Missing VITE_SUPABASE_URL"
→ Check .env.local or deployment platform settings
→ Ensure variable name starts with VITE_ for frontend
```

### Analytics Issues
```
❌ "Google Analytics script failed to load"
→ Check VITE_GOOGLE_ANALYTICS_ID is set
→ Verify network tab for gtag.js script
→ Check Google Analytics dashboard for data
```

### How to Verify Setup
```typescript
// In browser console:
console.log(import.meta.env.VITE_SUPABASE_URL);
console.log(import.meta.env.VITE_GOOGLE_ANALYTICS_ID);
console.log(window.gtag);  // Should be a function
```

## Best Practices

1. **Always use centralized configuration** - Don't scatter `import.meta.env` calls
2. **Validate configuration on startup** - Catch missing variables early
3. **Log masked information** - Never log full API keys
4. **Use feature flags** - Check `isDBFeatureAvailable()` before using features
5. **Track important events** - Monitor user journey with analytics
6. **Set user ID after login** - Better attribution and user tracking

## References

- [Supabase Environment Variables](https://supabase.com/docs/guides/environment-variables)
- [Vite Environment Variables](https://vitejs.dev/guide/env-and-mode.html)
- [Google Analytics Setup](https://developers.google.com/analytics/devguides/collection/gtagjs)
