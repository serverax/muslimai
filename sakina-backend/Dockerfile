FROM rust:1.88-slim AS builder

WORKDIR /app
COPY sakina-backend/Cargo.toml sakina-backend/Cargo.lock ./
COPY sakina-backend/src ./src
COPY sakina-backend/db ./db

RUN apt-get update && apt-get install -y --no-install-recommends libpq-dev pkg-config && rm -rf /var/lib/apt/lists/*
RUN cargo build --release --bin sakina-api

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends libpq5 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/sakina-api /usr/local/bin/sakina-api

EXPOSE 8080
CMD ["sakina-api"]
