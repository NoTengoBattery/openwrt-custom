# syntax=docker/dockerfile:1


ARG GROUP_ID=1001
ARG GROUP=openwrt
ARG USER_ID=1000
ARG USER=openwrt


FROM debian:bullseye-slim as notengobattery-openwrt-core
WORKDIR /tmp
COPY ./custom/prepare-system.zsh ./
RUN apt update && apt --no-install-recommends -y install zsh
RUN zsh -cel ./prepare-system.zsh


FROM notengobattery-openwrt-core as notengobattery-openwrt-user
ARG GROUP_ID
ARG GROUP
ARG USER_ID
ARG USER
WORKDIR /tmp
ADD https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh ./ohmyzsh.sh
COPY ./custom/prepare-user.zsh ./
RUN zsh -cel ./prepare-user.zsh


FROM notengobattery-openwrt-user as notengobattery-openwrt
ARG GROUP
ARG USER
RUN mkdir -p /openwrt && chown -R $USER:$GROUP /openwrt
USER $USER
WORKDIR /openwrt
RUN git config --global --add safe.directory /openwrt
COPY . ./


FROM notengobattery-openwrt
ENTRYPOINT ["custom/entrypoint.zsh"]
