# Stage 1: fetch the opencode binary
FROM alpine:3.21 AS fetcher
RUN apk add --no-cache curl bash
RUN curl -fsSL https://opencode.ai/install | bash
RUN cp /root/.opencode/bin/opencode /usr/local/bin/opencode

# Stage 2: minimal Elixir runtime on Alpine
FROM hexpm/elixir:1.19.4-erlang-28.3.2-alpine-3.21.6

# git: repo operations, bash+openssl+curl+python3: get-token script
RUN apk add --no-cache git bash openssl curl python3

# Copy opencode binary from fetcher stage
COPY --from=fetcher /usr/local/bin/opencode /usr/local/bin/opencode

# Non-root user
RUN adduser -D -g "" appuser

# Pre-create directories opencode expects at runtime
RUN mkdir -p /home/appuser/.local/share/opencode \
             /home/appuser/.local/state \
             /home/appuser/.config/perme8

WORKDIR /workspace
COPY opencode.json /workspace/opencode.json
COPY entrypoint.sh /workspace/entrypoint.sh
COPY get-token /home/appuser/.config/perme8/get-token
RUN chown -R appuser:appuser /workspace /home/appuser/.local /home/appuser/.config

USER appuser
EXPOSE 4096
ENTRYPOINT ["/workspace/entrypoint.sh"]
