#!/bin/bash
#------------------
# Creates a new Wordpress site inside valet
# George Tsarouchas
# tsarouxas@hellenictechnologies.com
# Created December 2019 - updated July 2020
# IMPORTANT NOTE BEFORE USING
# add to your BIN path with 
#ln -s /path_to_wordget/wordcreate.sh /usr/local/bin/wordcreate
# ------------------
admin_wp_user='wp';
admin_wp_pass='wp';
local_db_user='wp'
local_db_pass='wp'
#add to path
# sudo ln -s ~/tools/wordget/wordcreate.sh /usr/local/bin/wordcreate
echo "usage: wordcreate SITENAME FOLDER(optional)"
new_site_domain=$1
    if [ $2 ] 
    then 
        new_site_folder=$2
    else 
        new_site_folder=$PWD
    fi
echo "creating: $new_site_domain in: $new_site_folder and linking to valet"
mysql --user=$local_db_user --password=$local_db_pass --host=localhost -e "CREATE DATABASE IF NOT EXISTS ${new_site_domain}";
    if [ $new_site_domain ] && [ $new_site_folder ];
    then
        cd $new_site_folder && wp core download;
        #wp core download --locale=el
        cd $new_site_folder && wp config create --dbname=$new_site_domain --dbuser=$local_db_user --dbpass=$local_db_pass;
        wp core install --url=https://$new_site_domain.test --title=$new_site_domain --admin_user=$admin_wp_user --admin_password=$admin_wp_pass --admin_email=admin@example.com;
        #wpconfig set this for mysql - define('DB_HOST', '127.0.0.1:3306');
        cd $new_site_folder && valet link $new_site_domain && valet secure $new_site_domain
    fi