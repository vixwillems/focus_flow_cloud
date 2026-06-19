FROM lukemathwalker/cargo-chef:latest-rust-bookworm AS chef
WORKDIR /app

FROM chef AS planner
COPY Cargo.toml Cargo.lock ./
COPY backend/Cargo.toml backend/
COPY backend/crates/adapters/Cargo.toml backend/crates/adapters/
COPY backend/crates/application/Cargo.toml backend/crates/application/
COPY backend/crates/domain/Cargo.toml backend/crates/domain/
COPY backend/crates/infrastructure/Cargo.toml backend/crates/infrastructure/
# dummy source so planner can resolve the dependency tree
RUN mkdir -p backend/src backend/crates/adapters/src backend/crates/application/src backend/crates/domain/src backend/crates/infrastructure/src && \
    echo "fn main() {}" > backend/src/main.rs && \
    for d in adapters application domain infrastructure; do touch "backend/crates/$d/src/lib.rs"; done
RUN cargo chef prepare --recipe-path recipe.json --bin focus_flow_cloud

FROM chef AS builder
RUN apt-get update && apt-get install -y --no-install-recommends pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

COPY Cargo.toml Cargo.lock ./
COPY backend/ ./backend/
RUN cargo build --release -p focus_flow_cloud

FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/focus_flow_cloud /usr/local/bin/focus_flow_cloud
EXPOSE 8080
CMD ["focus_flow_cloud"]
