#!/bin/bash
#------------------
# Creates a new Wordpress site inside valet
# George Tsarouchas
# tsarouxas@hellenictechnologies.com
# July 2021
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

show_instructions(){
    echo "WordCreate v1.0.3"
    echo "Creates a new Wordpress site inside Valet"
    echo "--------------------------------"
    echo "(C) 2020-2021 Hellenic Technologies"
    echo "https://hellenictechnologies.com"
    echo ""
    echo "USAGE:"
    echo "wordcreate SITENAME FOLDER(optional)"
    echo ""
    echo "EXAMPLE 1 - Create mysite.test with wordpress installed"
    echo "wordcreate mysite"
    echo ""
    echo "EXAMPLE 2 - Create mycoolsite.test inside the folder ~/Sites/thisfolder/public_html"
    echo "wordcreate mysite ~/Sites/thisfolder/public_html"
    echo ""
    #Check if command is in PATH
    if ! [ -x "$(command -v wordcreate)" ]; then
    echo "ADD TO PATH in order to be able to use this command globally"
        echo "sudo ln -s $PWD/wordcreate.sh /usr/local/bin/wordcreate"
        exit
    fi
    
    exit 1 
}

#START
new_site_domain=$1
if [ $2 ] 
then 
    new_site_folder=$2
    #create the folder if it doesnt exist
    if [[ ! -e $new_site_folder ]]; then
        mkdir -p $new_site_folder
    fi
else 
    new_site_folder=$PWD
fi

if [ $new_site_domain ] && [ $new_site_folder ];
then
    echo "creating: $new_site_domain in: $new_site_folder and linking to valet"
    mysql --user=$local_db_user --password=$local_db_pass --host=localhost -e "CREATE DATABASE IF NOT EXISTS ${new_site_domain}";
    cd $new_site_folder && wp core download;
    #wp core download --locale=el
    cd $new_site_folder && wp config create --dbname=$new_site_domain --dbuser=$local_db_user --dbpass=$local_db_pass;
    wp core install --url=https://$new_site_domain.test --title=$new_site_domain --admin_user=$admin_wp_user --admin_password=$admin_wp_pass --admin_email=admin@example.com;
    #wpconfig set this for mysql - define('DB_HOST', '127.0.0.1:3306');
    cd $new_site_folder && valet link $new_site_domain && valet secure $new_site_domain
else
show_instructions
fi