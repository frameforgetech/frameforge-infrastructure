# Base Node.js image for all FrameForge services
FROM node:20-alpine AS base

# Install common dependencies
RUN apk add --no-cache \
    tini \
    dumb-init

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Use tini as entrypoint for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]
