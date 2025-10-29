# Build stage
FROM docker.io/library/node:20-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN if [ -f package-lock.json ]; then \
        npm ci --ignore-scripts; \
    else \
        npm install --ignore-scripts; \
    fi

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM docker.io/library/nginx:alpine

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Nginx alpine already runs as non-root user 'nginx' (UID 101, GID 101)
# Ensure proper permissions
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# Switch to non-root user
USER nginx

# Expose port (rootless friendly)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Security: Run as non-root, read-only root filesystem
# Start nginx
CMD ["nginx", "-g", "daemon off;"]
