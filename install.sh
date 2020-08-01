#!/bin/bash
echo 'Installing wordget into your local/bin directory - sudo required'
chmod +x $PWD/wordget.sh
sudo ln -s $PWD/wordget.sh /usr/local/bin/wordget 
# By using ln -s (instead of copying the executable into your bin folder) way you will be able to change the steps of wordget and adjust it accordingly
#TODO: install prerequisites

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
#rsync