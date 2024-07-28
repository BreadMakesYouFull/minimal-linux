ARG BASE_IMG=docker.io/debian:12.5-slim@sha256:67f3931ad8cb1967beec602d8c0506af1e37e8d73c2a0b38b181ec5d8560d395

FROM $BASE_IMG AS base

ARG MAKEFLAGS=""
ENV MAKEFLAGS=$MAKEFLAGS

RUN apt-get update  && apt-get install --no-install-recommends -y \
    bc \
    bison \
    build-essential \
    ca-certificates \
    cpio \ 
    flex \
    gcc \
    grub-common \
    grub-efi \
    grub-efi-amd64-bin \
    grub-pc-bin \
    libelf-dev \
    libncurses5-dev \
    libssl-dev \
    mtools \
    pv \
    vim \
    wget \
    xorriso \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /out
COPY ["*", "."]

RUN ./minimal_linux.sh
