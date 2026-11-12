FROM node:22-bookworm-slim

WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

COPY server.mjs ./
COPY api ./api
COPY server ./server
COPY dist ./dist

USER node
EXPOSE 4174
CMD ["node", "server.mjs"]
