# Mampire v1.1.2
Download a Wordpress site + db into a virtualhost in MAMP or LOCALWP by Flywheel

Downloads all Wordpress project files and imports remote database for local development in MAMP                    Copyright (C) 2019 Hellenic Technologies
https://hellenictechnologies.com/           

INSTALLATION:

STEP 1 - INSERT YOUR LOCAL DB CREDENTIALS 

At the top of the file replace these with your local db user/pass

local_db_user='YOUR_LOCAL_DB_PASSWORD eg. root'

local_db_password='YOUR_LOCAL_DB_PASSWORD'


STEP 2 - Make mampire executable and add to your PATH 

chmod +x /path_to_mampire/mampire.sh

ln -s /path_to_mampire/mampire.sh /usr/local/bin/mampire

You can now run it from anywhere in a terminal just by typing the command: 

mampire



USAGE: 

mampire.sh -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads

Example 1: Download files only without the database or the uploads folder
mampire.sh -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t /Users/george/Sites/electropop/htdocs/ -o exclude-uploads

Example 2: Download all files and database in current folder
mampire.sh -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -d mylocaldbname

TODO:
enable wpconfig debugging
sed -i '' '/\/\* That.s all, stop editing! Happy blogging. \*\// i\
// FX_SCRIPT FS_METHOD \
define( "FS_METHOD", "direct" ); \
\
// FX_SCRIPT WP_DEBUG \
define( "WP_DEBUG", true ); \
define( "WP_DEBUG_LOG", true ); \
\
// FX_SCRIPT DISABLE_WP_CRON \
define( "DISABLE_WP_CRON", true ); \
\
' wp-config.php


#create a dev user directly into the wp database for the developer to use directly -- poses as a risk in case the database goes online. needs a tough password using 

date |md5 | head -c8; echo


wp user create tsarouxas tsarouxas@hellenictechnologies.com --role=administrator --user_pass=local



CHANGELOG:
- 2020-06-29 fixed mysqldump downloading of remote database

