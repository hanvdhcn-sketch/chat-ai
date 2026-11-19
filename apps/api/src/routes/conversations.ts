import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { newId } from '../lib/id.js';
import {
  appendMessage,
  getConversation,
  listConversations,
  listMessages,
  saveConversation,
} from '../services/store.js';
import type { ModelId } from '../types/index.js';

const createBody = z.object({
  title: z.string().min(1).max(200).optional(),
  modelDefault: z
    .enum(['gemini-flash', 'gemini-pro', 'grok-fast', 'grok'])
    .optional(),
});

export async function conversationRoutes(app: FastifyInstance): Promise<void> {
  app.get(
    '/v1/conversations',
    { preHandler: requireAuth },
    async (request) => {
      const user = request.user!;
      return { conversations: listConversations(user.id) };
    },
  );

  app.post(
    '/v1/conversations',
    { preHandler: requireAuth },
    async (request, reply) => {
      const user = request.user!;
      const parsed = createBody.safeParse(request.body ?? {});
      if (!parsed.success) {
        return reply.code(400).send({ error: 'invalid_body', details: parsed.error.flatten() });
      }

      const now = new Date().toISOString();
      const modelDefault: ModelId =
        user.planTier === 'free'
          ? 'gemini-flash'
          : (parsed.data.modelDefault ?? 'grok');

      const conversation = {
        id: newId('conv'),
        userId: user.id,
        title: parsed.data.title ?? 'New chat',
        modelDefault,
        createdAt: now,
        updatedAt: now,
      };
      saveConversation(conversation);
      return reply.code(201).send({ conversation });
    },
  );

  app.get(
    '/v1/conversations/:id',
    { preHandler: requireAuth },
    async (request, reply) => {
      const user = request.user!;
      const { id } = request.params as { id: string };
      const conversation = getConversation(user.id, id);
      if (!conversation) {
        return reply.code(404).send({ error: 'not_found' });
      }
      return {
        conversation,
        messages: listMessages(conversation.id),
      };
    },
  );

  app.get(
    '/v1/conversations/:id/messages',
    { preHandler: requireAuth },
    async (request, reply) => {
      const user = request.user!;
      const { id } = request.params as { id: string };
      const conversation = getConversation(user.id, id);
      if (!conversation) {
        return reply.code(404).send({ error: 'not_found' });
      }
      return { messages: listMessages(conversation.id) };
    },
  );

  /** Non-streaming message create (persist user turn only). Prefer /stream for AI. */
  app.post(
    '/v1/conversations/:id/messages',
    { preHandler: requireAuth },
    async (request, reply) => {
      const user = request.user!;
      const { id } = request.params as { id: string };
      const conversation = getConversation(user.id, id);
      if (!conversation) {
        return reply.code(404).send({ error: 'not_found' });
      }

      const body = z
        .object({
          content: z.string().min(1).max(16_000),
          role: z.enum(['user', 'system']).default('user'),
        })
        .safeParse(request.body);
      if (!body.success) {
        return reply.code(400).send({ error: 'invalid_body' });
      }

      const message = {
        id: newId('msg'),
        conversationId: conversation.id,
        role: body.data.role,
        content: body.data.content,
        status: 'complete' as const,
        createdAt: new Date().toISOString(),
      };
      appendMessage(message);
      conversation.updatedAt = message.createdAt;
      saveConversation(conversation);
      return reply.code(201).send({ message });
    },
  );
}
