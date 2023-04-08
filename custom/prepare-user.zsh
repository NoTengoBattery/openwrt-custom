#!/usr/bin/env -S zsh --login
set -xe

# Set up user
export GROUP=openwrt
export USER=openwrt
export HOME=/home/$USER

# Update user and group configuration
groupadd -g $GROUP_ID $GROUP
useradd -u $USER_ID -g $GROUP_ID -d $HOME -s $(which zsh) $USER

# Build user directories
mkdir -p $HOME
chmod -R 700 $HOME
chown -R $USER:$GROUP $HOME

# Prepare LD_PRELOAD for jemalloc (a better malloc implementation)
PRELOAD=$(echo "$LD_PRELOAD $(find /usr/lib -name 'libmimalloc*' | head -n 1)" | xargs)
echo export LD_PRELOAD=\"$PRELOAD\" >>$HOME/.zshenv

# Install nano syntax highlighting
echo 'include /usr/share/nano/*.nanorc' >>$HOME/.nanorc
echo 'include /usr/share/nano/extra*.nanorc' >>$HOME/.nanorc

chmod a+rx ohmyzsh.sh && su $USER -c "zsh -cel ./ohmyzsh.sh"

chown -R $USER:$GROUP $HOME

rm -rf ./*(D)

exit 0
