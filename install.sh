#!/bin/bash
#Installer for windows
mkdir ~/bin
echo "Installing Wordget"
cp wordget/wordget.sh ~/bin/wordget
echo "Installing rsync"
curl -OL http://repo.msys2.org/msys/x86_64/rsync-3.1.3-1-x86_64.pkg.tar.xz
tar -xvf rsync-3.1.3-1-x86_64.pkg.tar.xz
cp usr/bin/rsync.exe ~/bin