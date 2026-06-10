FROM rust:1.88-slim AS builder

WORKDIR /app
COPY sakina-backend/Cargo.toml sakina-backend/Cargo.lock ./
COPY sakina-backend/src ./src
COPY sakina-backend/db ./db
COPY sakina-backend/data ./data
COPY sakina-wasm /sakina-wasm
COPY wasm /wasm

RUN apt-get update && apt-get install -y --no-install-recommends libpq-dev pkg-config && rm -rf /var/lib/apt/lists/*
RUN cargo build --release --bin sakina-api --bin sakina-llm-gateway --bin sakina-migrate --bin sakina-ingest

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends libpq5 ca-certificates && rm -rf /var/lib/apt/lists/*
RUN groupadd --system sakina && useradd --system --gid sakina --home-dir /nonexistent --shell /usr/sbin/nologin sakina
COPY --from=builder /app/target/release/sakina-api /usr/local/bin/sakina-api
COPY --from=builder /app/target/release/sakina-llm-gateway /usr/local/bin/sakina-llm-gateway
COPY --from=builder /app/target/release/sakina-migrate /usr/local/bin/sakina-migrate
COPY --from=builder /app/target/release/sakina-ingest /usr/local/bin/sakina-ingest

EXPOSE 8080
USER sakina
CMD ["sakina-api"]
