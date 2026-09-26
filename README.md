WordGet - Download a Wordpress Website into your local development

Downloads all Wordpress website files and imports remote database for local development in MAMP/XAMPP or LOCALWP by Flywheel                   
Copyright (C) 202[0-6] Hellenic Technologies
https://hellenictechnologies.com/     
tsarouxas@hellenictechnologies.com      
version 1.2.4

HOW IT WORKS - PULL ONLY:

WordGet is a pull-only tool. It never deploys, pushes or syncs anything back to the source site.

1. Set up a new, empty WordPress project where you want the copy: on your machine (LocalWP, VVV, MAMP/XAMPP) or on another server.
2. Run wordget from that target. It connects to the source over SSH and fetches the files (rsync) and, if you ask for it with -d, the database.
3. Everything WordGet changes is on the target side: the downloaded files, the local database import, URL search-replace, and the local wp-config.php.

The source site is treated as read-only: no files are uploaded to it, and its files and database are never modified.
Only exception: in localwp / vvv / localmode with -d, the database is exported to a temporary local.sql / local.sql.gz in the source directory, which WordGet deletes again once it's downloaded.

Direction is always SOURCE (-h/-u/-s) --> TARGET (-t / current folder). To go the other way, use a deployment tool, not WordGet.

INSTALLATION (Linux & macOS):

```bash
curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | bash
```

Installs wordget into ~/.local/bin for the current user (no sudo). If that folder isn't in your PATH, the installer prints the line to add to ~/.zshrc or ~/.bashrc.
Run the same command again to upgrade.

Options (environment variables):
- `WORDGET_INSTALL_DIR=~/bin` install somewhere else
- `WORDGET_REF=localwp` install from another branch or tag

e.g.
```bash
curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | WORDGET_INSTALL_DIR=~/bin bash
```

USAGE: 

Interactive setup - cd into your new (target) project folder and run wordget with no parameters:

```bash
cd ~/Sites/mysite/htdocs
wordget
```

It asks for the server, SSH user, port (default 22), remote and local directories, local environment (plain / LocalWP / VVV), database and uploads, then prints the equivalent one-line command so you can skip the questions next time.
A trailing / is added to both directories automatically (~/public_html becomes ~/public_html/), so the folder's contents are copied, not the folder itself.

Or pass everything as parameters:

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

