# Stage 1: minimal Elixir runtime on Alpine with Pi coding agent
FROM hexpm/elixir:1.19.4-erlang-28.3.2-alpine-3.21.6

# git: repo operations, bash+openssl+curl+python3: get-token script
# ripgrep+fd: required by Pi's grep and find tools
# postgresql16+contrib: embedded per-session database (contrib provides citext extension)
# build-base: make/gcc/musl-dev needed by bcrypt_elixir and lazy_html NIFs
# unzip: required by bun installer
# nodejs+npm: required by esbuild/tailwind asset pipeline, Pi, and npm test
RUN apk add --no-cache git bash openssl curl python3 github-cli ripgrep fd postgresql16 postgresql16-contrib build-base unzip nodejs npm

# Install Bun (JavaScript runtime/toolkit)
RUN curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -s /usr/local/bin/bun /usr/local/bin/bunx

# Install Pi coding agent globally via npm
RUN npm install -g @mariozechner/pi-coding-agent

# Non-root user
RUN adduser -D -g "" appuser

# Pre-create directories Pi expects at runtime
RUN mkdir -p /home/appuser/.pi/agent \
             /home/appuser/.config/perme8 \
             /home/appuser/.claude \
             /tmp/pgdata

WORKDIR /workspace
COPY entrypoint.sh /workspace/entrypoint.sh
COPY get-token /home/appuser/.config/perme8/get-token
COPY pi/ /workspace/pi/
RUN chown -R appuser:appuser /workspace /home/appuser/.pi /home/appuser/.config /home/appuser/.claude /tmp/pgdata

USER appuser

# Pi uses RPC mode over stdin/stdout (no HTTP port).
# The runtime adapter communicates via the process stdio.
ENTRYPOINT ["/workspace/entrypoint.sh"]
