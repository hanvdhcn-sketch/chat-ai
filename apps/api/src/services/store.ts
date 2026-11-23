import type {
  Conversation,
  Message,
  StoreSubscription,
  UsageSnapshot,
} from '../types/index.js';
import type { PlanTier } from '../config.js';
import { config } from '../config.js';

/**
 * In-memory store for M0/M1. Replace with Postgres (Supabase/Neon) + Redis.
 */
const conversations = new Map<string, Conversation>();
const messages = new Map<string, Message[]>();
const usageByUser = new Map<string, UsageSnapshot>();
const subscriptionsByUser = new Map<string, StoreSubscription>();
/** Plan tier overrides from Store entitlement verify (in-memory until Postgres). */
const planTierByUser = new Map<string, PlanTier>();

function dayStartIso(): string {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d.toISOString();
}

export function listConversations(userId: string): Conversation[] {
  return [...conversations.values()]
    .filter((c) => c.userId === userId && !c.archivedAt)
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
}

export function getConversation(
  userId: string,
  id: string,
): Conversation | undefined {
  const c = conversations.get(id);
  if (!c || c.userId !== userId) return undefined;
  return c;
}

export function saveConversation(c: Conversation): void {
  conversations.set(c.id, c);
}

export function listMessages(conversationId: string): Message[] {
  return messages.get(conversationId) ?? [];
}

export function appendMessage(msg: Message): void {
  const list = messages.get(msg.conversationId) ?? [];
  list.push(msg);
  messages.set(msg.conversationId, list);
}

export function updateMessage(
  conversationId: string,
  messageId: string,
  patch: Partial<Message>,
): Message | undefined {
  const list = messages.get(conversationId);
  if (!list) return undefined;
  const idx = list.findIndex((m) => m.id === messageId);
  if (idx < 0) return undefined;
  list[idx] = { ...list[idx], ...patch };
  return list[idx];
}

export function getOrCreateUsage(
  userId: string,
  planTier: PlanTier,
): UsageSnapshot {
  const windowStart = dayStartIso();
  let snap = usageByUser.get(userId);
  if (!snap || snap.windowStart !== windowStart) {
    snap = {
      userId,
      window: 'day',
      windowStart,
      messagesCount: 0,
      messagesLimit:
        planTier === 'pro'
          ? config.quotas.proMessagesPerDay
          : config.quotas.freeMessagesPerDay,
      imagesCount: 0,
      imagesLimit:
        planTier === 'pro'
          ? config.quotas.proImagesPerDay
          : config.quotas.freeImagesPerDay,
      inputTokens: 0,
      outputTokens: 0,
      tokenSoftCap:
        planTier === 'pro'
          ? config.quotas.proTokenSoftCap
          : config.quotas.freeTokenSoftCap,
      planTier,
    };
    usageByUser.set(userId, snap);
  } else {
    snap.planTier = planTier;
    snap.messagesLimit =
      planTier === 'pro'
        ? config.quotas.proMessagesPerDay
        : config.quotas.freeMessagesPerDay;
    snap.imagesLimit =
      planTier === 'pro'
        ? config.quotas.proImagesPerDay
        : config.quotas.freeImagesPerDay;
    if (snap.imagesCount === undefined) snap.imagesCount = 0;
    snap.tokenSoftCap =
      planTier === 'pro'
        ? config.quotas.proTokenSoftCap
        : config.quotas.freeTokenSoftCap;
  }
  return snap;
}

export function incrementUsage(
  userId: string,
  planTier: PlanTier,
  opts: {
    messages?: number;
    images?: number;
    inputTokens?: number;
    outputTokens?: number;
  },
): UsageSnapshot {
  const snap = getOrCreateUsage(userId, planTier);
  snap.messagesCount += opts.messages ?? 0;
  snap.imagesCount = (snap.imagesCount ?? 0) + (opts.images ?? 0);
  snap.inputTokens += opts.inputTokens ?? 0;
  snap.outputTokens += opts.outputTokens ?? 0;
  usageByUser.set(userId, snap);
  return snap;
}

export function getSubscription(userId: string): StoreSubscription | undefined {
  return subscriptionsByUser.get(userId);
}

export function setSubscription(sub: StoreSubscription): void {
  subscriptionsByUser.set(sub.userId, sub);
}

export function setUserPlanTierOverride(userId: string, tier: PlanTier): void {
  planTierByUser.set(userId, tier);
}

export function getUserPlanTierOverride(userId: string): PlanTier | undefined {
  return planTierByUser.get(userId);
}

/** Test helper */
export function resetStore(): void {
  conversations.clear();
  messages.clear();
  usageByUser.clear();
  subscriptionsByUser.clear();
  planTierByUser.clear();
}

/** Test helper — force usage counters */
export function setUsageForTests(snap: UsageSnapshot): void {
  usageByUser.set(snap.userId, snap);
}
