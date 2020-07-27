#!/bin/bash
echo 'Installing wordget into your local/bin directory - sudo required'
chmod +x $PWD/wordget.sh
sudo ln -s $PWD/wordget.sh /usr/local/bin/wordget 
# By using ln -s (instead of copying the executable into your bin folder) way you will be able to change the steps of wordget and adjust it accordingly
#TODO: install prerequisites
#mkcert
#brew
#rsync