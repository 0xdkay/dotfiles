#!/usr/bin/env bash
set -euo pipefail

DIRNAME="$(dirname "$0")"
DIR="$(cd "$DIRNAME" && pwd)"

echoerr() {
  echo "$@" 1>&2
}

usage() {
  echo "usage: $(basename "$0") <command>"
  echo ''
  echo 'Available commands:'
  echo '    update       Update installed packages'
  echo '    base         Install basic packages'
  echo '    github       Install github account'
  echo '    github_gpg   Install github gpg for signing commits'
  echo '    link         Install symbolic links'
  echo '    asdf         Install asdf'
  echo '    brew         Install Homebrew on macOS (or Linux)'
  echo '    chruby       Install chruby'
  echo '    formulae     Install Homebrew formulae using Brewfile'
  echo '    mise         Install mise'
  echo '    n            Install n'
  echo '    pyenv        Install pyenv with pyenv-virtualenv'
  echo '    rbenv        Install rbenv'
  echo '    ruby-install Install ruby-install'
  echo '    rustup       Install rustup'
  echo '    rvm          Install RVM'
  echo '    weechat      Install WeeChat configuration'
}

init_submodules() {
  (cd "$DIR" && git submodule init)
  (cd "$DIR" && git submodule update)
}

git_clone() {
  if [ ! -e "$HOME/$2" ]; then
    echo "Cloning '$1'..."
    git clone "$1" "$HOME/$2"
  else
    # shellcheck disable=SC2088
    echoerr "~/$2 already exists."
  fi
}

rename_with_backup() {
  if [ ! -e "$2" ]; then
    if mv "$1" "$2"; then
      return 0
    fi
  else
    local num
    num=1
    while [ -e "$2.~$num~" ]; do
      (( num++ ))
    done

    if mv "$2" "$2.~$num~" && mv "$1" "$2"; then
      return 0
    fi
  fi
  return 1
}

replace_file() {
  DEST=${2:-.$1}

  if [ -e "$DIR/$1" ]; then
    SRC="$DIR/$1"
  else
    SRC="$HOME/$1"
    if [ ! -e "$SRC" ]; then
      echoerr "Failed to find $1"
      return
    fi
  fi

  # http://www.tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html
  # File exists and is a directory.
  [ ! -d "$(dirname "$HOME/$DEST")" ] && mkdir -p "$(dirname "$HOME/$DEST")"

  # FILE exists and is a symbolic link.
  if [ -h "$HOME/$DEST" ]; then
    if rm "$HOME/$DEST" && ln -s "$SRC" "$HOME/$DEST"; then
      echo "Updated ~/$DEST"
    else
      echoerr "Failed to update ~/$DEST"
    fi
  # FILE exists.
  elif [ -e "$HOME/$DEST" ]; then
    if rename_with_backup "$HOME/$DEST" "$HOME/$DEST.old"; then
      echo "Renamed ~/$DEST to ~/$DEST.old"
      if ln -s "$SRC" "$HOME/$DEST"; then
        echo "Created ~/$DEST"
      else
        echoerr "Failed to create ~/$DEST"
      fi
    else
      echoerr "Failed to rename ~/$DEST to ~/$DEST.old"
    fi
  else
    if ln -s "$SRC" "$HOME/$DEST"; then
      echo "Created ~/$DEST"
    else
      echoerr "Failed to create ~/$DEST"
    fi
  fi
}

install_link() {
  init_submodules
  for FILENAME in \
    'aliases' \
    'bashrc' \
    'ctags' \
    'gemrc' \
    'git-templates' \
    'gitattributes_global' \
    'gitconfig' \
    'gitconfig.user' \
    'gitignore_global' \
    'ideavimrc' \
    'inputrc' \
    'irbrc' \
    'minttyrc' \
    'npmrc' \
    'p10k.zsh' \
    'profile' \
    'screenrc' \
    'tmux.conf' \
    'vimrc' \
    'vintrc.yaml' \
    'zprofile' \
    'zshrc'
  do
    replace_file "$FILENAME"
  done
  replace_file 'bat/config' '.config/bat/config'
  replace_file 'gdb-dashboard/.gdbinit' '.gdbinit'
  replace_file 'gdbinit.d'
  if [ "$(uname)" = 'Darwin' ]; then
    replace_file 'lazygit/config.yml' 'Library/Application Support/lazygit/config.yml'
  else
    replace_file 'lazygit/config.yml' '.config/lazygit/config.yml'
  fi
  replace_file 'pip.conf' '.pip/pip.conf'
  replace_file 'tpm' '.tmux/plugins/tpm'
  [ ! -d "$HOME/.vim" ] && mkdir "$HOME/.vim"
  replace_file '.vim' '.config/nvim'
  replace_file 'vimrc' '.config/nvim/init.vim'
  for FILENAME in \
    'diff-highlight' \
    'diff-hunk-list' \
    'pyg' \
    'server'
  do
    replace_file "bin/$FILENAME" "bin/$FILENAME"
  done
  echo 'Done.'
}

