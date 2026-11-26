# Orbita API (Fastify). Build context = repository root.
#   docker build -t orbita-api .
#   docker run --rm -p 3001:3001 --env-file apps/api/.env orbita-api

FROM node:22-alpine AS build
WORKDIR /repo
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/
RUN npm ci -w @chatai/api
COPY apps/api apps/api
RUN npm run build -w @chatai/api

FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /repo
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/
RUN npm ci -w @chatai/api --omit=dev && npm cache clean --force
COPY --from=build /repo/apps/api/dist apps/api/dist
COPY apps/api/migrations apps/api/migrations
USER node
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT:-3001}/health" >/dev/null || exit 1
CMD ["node", "apps/api/dist/index.js"]
