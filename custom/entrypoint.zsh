#!/usr/bin/env -S zsh --login
set -xe

# Update and install all feeds
./scripts/feeds update -a
./scripts/feeds install -a

ulimit -Hn 26214
exec "$@"
