WordGet - Download a Wordpress Website into your local development

Downloads all Wordpress website files and imports remote database for local development in MAMP/XAMPP or LOCALWP by Flywheel                   
Copyright (C) 2020 Hellenic Technologies
https://hellenictechnologies.com/     
tsarouxas@hellenictechnologies.com      
version 1.2.4

INSTALLATION (Linux & macOS):

```bash
curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | bash
```

Installs wordget into /usr/local/bin (asks for sudo if needed), or ~/.local/bin if sudo isn't available.
Run the same command again to upgrade.

Options (environment variables):
- `WORDGET_INSTALL_DIR=~/bin` install somewhere else
- `WORDGET_REF=localwp` install from another branch or tag

e.g.
```bash
curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | WORDGET_INSTALL_DIR=~/bin bash
```

USAGE: 

wordget -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads

EXAMPLES: 
1) Download the whole project into a LocalWP site (Requires to be run from the right-click option "Open Site Shell" inside LocalWP)
 wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t ~/Sites/electropop/htdocs/ -o localwp,exclude-uploads
    
2) Download files only without the database or the uploads folder
wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t /Users/george/Sites/electropop/htdocs/ -o exclude-uploads

3) Download all files and database in current folder
wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -d mylocaldbname

REQUIREMENTS:
- wp needs to be installed on the remote server in case that LocalWP is to be used locally.
- Windows users MUST always run Wordget from a GIT BASH shell


CHANGELOG:
- 2020-07-26 direct integration with LocalWP - using option localwp
- 2020-06-29 fixed mysqldump downloading of remote database

