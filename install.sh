#!/usr/bin/env bash
set -e

DIRNAME="$(dirname "$0")"
DIR="$(cd "$DIRNAME" && pwd)"

echoerr() {
  echo "$@" 1>&2
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
    'tigrc' \
    'tmux.conf' \
    'vimrc' \
    'vintrc.yaml' \
    'zprofile' \
    'zshrc'
  do
    replace_file "$FILENAME"
  done
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
    git remote add downstream https://github.com/0xdkay/dotfiles.git 2</dev/null
    git pull downstream master

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
    ssh-keygen -t rsa -C "$GITHUB_ACCOUNT"
    eval $(ssh-agent)
    ssh-add "$HOME/.ssh/id_rsa"
    echo "need to add below public key to github"
    cat "$HOME/.ssh/id_rsa.pub"
    echo -n "press enter when you done..."
    read -r t
    ssh -T git@github.com
    ;;

  link)
    install_link
    ;;

  ycm)
    sudo apt-get install -y build-essential cmake
    sudo apt-get install -y python-dev python3-dev

    cd "$HOME/.vim/plugged/YouCompleteMe"
    ./install.py --clang-completer
    ;;

  antibody)
    curl -sL https://git.io/antibody | bash -s
    ;;

  brew)
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    ;;
  chruby)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install chruby
    else
      wget -O chruby-0.3.9.tar.gz https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz
      tar -xzvf chruby-0.3.9.tar.gz
      cd chruby-0.3.9/
      sudo make install
    fi
    ;;
  formulae)
    brew bundle --file="${DIR}/Brewfile" --no-lock
    ;;
  pwndbg)
    init_submodules
    cd "${DIR}/pwndbg"
    ./setup.sh
    ;;
  pyenv)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install pyenv
      brew install pyenv-virtualenv
    else
      curl -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash
    fi
    ;;

  rbenv)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install rbenv
    else
      git_clone https://github.com/rbenv/rbenv.git .rbenv
      git_clone https://github.com/rbenv/ruby-build.git .rbenv/plugins/ruby-build
    fi
    echo 'Done.'
    ;;
  ruby-install)
    if [ "$(uname)" = 'Darwin' ]; then
      brew install ruby-install
    else
      wget -O ruby-install-0.7.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.7.0.tar.gz
      tar -xzvf ruby-install-0.7.0.tar.gz
      cd ruby-install-0.7.0/
      sudo make install
    fi
    ;;
  rustup)
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    ;;
  rvm)
    command curl -sSL https://get.rvm.io | bash -s stable
    ;;
  weechat)
    replace_file 'weechat'
    ;;
  *)
    echo "usage: $(basename "$0") <command>"
    echo ''
    echo 'Available commands:'
    echo '    update        Update installed packages'
    echo '    base          Install basic packages'
    echo '    link          Install symbolic links'
    echo '    antibody      Install Antibody'
    echo '    pwndbg        Install pwndbg'
    echo '    github        Install github account'
    echo '    brew          Install Homebrew on macOS (or Linux)'
    echo '    formulae      Install Homebrew formulae using Brewfile'
    echo '    pyenv         Install pyenv with pyenv-virtualenv'
    echo '    rustup        Install rustup'
    echo '    ruby-install  Install ruby-install'
    echo '    chruby        Install chruby'
    echo '    rbenv         Install rbenv'
    echo '    rvm           Install RVM'
    echo '    weechat       Install WeeChat configuration'
    ;;
esac