install_gpg() {
  # Retrieve the user.name and user.email from Git configuration
  NAME_REAL=$(git config -f gitconfig.user user.name)
  NAME_EMAIL=$(git config -f gitconfig.user user.email)

  # Check if the values were retrieved successfully
  if [ -z "$NAME_REAL" ] || [ -z "$NAME_EMAIL" ]; then
    echo "Error: Could not retrieve user.name and user.email from Git configuration."
    echo "Check them in \"gitconfig.user\" file."
    exit 1
  fi

  echo "Setting GPG for ${NAME_REAL} (${NAME_EMAIL})"

  # Generate a temporary configuration file for batch key generation
  GPG_CONFIG=$(mktemp)
  cat <<EOF > "$GPG_CONFIG"
  Key-Type: eddsa
  Key-Curve: ed25519
  Key-Usage: sign
  Expire-Date: 0
  Name-Real: $NAME_REAL
  Name-Email: $NAME_EMAIL
EOF

  # Generate the GPG key
  gpg --batch --generate-key "$GPG_CONFIG"

  # Clean up the temporary configuration file
  rm "$GPG_CONFIG"

  # Extract the GPG key ID for the generated key
  KEY_ID=$(gpg --list-keys | grep -B 1 "<$NAME_EMAIL>" | head -n 1 | awk '{print $1}')

  # Check if the key ID was retrieved successfully
  if [ -z "$KEY_ID" ]; then
    echo "Error: Could not retrieve the GPG key ID."
    exit 1
  fi

  # Output the GPG key ID and public key
  echo "GPG Key ID: $KEY_ID"
  echo "need to add below gpg public key to github"
  gpg --armor --export "$KEY_ID"
  echo -n "press enter when you done..."
  # shellcheck disable=SC2034 # just for waiting key press
  read -r TMP

  git config -f ~/.gitconfig.local commit.gpgsign true
  git config -f ~/.gitconfig.local tag.gpgsign true
  git config -f ~/.gitconfig.local user.signingkey "$KEY_ID"
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

case "$1" in
  update)
    if [[ "$(uname)" != 'Darwin' ]]; then
      # update package list
      sudo apt-get update
      sudo apt-get -y dist-upgrade
    else
      brew update
      brew upgrade
    fi

    # dotfiles update
    git pull https://github.com/0xdkay/dotfiles.git master

    # vim update
    vim +PlugUpgrade +PlugClean\! +PlugUpdate +qall\!
    ;;

  base)
    # change archive from us to kr
    sudo sed -i 's/us.archive/kr.archive/g' /etc/apt/sources.list

    # update package list
    sudo apt-get update

    # upgrade before doing
    sudo apt-get -y dist-upgrade

    # install softwares
    sudo apt-get install -y vim zsh tmux git
    #sudo apt-get install build-essential python-dev python-pip
    # sudo apt-get install -y exuberant-ctags
    ;;

  github)
    # setup github
    echo "Type your github account: "
    read -r GITHUB_ACCOUNT
    ssh-keygen -t ed25519 -C "$GITHUB_ACCOUNT"
    eval "$(ssh-agent)"
    ssh-add "$HOME/.ssh/id_ed25519"
    echo "need to add below public key to github"
    cat "$HOME/.ssh/id_ed25519.pub"
    echo -n "press enter when you done..."
    # shellcheck disable=SC2034 # just for waiting key press
    read -r TMP
    ssh -T git@github.com
    ;;

  github_gpg)
    install_gpg
    ;;

  link)
    install_link
    ;;
  asdf)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install asdf
    else
      git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
    fi
    ;;
  brew)
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ;;
  chruby)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install chruby
    else
      wget https://github.com/postmodern/chruby/releases/download/v0.3.9/chruby-0.3.9.tar.gz
      tar -xzvf chruby-0.3.9.tar.gz
      cd chruby-0.3.9/
      sudo make install
    fi
    ;;
  formulae)
    brew bundle --file="${DIR}/Brewfile" --no-lock --no-upgrade
    ;;
  mise)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install mise
    else
      curl https://mise.run | sh
    fi
    ;;
  n)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install n
    else
      curl -L https://bit.ly/n-install | N_PREFIX="$HOME/.n" bash -s -- -y
    fi
    ;;
  pyenv)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install pyenv
      brew install pyenv-virtualenv
    else
      curl https://pyenv.run | bash
    fi
    ;;
  rbenv)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install rbenv
    else
      git_clone https://github.com/rbenv/rbenv.git .rbenv
      git_clone https://github.com/rbenv/ruby-build.git .rbenv/plugins/ruby-build
    fi
    ;;
  ruby-install)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install ruby-install
    else
      wget https://github.com/postmodern/ruby-install/releases/download/v0.9.2/ruby-install-0.9.2.tar.gz
      tar -xzvf ruby-install-0.9.2.tar.gz
      cd ruby-install-0.9.2/
      sudo make install
    fi
    ;;
  rustup)
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    ;;
  rvm)
    \curl -sSL https://get.rvm.io | bash -s stable
    ;;
  weechat)
    replace_file 'weechat'
    ;;
  *)
    usage
    ;;
esac
