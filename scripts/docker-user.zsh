#!/usr/bin/env -S zsh --login
set -xe

# Set up user variables
[[ -v GROUP ]] || exit 1
[[ -v GROUP_ID ]] || exit 1
[[ -v USER ]] || exit 1
[[ -v USER_ID ]] || exit 1
export HOME=/home/$USER
SYSTEM_GROUP=$(getent group ${GROUP_ID} | cut -d: -f1)
SYSTEM_USER=$(getent passwd ${USER_ID} | cut -d: -f1)

# Update user and group configuration
[[ -z $SYSTEM_GROUP ]] && addgroup --gid $GROUP_ID $GROUP || groupmod -n $GROUP -g $GROUP_ID $SYSTEM_GROUP
if [[ -z $SYSTEM_USER ]]; then
  adduser --uid $USER_ID --ingroup $GROUP --home $HOME --shell $(which zsh) --disabled-password $USER
else
  usermod -l $USER -u $USER_ID -g $GROUP -d $HOME -s $(which zsh) -c "$USER" $SYSTEM_USER
fi

# Build user directories
mkdir -p $HOME/repo
chmod -R 700 $HOME
chown -R $USER:$GROUP $HOME

# Set up user environment
echo export EDITOR=\"nano\" >>$HOME/.zshenv
echo typeset -U path >>$HOME/.zlogin

# Install nano syntax highlighting
echo 'include /usr/share/nano/*.nanorc' >>$HOME/.nanorc
echo 'include /usr/share/nano/extra/*.nanorc' >>$HOME/.nanorc
chown -R $USER:$GROUP $HOME
su $USER -c "curl https://raw.githubusercontent.com/scopatz/nanorc/master/install.sh | zsh"

# Install oh-my-zsh
chmod a+rx ohmyzsh.sh && su $USER -c "zsh -cel ./ohmyzsh.sh"

chown -R $USER:$GROUP $HOME

rm -rf ./*(D)

exit 0