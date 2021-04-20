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
    git pull origin master

    # vim update
    vim +PlugUpgrade +PlugClean\! +PlugUpdate +qall\!

    if [ "$(uname)" != "Darwin" ] && [ -e "$HOME/.gdb/pwndbg" ]; then
      # pwngdb update
      cd $HOME/.gdb/pwndbg/
      git pull origin master
      ./setup.sh

      sudo apt-get autoremove -y
    fi
    ;;

  base)
    # change archive from us to kr
    sudo sed -i 's/us.archive/kr.archive/g' /etc/apt/sources.list

    # update package list
    sudo apt-get update

    # upgrade before doing
    sudo apt-get -y dist-upgrade

    # install softwares
    sudo apt-get install -y vim zsh tmux
    sudo apt-get install build-essential python-dev python-pip
    # sudo apt-get install -y exuberant-ctags
    ;;

  gdb)
    if [[ "$(uname)" != 'Darwin' ]]; then
      if [[ ! -e "$HOME/.gdb/pwndbg" ]]; then
      # install gdb
      sudo apt-get install -y gdb
      git_clone https://github.com/zachriggle/pwndbg .gdb/pwndbg
      cd $HOME/.gdb/pwndbg
      ./setup.sh

      else
        echo "already exists"
      fi
    else
      if [[ ! -e "$HOME/.gdb/pwndbg" ]]; then
      brew install gdb
      git_clone https://github.com/zachriggle/pwndbg .gdb/pwndbg
      cd $HOME/.gdb/pwndbg
      ./setup.sh
      else
        echo "already exists"
      fi
    fi
    ;;

  apache)
    # install apache, mysql, php
    sudo apt-get install -y apache2
    echo "apache is running on ....."
    ifconfig eth0 | grep inet | awk '{ print $2 }'

    sudo apt-get install -y mysql-server libapache2-mod-auth-mysql php7.0-mysql
    sudo mysql_install_db
    sudo /usr/bin/mysql_secure_installation

    sudo apt-get install -y php7.0 libapache2-mod-php7.0 php7.0-mcrypt
    sudo apt-get install -y php7.0-mysql php7.0-sqlite php7.0-common php7.0-dev

    sudo service apache2 restart
    ;;

  ftp)
    # install vsftpd with ftps
    sudo apt-get install -y vsftpd
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem
    sudo sed -i 's/\anonymous_enable=.*/anonymous_enable=NO/g' /etc/vsftpd.conf
    sudo sed -i 's/\#local_enable=.*/local_enable=YES/g' /etc/vsftpd.conf
    sudo sed -i 's/\#write_enable=.*/write_enable=YES/g' /etc/vsftpd.conf
    sudo sed -i 's/rsa_cert_file.*/rsa_cert_file=\/etc\/ssl\/private\/vsftpd.pem/g' /etc/vsftpd.conf
    sudo sed -i 's/rsa_private_key_file.*/rsa_private_key_file=\/etc\/ssl\/private\/vsftpd.pem/g' /etc/vsftpd.conf
    echo "ssl_enable=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
    echo "allow_anon_ssl=NO" | sudo tee -a /etc/vsftpd.conf > /dev/null
    echo "force_local_data_ssl=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
    echo "force_local_logins_ssl=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
    echo "ssl_tlsv1=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
    echo "ssl_sslv2=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
    echo "ssl_sslv3=YES" | sudo tee -a /etc/vsftpd.conf > /dev/null
    echo "require_ssl_reuse=NO" | sudo tee -a /etc/vsftpd.conf > /dev/null
    echo "ssl_ciphers=HIGH" | sudo tee -a /etc/vsftpd.conf > /dev/null
    sudo service vsftpd restart
    ;;

  github)
    # setup github
    echo "Type your github account: "
    read GITHUB_ACCOUNT
    ssh-keygen -t rsa -C $GITHUB_ACCOUNT
    eval $(ssh-agent)
    ssh-add $HOME/.ssh/id_rsa
    echo "need to add below public key to github"
    cat $HOME/.ssh/id_rsa.pub
    echo -n "press enter when you done..."
    read t
    ssh -T git@github.com
    ;;

  link)
    install_link
    ;;

  ycm)
    sudo apt-get install -y build-essential cmake
    sudo apt-get install -y python-dev python3-dev

    cd $HOME/.vim/plugged/YouCompleteMe
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
    echo '    link         Install symbolic links'
    echo '    brew         Install Homebrew on macOS (or Linux)'
    echo '    chruby       Install chruby'
    echo '    formulae     Install Homebrew formulae using Brewfile'
    echo '    pwndbg       Install pwndbg'
    echo '    pyenv        Install pyenv with pyenv-virtualenv'
    echo '    rbenv        Install rbenv'
    echo '    ruby-install Install ruby-install'
    echo '    rustup       Install rustup'
    echo '    rvm          Install RVM'
    echo '    weechat      Install WeeChat configuration'
    ;;
esac
