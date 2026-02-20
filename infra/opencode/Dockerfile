FROM oven/bun:latest
RUN bun install -g opencode-ai@latest
RUN adduser --disabled-password --gecos "" appuser
WORKDIR /workspace
COPY opencode.json /workspace/opencode.json
RUN chown -R appuser:appuser /workspace
USER appuser
EXPOSE 4096
ENTRYPOINT ["opencode", "serve", "--hostname", "0.0.0.0", "--port", "4096"]
