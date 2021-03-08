ARG RELEASE_FLAG=--release
FROM ballistacompute/rust-base:0.4.0-20210213 AS base
WORKDIR /tmp/ballista
RUN apt-get -y install cmake
RUN cargo install cargo-chef 

FROM base as planner
COPY rust .
RUN cargo chef prepare --recipe-path recipe.json

FROM base as cacher
COPY --from=planner /tmp/ballista/recipe.json recipe.json
RUN cargo chef cook $RELEASE_FLAG --recipe-path recipe.json

FROM base as builder
COPY rust .
COPY --from=cacher /tmp/ballista/target target
ARG RELEASE_FLAG=--release

# force build.rs to run to generate configure_me code.
ENV FORCE_REBUILD='true'
RUN cargo build $RELEASE_FLAG

# put the executor on /executor (need to be copied from different places depending on FLAG)
ENV RELEASE_FLAG=${RELEASE_FLAG}
RUN if [ -z "$RELEASE_FLAG" ]; then mv /tmp/ballista/target/debug/ballista-executor /executor; else mv /tmp/ballista/target/release/ballista-executor /executor; fi

# put the executor on /executor (need to be copied from different places depending on FLAG)
ENV RELEASE_FLAG=${RELEASE_FLAG}
RUN if [ -z "$RELEASE_FLAG" ]; then mv /tmp/ballista/target/debug/ballista-scheduler /scheduler; else mv /tmp/ballista/target/release/ballista-scheduler /scheduler; fi

# Copy the binary into a new container for a smaller docker image
FROM ballistacompute/rust-base:0.4.0-20210213

COPY --from=builder /executor /

COPY --from=builder /scheduler /

ENV RUST_LOG=info
ENV RUST_BACKTRACE=full

CMD ["/executor", "--local"]
