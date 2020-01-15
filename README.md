# mampire
Download a Wordpress site + db into a virtualhost in MAMP
Mampire version 1.1.2 - 
-----------------------------------------------
|                                             |
|               (㇏(•̀vv•́)ノ)                   |
|                                             |
| Downloads all Wordpress project files       |
| and imports remote database for local       | 
| development in MAMP                         |
| Copyright (C) 2019 Hellenic Technologies    |
| https://hellenictechnologies.com/           |
|                                             |
-----------------------------------------------

Usage: $0 -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads

Example 1: Download files only without the database or the uploads folder
./mampire -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t /Users/george/Sites/electropop/htdocs/ -o exclude-uploads

Example 2: Download all files and database in current folder
./mampire -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -d mylocaldbname

add to your BIN path with 
ln -s /path_to_mampire/mampire.sh /usr/local/bin/mampire