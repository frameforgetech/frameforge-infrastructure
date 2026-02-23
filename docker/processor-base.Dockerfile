# Base image for Video Processor with FFmpeg
FROM node:20-alpine AS base

# Install FFmpeg and common dependencies
RUN apk add --no-cache \
    ffmpeg \
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
