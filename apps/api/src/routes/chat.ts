import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { newId } from '../lib/id.js';
import { checkImageQuota, checkQuota } from '../services/quota.js';
import { buildOrbitaQuotaSystemPrompt } from '../services/quota-context.js';
import { checkRateLimit } from '../services/rate-limit.js';
import { streamCompletion } from '../services/ai-gateway.js';
import {
  buildPersistedUserContent,
  buildUserTurnContent,
  countImageAttachments,
  maxAttachmentsInBody,
  sanitizeAttachments,
  toGatewayMessages,
} from '../services/attachments.js';
import {
  appendMessage,
  getConversation,
  listMessages,
  saveConversation,
  updateMessage,
  incrementUsage,
} from '../services/store.js';
import { config } from '../config.js';
import { conversationNotFound } from '../lib/errors.js';

/** Request-body ceiling: allow the larger of Free/Pro per-image caps. */
const maxImageB64 =
  Math.ceil(
    (Math.max(config.quotas.freeMaxImageBytes, config.quotas.maxImageBytes) *
      4) /
      3,
  ) + 8;

const attachmentSchema = z.object({
  name: z.string().min(1).max(256),
  mimeType: z.string().min(1).max(128),
  kind: z.enum(['image', 'text', 'unsupported']),
  text: z.string().max(100_000).optional(),
  dataBase64: z.string().max(maxImageB64).optional(),
  notice: z.string().max(500).optional(),
});

const streamBody = z
  .object({
    content: z.string().max(16_000).default(''),
    model: z.enum(['grok-fast', 'grok']).optional(),
    /** Optional UI locale hint (e.g. vi / en) for quota system prompt. */
    locale: z.string().min(2).max(16).optional(),
    attachments: z.array(attachmentSchema).max(maxAttachmentsInBody).optional(),
  })
  .superRefine((val, ctx) => {
    const hasText = val.content.trim().length > 0;
    const atts = sanitizeAttachments(val.attachments, 'pro');
    const hasUseful = atts.some((a) => a.kind === 'image' || a.kind === 'text');
    if (!hasText && !hasUseful) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'empty_message',
        path: ['content'],
      });
    }
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
        return reply.code(404).send(conversationNotFound);
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

      const attachments = sanitizeAttachments(
        parsed.data.attachments,
        user.planTier,
        quota.usage,
      );
      const imageCount = countImageAttachments(attachments);
      const imageQuota = checkImageQuota(user, imageCount);
      if (!imageQuota.ok) {
        return reply.code(402).send({
          error: imageQuota.reason,
          usage: imageQuota.usage,
          upgradeRequired: user.planTier === 'free',
        });
      }

      const persistedContent = buildPersistedUserContent(
        parsed.data.content,
        attachments,
      );
      const userTurnContent = buildUserTurnContent(
        parsed.data.content,
        attachments,
      );

      const now = new Date().toISOString();
      const userMsg = {
        id: newId('msg'),
        conversationId: conversation.id,
        role: 'user' as const,
        content: persistedContent,
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
      const quotaSystemPrompt = buildOrbitaQuotaSystemPrompt(
        quota.usage,
        user.planTier,
        {
          locale: parsed.data.locale ?? user.locale,
          latestUserMessage: parsed.data.content,
        },
      );
      const gatewayMessages = toGatewayMessages(
        history,
        userTurnContent,
        quotaSystemPrompt,
      );

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
        if (conversation.title === 'New chat' && persistedContent) {
          conversation.title = persistedContent.slice(0, 60);
        }
        saveConversation(conversation);
      };

      try {
        for await (const chunk of streamCompletion({
          planTier: user.planTier,
          model: parsed.data.model,
          messages: gatewayMessages,
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
              webSearch: chunk.webSearch ?? false,
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
              images: imageCount,
              inputTokens: chunk.inputTokens ?? 0,
              outputTokens: chunk.outputTokens ?? 0,
            });
            writeEvent({
              type: 'done',
              model: chunk.model,
              inputTokens: chunk.inputTokens,
              outputTokens: chunk.outputTokens,
              stub: chunk.stub ?? false,
              webSearch: chunk.webSearch ?? false,
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
              images: imageCount,
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
