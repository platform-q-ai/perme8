# Stage 1: fetch the opencode binary
FROM alpine:3.21 AS fetcher
RUN apk add --no-cache curl bash
RUN curl -fsSL https://opencode.ai/install | bash
RUN cp /root/.opencode/bin/opencode /usr/local/bin/opencode

# Stage 2: minimal Elixir runtime on Alpine
FROM hexpm/elixir:1.19.4-erlang-28.3.2-alpine-3.21.6

# git: repo operations, bash+openssl+curl+python3: get-token script
# ripgrep+fd: required by opencode's Grep and Glob tools
# postgresql16+contrib: embedded per-session database (contrib provides citext extension)
# build-base: make/gcc/musl-dev needed by bcrypt_elixir and lazy_html NIFs
# unzip: required by bun installer
RUN apk add --no-cache git bash openssl curl python3 github-cli ripgrep fd postgresql16 postgresql16-contrib build-base unzip

# Install Bun (JavaScript runtime/toolkit)
RUN curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -s /usr/local/bin/bun /usr/local/bin/bunx

# Copy opencode binary from fetcher stage
COPY --from=fetcher /usr/local/bin/opencode /usr/local/bin/opencode

# Non-root user
RUN adduser -D -g "" appuser

# Pre-create directories opencode expects at runtime
RUN mkdir -p /home/appuser/.local/share/opencode \
             /home/appuser/.local/state \
             /home/appuser/.config/perme8 \
             /home/appuser/.claude \
             /tmp/pgdata

WORKDIR /workspace
COPY opencode.json /workspace/opencode.json
COPY entrypoint.sh /workspace/entrypoint.sh
COPY get-token /home/appuser/.config/perme8/get-token
RUN chown -R appuser:appuser /workspace /home/appuser/.local /home/appuser/.config /home/appuser/.claude /tmp/pgdata

USER appuser
EXPOSE 4096
ENTRYPOINT ["/workspace/entrypoint.sh"]
