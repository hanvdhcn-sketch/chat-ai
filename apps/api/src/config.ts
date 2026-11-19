import 'dotenv/config';

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) ? n : fallback;
}

/**
 * Server config from env. Secrets must never be logged or returned to clients.
 * Missing AI/Stripe keys are OK in stub mode — routes return stub responses.
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
    geminiApiKey: process.env.GOOGLE_GEMINI_API_KEY ?? '',
  },

  stripe: {
    secretKey: process.env.STRIPE_SECRET_KEY ?? '',
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET ?? '',
    priceProMonthly: process.env.STRIPE_PRICE_PRO_MONTHLY ?? '',
    successUrl: process.env.STRIPE_SUCCESS_URL ?? 'chatai://billing/success',
    cancelUrl: process.env.STRIPE_CANCEL_URL ?? 'chatai://billing/cancel',
    portalReturnUrl:
      process.env.STRIPE_PORTAL_RETURN_URL ?? 'chatai://billing/portal-return',
  },

  quotas: {
    freeMessagesPerDay: intEnv('FREE_MESSAGES_PER_DAY', 40),
    proMessagesPerDay: intEnv('PRO_MESSAGES_PER_DAY', 400),
    freeTokenSoftCap: intEnv('FREE_TOKEN_SOFT_CAP_PER_DAY', 80_000),
    proTokenSoftCap: intEnv('PRO_TOKEN_SOFT_CAP_PER_DAY', 800_000),
    freeRateLimitPerMin: intEnv('FREE_RATE_LIMIT_PER_MIN', 5),
    proRateLimitPerMin: intEnv('PRO_RATE_LIMIT_PER_MIN', 30),
  },
} as const;

export type PlanTier = 'free' | 'pro';

export function isAiConfigured(): boolean {
  return Boolean(config.ai.xaiApiKey || config.ai.geminiApiKey);
}

export function isStripeConfigured(): boolean {
  return Boolean(config.stripe.secretKey && config.stripe.webhookSecret);
}

export function isSupabaseConfigured(): boolean {
  return Boolean(config.supabase.url && config.supabase.jwtSecret);
}
