import 'dotenv/config';

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) ? n : fallback;
}

/**
 * Server config from env. Secrets must never be logged or returned to clients.
 * Missing AI / MS Store keys are OK in stub mode — routes return stub responses.
 */
export const config = {
  port: intEnv('PORT', 3001),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  publicApiUrl: process.env.PUBLIC_API_URL ?? 'http://localhost:3001',
  corsOrigin: process.env.CORS_ORIGIN ?? true,

  supabase: {
    url: process.env.SUPABASE_URL ?? '',
    anonKey: process.env.SUPABASE_ANON_KEY ?? '',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? '',
    jwtSecret: process.env.SUPABASE_JWT_SECRET ?? '',
  },

  databaseUrl: process.env.DATABASE_URL ?? '',
  redisUrl: process.env.REDIS_URL ?? '',

  ai: {
    xaiApiKey: process.env.XAI_API_KEY ?? '',
    xaiBaseUrl: process.env.XAI_BASE_URL ?? 'https://api.x.ai/v1',
    /**
     * Web search for chat:
     * - xai (default): Responses API built-in `web_search` (XAI_API_KEY only)
     * - local: client-side tool loop via DuckDuckGo (or Brave if BRAVE_SEARCH_API_KEY)
     * - off: no live search
     */
    webSearchMode: (() => {
      const raw = (process.env.XAI_WEB_SEARCH_MODE ?? 'xai').toLowerCase();
      if (raw === 'off' || raw === 'false' || raw === '0') return 'off' as const;
      if (raw === 'local') return 'local' as const;
      return 'xai' as const;
    })(),
    /** Overall timeout for a search-enabled vendor request (ms). */
    webSearchTimeoutMs: intEnv('WEB_SEARCH_TIMEOUT_MS', 90_000),
    /** Max local tool-calling rounds per user message. */
    webSearchMaxToolRounds: intEnv('WEB_SEARCH_MAX_TOOL_ROUNDS', 3),
  },

  /**
   * Microsoft Store Collections / Purchase API credentials (Azure AD app).
   * Used to validate User Store ID keys from the Windows client.
   */
  msStore: {
    tenantId: process.env.MS_STORE_TENANT_ID ?? '',
    clientId: process.env.MS_STORE_CLIENT_ID ?? '',
    clientSecret: process.env.MS_STORE_CLIENT_SECRET ?? '',
    proProductId: process.env.MS_STORE_PRO_PRODUCT_ID ?? 'pro_monthly',
    collectionsBaseUrl:
      process.env.MS_STORE_COLLECTIONS_BASE_URL ??
      'https://collections.mp.microsoft.com/v7.0',
    /** Azure AD scope for Store Collections (override if Microsoft changes audience). */
    collectionsScope:
      process.env.MS_STORE_COLLECTIONS_SCOPE ??
      'https://onestore.microsoft.com/.default',
  },

  /**
   * @deprecated Stripe is not the end-user billing path. Kept only so old
   * env names do not crash boot; routes return 410 Gone.
   */
  stripe: {
    secretKey: process.env.STRIPE_SECRET_KEY ?? '',
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET ?? '',
    priceProMonthly: process.env.STRIPE_PRICE_PRO_MONTHLY ?? '',
  },

  quotas: {
    freeMessagesPerDay: intEnv('FREE_MESSAGES_PER_DAY', 100),
    proMessagesPerDay: intEnv('PRO_MESSAGES_PER_DAY', 400),
    freeTokenSoftCap: intEnv('FREE_TOKEN_SOFT_CAP_PER_DAY', 80_000),
    proTokenSoftCap: intEnv('PRO_TOKEN_SOFT_CAP_PER_DAY', 800_000),
    freeRateLimitPerMin: intEnv('FREE_RATE_LIMIT_PER_MIN', 5),
    proRateLimitPerMin: intEnv('PRO_RATE_LIMIT_PER_MIN', 30),
    /** Max images attached on a single user message. */
    freeImagesPerMessage: intEnv('FREE_IMAGES_PER_MESSAGE', 3),
    proImagesPerMessage: intEnv('PRO_IMAGES_PER_MESSAGE', 8),
    /** Max decoded image size (bytes) before base64 encoding. */
    maxImageBytes: intEnv('MAX_IMAGE_BYTES', 8 * 1024 * 1024),
    /** Daily image upload hard quota (successful image attachments counted). */
    freeImagesPerDay: intEnv('FREE_IMAGES_PER_DAY', 10),
    proImagesPerDay: intEnv('PRO_IMAGES_PER_DAY', 20),
    /**
     * Hidden Pro monthly soft-cap (UTC calendar month). When reached, Pro
     * image limits reduce to Free rates until next month — not marketed.
     */
    proImagesPerMonthSoftCap: intEnv('PRO_IMAGES_PER_MONTH_SOFT_CAP', 200),
  },
} as const;

export type PlanTier = 'free' | 'pro';

export function isAiConfigured(): boolean {
  return Boolean(config.ai.xaiApiKey);
}

/** True when Azure AD + Store product id are set for live Collections verify. */
export function isMsStoreConfigured(): boolean {
  return Boolean(
    config.msStore.tenantId &&
      config.msStore.clientId &&
      config.msStore.clientSecret &&
      config.msStore.proProductId,
  );
}

export function isSupabaseConfigured(): boolean {
  return Boolean(config.supabase.url && config.supabase.jwtSecret);
}

/** @deprecated Stripe is not used for end-user Pro. */
export function isStripeConfigured(): boolean {
  return Boolean(config.stripe.secretKey && config.stripe.webhookSecret);
}
