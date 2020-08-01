#!/bin/bash
echo 'Installing wordget into your local/bin directory - sudo required'
# By using ln -s (instead of copying the executable into your bin folder) way you will be able to change the steps of wordget and adjust it accordingly
#install prerequisites

# What type of OS are we on?
host_uname="$(uname -s)"
case "${host_uname}" in
    Linux*)     host_os=Linux;;
    Darwin*)    host_os=Mac;;
    CYGWIN*)    host_os=Windows;;
    MINGW*)     host_os=Windows;;
    *)          host_os="UNKNOWN:${host_uname}"
esac

#mkcert on linux only - required for chrome to accept locally signed ssl certificates
if ! [ -x "$(command -v mkcert)" ] && [ "$host_os" == 'Linux' ];
then
    git clone https://github.com/Homebrew/brew ~/.linuxbrew/Homebrew
    mkdir ~/.linuxbrew/bin
    ln -s ~/.linuxbrew/Homebrew/bin/brew ~/.linuxbrew/bin
    eval $(~/.linuxbrew/bin/brew shellenv)
    brew install mkcert
fi

#rsync on windows
if ! [ -x "$(command -v rsync)" ] && [ "$host_os" == 'Windows' ];
then
    echo "Installing rsync"
    mkdir ~/bin
    curl -OL http://repo.msys2.org/msys/x86_64/rsync-3.1.3-1-x86_64.pkg.tar.xz
    tar -xvf rsync-3.1.3-1-x86_64.pkg.tar.xz
    cp usr/bin/rsync.exe ~/bin
fi

echo "Installing Wordget"
if [ "$host_os" == 'Mac' ] || [ "$host_os" == 'Linux' ];
then
    chmod +x $PWD/wordget.sh
    sudo ln -s $PWD/wordget.sh /usr/local/bin/wordget 
elif [ "$host_os" == 'Windows' ]
    chmod +x $PWD/wordget.sh
    cp wordget/wordget.sh ~/bin/wordget
fi