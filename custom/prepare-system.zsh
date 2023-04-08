#!/usr/bin/env -S zsh --login
set -xe

# Update the package list and upgrade all currently installed packages
apt-get update -y
apt-get upgrade -y
apt-get install --no-install-recommends -y apt-utils zsh

# Install core system dependencies (explicitly requested by OpenWrt scripts, simplified tree)
apt-get install --no-install-recommends -y \
  bash build-essential bzip2 coreutils 	debianutils diffutils fakeroot file findutils gawk git \
  grep libc-bin ncurses-dev perl pigz python3 python3-distutils rsync tar unzip util-linux wget

# Command line tools and clients utilities, non-explicitly requested dependencies
apt-get install --no-install-recommends -y \
  curl htop less nano passwd psmisc

# Other cool project dependencies
apt-get install --no-install-recommends -y \
  libjemalloc2 	ruby-bundler

# zsh for extra coolness
apt-get install --no-install-recommends -y \
  zsh-autosuggestions zsh-syntax-highlighting

# Clean up
apt autoremove -y
apt clean -y

rm -rf ./*(D)

exit 0
