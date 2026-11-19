import type { PlanTier } from '../config.js';

export type MessageRole = 'user' | 'assistant' | 'system';

export type ModelId =
  | 'gemini-flash'
  | 'gemini-pro'
  | 'grok-fast'
  | 'grok';

export interface AuthUser {
  id: string;
  email: string;
  name?: string;
  locale: 'vi' | 'en';
  planTier: PlanTier;
  stripeCustomerId?: string;
}

export interface Conversation {
  id: string;
  userId: string;
  title: string;
  modelDefault: ModelId;
  createdAt: string;
  updatedAt: string;
  archivedAt?: string;
}

export interface Message {
  id: string;
  conversationId: string;
  role: MessageRole;
  content: string;
  status: 'pending' | 'streaming' | 'complete' | 'error';
  model?: ModelId;
  inputTokens?: number;
  outputTokens?: number;
  latencyMs?: number;
  createdAt: string;
}

export interface UsageSnapshot {
  userId: string;
  window: 'day';
  windowStart: string;
  messagesCount: number;
  messagesLimit: number;
  inputTokens: number;
  outputTokens: number;
  tokenSoftCap: number;
  planTier: PlanTier;
}

declare module 'fastify' {
  interface FastifyRequest {
    user?: AuthUser;
  }
}
