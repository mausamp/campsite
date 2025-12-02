# syntax = docker/dockerfile:1

FROM node:20-slim as base

# configure pnpm
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

ARG TIPTAP_PRIVATE_REGISTRY_KEY

LABEL fly_launch_runtime="Node.js"

# Throw-away build stage to reduce size of final image
FROM base as builder
# Install packages needed to build node modules
RUN apt-get update -qq && \
  apt-get install -y build-essential pkg-config python-is-python3 ca-certificates
WORKDIR /app
RUN pnpm install turbo@2.0.9 --global
COPY . .
RUN turbo prune @campsite/styled-text-server --docker
WORKDIR /app


FROM base AS installer
WORKDIR /app
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/pnpm-lock.yaml ./pnpm-lock.yaml

RUN pnpm config set "@tiptap-pro:registry" https://registry.tiptap.dev/
RUN pnpm config set "//registry.tiptap.dev/:_authToken" ${TIPTAP_PRIVATE_REGISTRY_KEY}
RUN pnpm install

COPY --from=builder /app/out/full/ .

RUN npx turbo run build --filter=@campsite/styled-text-server

RUN apt-get update -y && apt-get install -y ca-certificates

RUN --mount=type=secret,id=SENTRY_AUTH_TOKEN \
--mount=type=secret,id=SENTRY_ORG \
--mount=type=secret,id=SENTRY_PROJECT \
SENTRY_ORG=$(cat /run/secrets/SENTRY_ORG) \
SENTRY_AUTH_TOKEN=$(cat /run/secrets/SENTRY_AUTH_TOKEN) \
SENTRY_PROJECT=$(cat /run/secrets/SENTRY_PROJECT) \
npx turbo run sentry:sourcemaps --filter=@campsite/styled-text-server


FROM base AS runner

# Set production environment
ENV NODE_ENV="production"

WORKDIR /app/apps/styled-text-server

# Copy built application
COPY --from=installer /app /app

# Start the server by default, this can be overwritten at runtime
EXPOSE 9000
ENV PORT 9000

ENTRYPOINT [ "node", "dist/index.mjs" ]
