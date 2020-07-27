WordGet - Download a Wordpress Website into your local development

Downloads all Wordpress website files and imports remote database for local development in MAMP/XAMPP or LOCALWP by Flywheel                   
Copyright (C) 2020 Hellenic Technologies
https://hellenictechnologies.com/     
tsarouxas@hellenictechnologies.com      
version 1.2.4

INSTALLATION:

STEP 1 - INSERT YOUR LOCAL DB CREDENTIALS 

At the top of the file replace these with your local db user/pass

local_db_user='YOUR_LOCAL_DB_PASSWORD eg. root'

local_db_password='YOUR_LOCAL_DB_PASSWORD'


STEP 2 - Make wordget executable and add to your PATH 

chmod +x /path_to_wordget/wordget.sh
ln -s /path_to_wordget/wordget.sh /usr/local/bin/wordget
You can now run it from anywhere in a terminal just by typing the command: 

wordget



USAGE: 

wordget.sh -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads

Example 1: Download files only without the database or the uploads folder
wordget.sh -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t /Users/george/Sites/electropop/htdocs/ -o exclude-uploads

Example 2: Download all files and database in current folder
wordget.sh -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -d mylocaldbname


CHANGELOG:
- 2020-07-26 direct integration with LocalWP - using option localwp
- 2020-06-29 fixed mysqldump downloading of remote database

