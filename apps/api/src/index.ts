import Fastify from 'fastify';
import cors from '@fastify/cors';
import { config } from './config.js';
import { healthRoutes } from './routes/health.js';
import { authRoutes } from './routes/auth.js';
import { conversationRoutes } from './routes/conversations.js';
import { chatRoutes } from './routes/chat.js';
import { usageRoutes } from './routes/usage.js';
import { billingRoutes } from './routes/billing.js';

async function main() {
  const app = Fastify({
    logger: true,
  });

  await app.register(cors, {
    origin: config.corsOrigin === true ? true : config.corsOrigin,
  });

  await app.register(healthRoutes);
  await app.register(authRoutes);
  await app.register(conversationRoutes);
  await app.register(chatRoutes);
  await app.register(usageRoutes);
  await app.register(billingRoutes);

  await app.listen({ port: config.port, host: '0.0.0.0' });
  app.log.info(`ChatAI API listening on :${config.port}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
