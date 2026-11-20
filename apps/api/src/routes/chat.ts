import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { newId } from '../lib/id.js';
import { checkQuota } from '../services/quota.js';
import { checkRateLimit } from '../services/rate-limit.js';
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
  model: z.enum(['grok-fast', 'grok']).optional(),
});

/**
 * Streaming chat: SSE text/event-stream.
 * Persists user + assistant messages; respects message hard quota + token soft-cap.
 * Client abort closes the upstream vendor stream.
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

      const rl = checkRateLimit(user.id, quota.rateLimitPerMin);
      if (!rl.ok) {
        return reply.code(429).send({
          error: 'rate_limit_exceeded',
          retryAfterSec: rl.retryAfterSec,
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

      const abort = new AbortController();
      const onClose = () => abort.abort();
      request.raw.on('close', onClose);

      reply.hijack();
      reply.raw.writeHead(200, {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache, no-transform',
        Connection: 'keep-alive',
        'X-Accel-Buffering': 'no',
      });

      const writeEvent = (payload: unknown) => {
        if (reply.raw.writableEnded) return;
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
      let finished = false;

      const finalizeAssistant = (patch: {
        status: 'complete' | 'error';
        model?: typeof conversation.modelDefault;
        inputTokens?: number;
        outputTokens?: number;
        errorText?: string;
      }) => {
        if (finished) return;
        finished = true;
        updateMessage(conversation.id, assistantId, {
          content: assembled || patch.errorText || '',
          status: patch.status,
          model: patch.model,
          inputTokens: patch.inputTokens,
          outputTokens: patch.outputTokens,
          latencyMs: Date.now() - started,
        });
        conversation.updatedAt = new Date().toISOString();
        if (conversation.title === 'New chat' && parsed.data.content) {
          conversation.title = parsed.data.content.slice(0, 60);
        }
        saveConversation(conversation);
      };

      try {
        for await (const chunk of streamCompletion({
          planTier: user.planTier,
          model: parsed.data.model,
          messages: history,
          abortSignal: abort.signal,
        })) {
          if (abort.signal.aborted) break;

          if (chunk.type === 'meta') {
            writeEvent({
              type: 'meta',
              userMessageId: userMsg.id,
              assistantMessageId: assistantId,
              model: chunk.model,
              vendor: chunk.vendor,
              stub: chunk.stub ?? false,
            });
          } else if (chunk.type === 'delta' && chunk.text) {
            assembled += chunk.text;
            // Persist partials periodically so disconnect doesn't lose draft.
            if (assembled.length % 200 < (chunk.text.length || 1)) {
              updateMessage(conversation.id, assistantId, {
                content: assembled,
                status: 'streaming',
                model: chunk.model,
              });
            }
            writeEvent({
              type: 'delta',
              text: chunk.text,
              model: chunk.model,
            });
          } else if (chunk.type === 'done') {
            finalizeAssistant({
              status: 'complete',
              model: chunk.model,
              inputTokens: chunk.inputTokens,
              outputTokens: chunk.outputTokens,
            });
            incrementUsage(user.id, user.planTier, {
              messages: 1,
              inputTokens: chunk.inputTokens ?? 0,
              outputTokens: chunk.outputTokens ?? 0,
            });
            writeEvent({
              type: 'done',
              model: chunk.model,
              inputTokens: chunk.inputTokens,
              outputTokens: chunk.outputTokens,
              stub: chunk.stub ?? false,
            });
          } else if (chunk.type === 'error') {
            finalizeAssistant({
              status: 'error',
              model: chunk.model,
              errorText: chunk.error,
            });
            writeEvent({ type: 'error', error: chunk.error, model: chunk.model });
          }
        }

        if (abort.signal.aborted && !finished) {
          finalizeAssistant({
            status: assembled ? 'complete' : 'error',
            errorText: assembled ? undefined : 'aborted',
          });
          if (assembled) {
            incrementUsage(user.id, user.planTier, {
              messages: 1,
              inputTokens: 0,
              outputTokens: Math.ceil(assembled.length / 4),
            });
          }
          writeEvent({ type: 'error', error: 'aborted' });
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'stream_failed';
        finalizeAssistant({ status: 'error', errorText: message });
        writeEvent({ type: 'error', error: message });
      } finally {
        request.raw.off('close', onClose);
        if (!reply.raw.writableEnded) {
          reply.raw.end();
        }
      }
    },
  );
}
