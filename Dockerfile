FROM ubuntu:22.04

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Install fardrun
COPY fardrun /usr/local/bin/fardrun
RUN chmod +x /usr/local/bin/fardrun

WORKDIR /app
COPY bay2/ bay2/

RUN mkdir -p out/bay2

EXPOSE 19000

HEALTHCHECK --interval=5s --timeout=3s --retries=5 --start-period=10s \
  CMD curl -f http://localhost:19000/health || exit 1

CMD ["fardrun", "run", "--program", "bay2/src/server.fard", "--out", "out/bay2"]
