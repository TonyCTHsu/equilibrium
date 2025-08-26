# Dockerfile for Equilibrium container image
FROM ruby:3.4.5

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -g 1001 equilibrium && \
    useradd -d /home/equilibrium -m -u 1001 -g equilibrium equilibrium

# Copy gem artifact from CI build
COPY pkg/*.gem /tmp/

# Install the gem
RUN gem install --no-document /tmp/*.gem && \
    rm /tmp/*.gem

USER equilibrium

# Default command shows help when run without arguments
CMD ["equilibrium", "--help"]

# Add labels for container metadata
LABEL org.opencontainers.image.title="Equilibrium"
LABEL org.opencontainers.image.description="Container image tag validation tool"
LABEL org.opencontainers.image.vendor="Tony Hsu"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/TonyCTHsu/equilibrium"