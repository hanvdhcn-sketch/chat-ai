import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { newId } from '../lib/id.js';
import { checkQuota } from '../services/quota.js';
import { streamCompletion } from '../services/ai-gateway.js';
import {
  appendMessage,
  getConversation,
  listMessages,
  saveConversation,
  updateMessage,
  incrementUsage,
} from '../services/store.js';

const streamBody = z.object({
  content: z.string().min(1).max(16_000),
  model: z
    .enum(['gemini-flash', 'gemini-pro', 'grok-fast', 'grok'])
    .optional(),
});

/**
 * Streaming chat: SSE-style text/event-stream.
 * Client should consume with an HTTP stream parser (Flutter http/dio).
 */
export async function chatRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    '/v1/conversations/:id/messages/stream',
    { preHandler: requireAuth },
    async (request, reply) => {
      const user = request.user!;
      const { id } = request.params as { id: string };
      const conversation = getConversation(user.id, id);
      if (!conversation) {
        return reply.code(404).send({ error: 'not_found' });
      }

      const parsed = streamBody.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'invalid_body' });
      }

      const quota = checkQuota(user);
      if (!quota.ok) {
        return reply.code(402).send({
          error: quota.reason,
          usage: quota.usage,
          upgradeRequired: user.planTier === 'free',
        });
      }

      const now = new Date().toISOString();
      const userMsg = {
        id: newId('msg'),
        conversationId: conversation.id,
        role: 'user' as const,
        content: parsed.data.content,
        status: 'complete' as const,
        createdAt: now,
      };
      appendMessage(userMsg);

      const assistantId = newId('msg');
      appendMessage({
        id: assistantId,
        conversationId: conversation.id,
        role: 'assistant',
        content: '',
        status: 'streaming',
        createdAt: now,
      });

      reply.hijack();
      reply.raw.writeHead(200, {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache, no-transform',
        Connection: 'keep-alive',
        'X-Accel-Buffering': 'no',
      });

      const writeEvent = (payload: unknown) => {
        reply.raw.write(`data: ${JSON.stringify(payload)}\n\n`);
      };

      writeEvent({
        type: 'meta',
        userMessageId: userMsg.id,
        assistantMessageId: assistantId,
      });

      const history = listMessages(conversation.id)
        .filter((m) => m.id !== assistantId)
        .map((m) => ({
          role: m.role as 'user' | 'assistant' | 'system',
          content: m.content,
        }));

      let assembled = '';
      const started = Date.now();

      try {
        for await (const chunk of streamCompletion({
          planTier: user.planTier,
          model: parsed.data.model,
          messages: history,
        })) {
          if (chunk.type === 'delta' && chunk.text) {
            assembled += chunk.text;
            writeEvent({
              type: 'delta',
              text: chunk.text,
              model: chunk.model,
            });
          } else if (chunk.type === 'done') {
            updateMessage(conversation.id, assistantId, {
              content: assembled,
              status: 'complete',
              model: chunk.model,
              inputTokens: chunk.inputTokens,
              outputTokens: chunk.outputTokens,
              latencyMs: Date.now() - started,
            });
            incrementUsage(user.id, user.planTier, {
              messages: 1,
              inputTokens: chunk.inputTokens ?? 0,
              outputTokens: chunk.outputTokens ?? 0,
            });
            conversation.updatedAt = new Date().toISOString();
            if (conversation.title === 'New chat' && parsed.data.content) {
              conversation.title = parsed.data.content.slice(0, 60);
            }
            saveConversation(conversation);
            writeEvent({
              type: 'done',
              model: chunk.model,
              inputTokens: chunk.inputTokens,
              outputTokens: chunk.outputTokens,
            });
          } else if (chunk.type === 'error') {
            updateMessage(conversation.id, assistantId, {
              content: assembled || chunk.error || 'error',
              status: 'error',
              model: chunk.model,
              latencyMs: Date.now() - started,
            });
            writeEvent({ type: 'error', error: chunk.error });
          }
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'stream_failed';
        updateMessage(conversation.id, assistantId, {
          content: assembled || message,
          status: 'error',
          latencyMs: Date.now() - started,
        });
        writeEvent({ type: 'error', error: message });
      }

      reply.raw.end();
    },
  );
}
