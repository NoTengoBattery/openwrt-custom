
ARG GROUP_ID=1000
ARG USER_ID=1000
ARG GROUP=builder
ARG USER=builder

FROM debian:stable-slim AS builder-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends --auto-remove \
      adduser build-essential ca-certificates clang coreutils curl dropbear \
      file flex gawk git-core libncurses5-dev libssl-dev libxml-parser-perl \
      llvm mercurial nano pigz python3-dev python3-setuptools quilt rsync \
      subversion sudo swig unzip wget xsltproc zlib1g-dev zsh
  

# Create non-root user
ARG GROUP_ID
ARG USER_ID
ARG GROUP
ARG USER
ENV GID=${GROUP_ID} UID=${USER_ID}
WORKDIR /tmp
ADD https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh ./ohmyzsh.sh
COPY scripts/docker-user.zsh .
RUN chmod +x docker-user.zsh && \
    ./docker-user.zsh

USER ${USER}:${GROUP}
WORKDIR /home/${USER}/openwrt/repo

# Default shell
CMD ["/usr/bin/env", "-S", "zsh", "--login"]
