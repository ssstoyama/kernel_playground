ARG zigv="zig-linux-x86_64-0.11.0-dev.2247+38ee46dda"

# Build
FROM debian:bullseye AS builder

ARG zigv

WORKDIR /tmp
RUN apt update && apt install -y \
  curl \
  xz-utils

RUN curl https://ziglang.org/builds/${zigv}.tar.xz \
  | tar -Jxvf -

# Package
FROM debian:bullseye

ARG zigv

COPY --from=builder /tmp/${zigv} /usr/local/bin/${zigv}
RUN ln -s /usr/local/bin/${zigv}/zig /usr/local/bin/zig

RUN apt update && apt install -y \
      git \
      qemu-system-x86 \
      vim \
      build-essential \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*
