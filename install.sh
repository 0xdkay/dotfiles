#!/bin/bash
DIRNAME="$(dirname "$0")"
DIR="$(cd "$DIRNAME" && pwd)"

function echoerr() {
  echo "$@" 1>&2
}

function init_submodules() {
  (cd "$DIR" && git submodule init)
  (cd "$DIR" && git submodule update)
}

function git_clone() {
  if [ ! -e "$HOME/$2" ]; then
    echo "Cloning '$1'..."
    git clone "$1" "$HOME/$2"
  else
    echoerr "~/$2 already exists."
  fi
}

function replace_file() {
  DEST=${2:-.$1}

  # http://www.tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html
  # File exists and is a directory.
  [ ! -d "$(dirname "$HOME/$DEST")" ] && mkdir -p "$(dirname "$HOME/$DEST")"

  # FILE exists and is a symbolic link.
  if [ -h "$HOME/$DEST" ]; then
    if rm "$HOME/$DEST" && ln -s "$DIR/$1" "$HOME/$DEST"; then
      echo "Updated ~/$DEST"
    else
      echoerr "Failed to update ~/$DEST"
    fi
  # FILE exists.
  elif [ -e "$HOME/$DEST" ]; then
    if mv --backup=number "$HOME/$DEST" "$HOME/$DEST.old"; then
      echo "Renamed ~/$DEST to ~/$DEST.old"
      if ln -s "$DIR/$1" "$HOME/$DEST"; then
        echo "Created ~/$DEST"
      else
        echoerr "Failed to create ~/$DEST"
      fi
    else
      echoerr "Failed to rename ~/$DEST to ~/$DEST.old"
    fi
  else
    if ln -s "$DIR/$1" "$HOME/$DEST"; then
      echo "Created ~/$DEST"
    else
      echoerr "Failed to create ~/$DEST"
    fi
  fi
}

case "$1" in
  update)
    # update package list
    sudo apt-get update
    sudo apt-get -y dist-upgrade

    # dotfiles update
    git pull origin master

    # vim update
    vim +PlugUpgrade
    vim +PlugUpdate

    # pwngdb update
    cd ~/.gdb/pwndbg/
    git pull origin master
    ./setup.sh

    sudo apt-get autoremove -y
    ;;

  base)
    # change archive from us to kr
    sudo sed -i 's/us.archive/kr.archive/g' /etc/apt/sources.list

    # update package list
    sudo apt-get update

    # upgrade before doing
    sudo apt-get -y dist-upgrade

    # install softwares
    sudo apt-get install -y vim exuberant-ctags zsh
    sudo apt-get install -y tmux
    sudo apt-get install build-essential python-dev python-pip
    ;;

  gdb)
    # install gdb
    sudo apt-get install -y gdb
    git_clone https://github.com/zachriggle/pwndbg .gdb/pwndbg
    cd ~/.gdb/pwndbg
    ./setup.sh
    ;;

  apache)
    # install apache, mysql, php
    sudo apt-get install -y apache2
    echo "apache is running on ....."
    ifconfig eth0 | grep inet | awk '{ print $2 }'

    sudo apt-get install -y mysql-server libapache2-mod-auth-mysql php5-mysql
    sudo mysql_install_db
    sudo /usr/bin/mysql_secure_installation

    sudo apt-get install -y php5 libapache2-mod-php5 php5-mcrypt
    sudo apt-get install -y php5-mysql php5-sqlite php5-common php5-dev

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
    ssh-add ~/.ssh/id_rsa
    echo "need to add below public key to github"
    cat ~/.ssh/id_rsa.pub
    echo -n "press enter when you done..."
    read t
    ssh -T git@github.com
    ;;

  link)
    init_submodules
    for FILENAME in \
      'bashrc' \
      'gemrc' \
      'gitattributes_global' \
      'gitconfig' \
      'gitignore_global' \
      'ideavimrc' \
      'inputrc' \
      'irbrc' \
      'profile' \
      'screenrc' \
      'tmux.conf' \
      'vim/bundle/netrw' \
      'vimrc' \
      'weechat' \
      'zprofile' \
      'zshrc'
    do
      replace_file "$FILENAME"
    done

    replace_file 'tpm' '.tmux/plugins/tpm'
    for FILENAME in bin/*
    do
      replace_file "$FILENAME" "$FILENAME"
    done
    echo 'Done.'
    ;;

  brew)
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    ;;

  formulae)
    while read COMMAND; do
      trap 'break' INT
      [[ -z "$COMMAND" || ${COMMAND:0:1} == '#' ]] && continue
      brew $COMMAND
    done < "$DIR/Brewfile" && echo 'Done.'
    ;;

  npm)
    if ! which npm &> /dev/null; then
      echoerr 'command not found: npm'
    else
      for PACKAGE in \
        'csslint' \
        'jshint' \
        'jslint' \
        'jsonlint'
      do
        if which $PACKAGE &> /dev/null; then
          echoerr "$PACKAGE is already installed."
        else
          echo "npm install -g $PACKAGE"
          npm install -g "$PACKAGE"
        fi
      done
    fi
    ;;

  pyenv)
    curl -L https://raw.githubusercontent.com/yyuu/pyenv-installer/master/bin/pyenv-installer | bash
    ;;

  rbenv)
    git_clone https://github.com/sstephenson/rbenv.git .rbenv
    git_clone https://github.com/sstephenson/ruby-build.git .rbenv/plugins/ruby-build
    echo 'Done.'
    ;;

  rvm)
    \curl -sSL https://get.rvm.io | bash -s stable
    ;;

  *)
    echo "usage: $(basename "$0") <command>"
    echo ''
    echo 'Available commands:'
    echo '    update    Update installed packages'
    echo '    base      Install basic packages'
    echo '    gdb       Install pwndbg'
    echo '    apache    Install apache, mysql, php5'
    echo '    ftp       Install vsftpd with self-signed certificate'
    echo '    github    Install github account'
    echo '    link      Install symbolic links'
    echo '    brew      Install Homebrew'
    echo '    formulae  Install Homebrew formulae using Brewfile'
    echo '    npm       Install global Node.js packages'
    echo '    pyenv     Install pyenv with pyenv-virtualenv'
    echo '    rbenv     Install rbenv'
    echo '    rvm       Install RVM'
    ;;
esac
