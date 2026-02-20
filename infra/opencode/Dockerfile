FROM oven/bun:latest
RUN bun install -g opencode-ai@latest
WORKDIR /workspace
COPY opencode.json /workspace/opencode.json
EXPOSE 4096
ENTRYPOINT ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
