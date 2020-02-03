#!/bin/bash
#-----------------------------------------------------------
# Download a Wordpress site + db into a virtualhost in MAMP
# GT - Xmas 2019
# **IMPORTANT NOTE** BEFORE USING
# export PATH=$PATH:/mnt/c/MAMP/bin/mysql/bin -- needs mysql.exe and mysqldump.exe
# setup ssh access for ubuntu on windows and remote server
# make sure you are allowed to access the remote mysql
# Run as root inside Ubuntu app in order for this to work
# ----------------------------------------------------------

local_db_user='root'
local_db_password='[INSERT_LOCAL_MYSQL_PASS_HERE]'

show_instructions(){
    echo "Mampire version 1.1.2 - "
    echo "-----------------------------------------------"
    echo "|                                             |"
    echo "|                   (\(•̀vv•́)/)                |"
    echo "|                                             |"
    echo "| Downloads all Wordpress project files       |"
    echo "| and imports remote database for local       |" 
    echo "| development in MAMP                         |"
    echo "| (C) 2019 Hellenic Technologies              |"
    echo "| https://hellenictechnologies.com/           |"
    echo "|                                             |"
    echo "-----------------------------------------------"
    echo ""
    echo "Usage: $0 -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads"
    echo ""
    echo "Example 1: Download files only without the database or the uploads folder"
    echo "mampire -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t /Users/george/Sites/electropop/htdocs/ -o exclude-uploads"
    echo ""
    echo "Example 2: Download all files and database in current folder (navigate (cd) into your local folder with terminal)"
    echo "mampire -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -d mylocaldbname"

    echo ""
    echo -e "\t-h [WEBSITE HOST/IP ADDRESS]"
    echo -e "\t-u [WEBSITE USERNAME]"
    echo -e "\t-s [REMOTE DIRECTORY]"
    echo -e "\t-t [LOCAL DIRECTORY]"
    echo -e "\t-d [LOCAL DATABASE NAME]"
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


#Begin the process

echo "Downloading website files..."

#check if they want the uploads folder or not
if [ $exclude_uploads ] 
then 
rsync  -e 'ssh -i /root/.ssh/id_rsa -q -p 2310' -arpz --exclude 'wp-content/uploads/*' --progress $website_username@$website_ipaddress:$source_directory $target_directory
else 
rsync  -e 'ssh -i /root/.ssh/id_rsa -q -p 2310' -arpz --progress $website_username@$website_ipaddress:$source_directory $target_directory
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
mysqldump --add-drop-database -P 3306 --host=$website_ipaddress --user=$WPDBUSER --password=$WPDBPASS $WPDBNAME 2> /dev/null > ${database_name}_temp_db.sql && \
mysql --user=$local_db_user --password=$local_db_password --host=127.0.0.1 -e "\
CREATE DATABASE IF NOT EXISTS ${database_name}; \
USE ${database_name}; \
source ${database_name}_temp_db.sql;" 2> /dev/null \
&& rm ${database_name}_temp_db.sql

#replace the wp-config password to connect to the database
sed -i -e "s|${WPDBNAME}|${database_name}|g" ${target_directory}/wp-config.php
sed -i -e "s|${WPDBUSER}|$local_db_user|g" ${target_directory}/wp-config.php
sed -i -e "s|${WPDBPASS}|${local_db_password}|g" ${target_directory}/wp-config.php
fi