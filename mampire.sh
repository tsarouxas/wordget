#!/bin/bash
#------------------
# Download a Wordpress site + db into a virtualhost in MAMP
# George Tsarouchas
# tsarouxas@hellenictechnologies.com
# XMAS2019
# IMPORTANT NOTE BEFORE USING
# add to your BIN path with 
#ln -s /path_to_mampire/mampire.sh /usr/local/bin/mampire
# ------------------
#INITILIAZE THESE 2 variables
local_db_user='YOUR_LOCAL_DB_PASSWORD eg. root'
local_db_password='YOUR_LOCAL_DB_PASSWORD'

show_instructions(){
    echo "Mampire version 1.1.2 - "
    echo "-----------------------------------------------"
    echo "|                                             |"
    echo "|               (㇏(•̀vv•́)ノ)                   |"
    echo "|                                             |"
    echo "| Downloads all Wordpress project files       |"
    echo "| and imports remote database for local       |" 
    echo "| development in MAMP                         |"
    echo "| Copyright (C) 2019 Hellenic Technologies    |"
    echo "| https://hellenictechnologies.com/           |"
    echo "|                                             |"
    echo "-----------------------------------------------"
    echo ""
    echo "Usage: $0 -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads"
    echo ""
    echo "Example 1: Download files only without the database or the uploads folder"
    echo "./mampire -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t /Users/george/Sites/electropop/htdocs/ -o exclude-uploads"
    echo ""
    echo "Example 2: Download all files and database in current folder"
    echo "./mampire -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -d mylocaldbname"

    echo ""
    echo -e "\t-h [WEBSITE HOST/IP ADDRESS]"
    echo -e "\t-u [WEBSITE USERNAME]"
    echo -e "\t-s [REMOTE DIRECTORY]"
    echo -e "\t-t [LOCAL DIRECTORY]"
    echo -e "\t-d [LOCAL DATABASE NAME]"
    echo -e "\t-p [OPTIONAL SSH PORT NUMBER]"
    echo -e "\t-o [OPTIONAL PARAMETERS - exclude-uploads (COMMA SEPARATED)]"
    echo ""
    exit 1 
}

while getopts "h:u:s:t:d:o:" opt
do
   case "$opt" in
      h ) website_ipaddress=$OPTARG ;;
      u ) website_username=$OPTARG ;;
      s ) source_directory=$OPTARG ;;
      t ) target_directory=$OPTARG ;;
      d ) database_name=$OPTARG ;;
      o ) extra_options=$OPTARG ;;
      p ) port_number=$OPTARG ;;
      ? ) echo OPTARG; show_instructions ;;
   esac
done

#Check if all parameters are given by user
if [ -z $website_ipaddress ] || [ -z $website_username ] || [ -z $source_directory ]
then
   show_instructions
   echo "You need to fill in all parameters";
fi

# Check for extra parameters
IFS=',' read -r -a array <<< "$extra_options"

for element in "${array[@]}"
do
    if [ $element == "exclude-uploads" ] 
    then
        exclude_uploads=1
    fi
done

#Confirmation prompt
echo ""
if [ -z $target_directory ] 
then 
    target_directory=$(pwd);
fi
echo "I will now download the remote directory ${source_directory} into your local directory ${target_directory} from user ${website_username} on server ${website_ipaddress}."
if [ $exclude_uploads ] 
then 
    echo "The uploads/ folder will not be downloaded. ";
fi
if [ $database_name ] 
then 
    echo "The remote database will be downloaded and imported into your local database: $database_name.";
else
    echo "The remote database will not be downloaded.";
fi

echo ""
read -p "Are you sure you want to continue? <y/N> " prompt
if [[ $prompt != "y" && $prompt != "Y" && $prompt != "yes" && $prompt != "Yes" ]]
then
  exit 0
fi

if [ -z $port_number ] 
then 
    port_number=22;
fi

#Begin the process

echo "Downloading website files..."

#check if they want the uploads folder or not
if [ $exclude_uploads ] 
then 
rsync  -e "ssh -i ~/.ssh/id_rsa -q -p $port_number -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no" -arpz --exclude 'wp-content/uploads/*' --progress $website_username@$website_ipaddress:$source_directory $target_directory
else 
rsync  -e "ssh -i ~/.ssh/id_rsa -q -p $port_number -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no" -arpz --progress $website_username@$website_ipaddress:$source_directory $target_directory
fi

if [ $database_name ]
then
    echo "Downloading Database and Importing to local database $database_name"
    WPDBNAME=`cat ${target_directory}/wp-config.php | grep DB_NAME | cut -d \' -f 4`
    WPDBUSER=`cat ${target_directory}/wp-config.php | grep DB_USER | cut -d \' -f 4`
    WPDBPASS=`cat ${target_directory}/wp-config.php | grep DB_PASSWORD | cut -d \' -f 4`
echo "remote DB credentials"
echo "D: $WPDBNAME";
echo "U: $WPDBUSER";
echo "P: $WPDBPASS";
    #import the new one into $database_name
    #TODO --compress and gzip
mysqldump --add-drop-database -P 3306 -h$website_ipaddress -u$WPDBUSER --password=$WPDBPASS $WPDBNAME 2> /dev/null > ${database_name}_temp_db.sql && \
mysql -u{$local_db_user} -p${local_db_password} -h'127.0.0.1' -e " \
CREATE DATABASE IF NOT EXISTS ${database_name}; \
USE ${database_name}; \
source ${database_name}_temp_db.sql;" 2> /dev/null \
&& rm ${database_name}_temp_db.sql

#replace the wp-config password to connect to the database
sed -i -e "s|${WPDBNAME}|${database_name}|g" ${target_directory}/wp-config.php
sed -i -e "s|${WPDBUSER}|$local_db_user|g" ${target_directory}/wp-config.php
sed -i -e "s|${WPDBPASS}|${local_db_password}|g" ${target_directory}/wp-config.php
fi
