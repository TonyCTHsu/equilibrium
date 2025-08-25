# Multi-stage build for minimal production image
FROM ruby:3.2-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git

WORKDIR /app

# Copy gemspec and version file first for dependency caching
COPY equilibrium.gemspec ./
COPY lib/equilibrium/version.rb ./lib/equilibrium/

# Install dependencies
RUN bundle config set --local deployment true && \
    bundle config set --local without development test && \
    bundle install

# Copy source code
COPY . .

# Build the gem
RUN gem build equilibrium.gemspec && \
    gem install equilibrium-*.gem --no-document

# Production stage
FROM ruby:3.2-alpine AS production

# Install runtime dependencies only
RUN apk add --no-cache \
    ca-certificates \
    curl

# Copy the installed gem and its dependencies from builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Create non-root user for security
RUN addgroup -g 1001 equilibrium && \
    adduser -D -u 1001 -G equilibrium equilibrium

USER equilibrium

# Set the entry point
ENTRYPOINT ["equilibrium"]

# Default command shows help
CMD ["--help"]

# Add labels for container metadata
LABEL org.opencontainers.image.title="Equilibrium"
LABEL org.opencontainers.image.description="Container image tag validation tool"
LABEL org.opencontainers.image.vendor="Tony Hsu"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/TonyCTHsu/equilibrium"