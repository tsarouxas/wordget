#!/bin/bash
#------------------
# Download a Wordpress site + db into a virtualhost in MAMP
# George Tsarouchas
# tsarouxas@hellenictechnologies.com
# Created December 2019 - updated July 2020
# IMPORTANT NOTE BEFORE USING
# add to your BIN path with 
#ln -s /path_to_wordget/wordget.sh /usr/local/bin/wordget
# ------------------
#INITILIAZE THESE 2 variables
local_db_user='root'
local_db_password='root'
local_dev_env='default'

show_instructions(){
    echo "WordGet v1.2.4"
    echo "--------------------------------"
    echo "(C) 2020 Hellenic Technologies"
    echo "https://hellenictechnologies.com"
    echo ""
    echo "Downloads all Wordpress website files and database and imports them into your local development enviroment"
    echo ""
    echo "USAGE:"
    echo "wordget -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads"
    echo ""
    echo "REQUIREMENTS:"
    echo "Make sure that your SSH PUBLIC key is installed on the source server. "
    echo "IMPORTANT: If the option -o localwp is going to be used, then wp-cli MUST be installed on the source server and wordget NEEDS to be run through 'Open Site Shell' inside LocalWP"
    echo ""
    echo "EXAMPLES:"
    echo "1) Download the whole project into a LocalWP site"
    echo "wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t ~/Sites/electropop/htdocs/ -o localwp,exclude-uploads"
    echo ""
    echo "2) Download files only without the database or the uploads folder"
    echo "wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t ~/Sites/electropop/htdocs/ -o exclude-uploads"
    echo ""
    echo "3) Download all files and database in current folder"
    echo "wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -d mylocaldbname"
    echo ""
    echo "PARAMETERS:"
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

while getopts "h:u:s:t:d:p:o:" opt
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

for cmd_option in "${array[@]}"
do
    if [ "$cmd_option" == "exclude-uploads" ] 
    then
        exclude_uploads=1
    fi
    #use LocalWP as local development environment
    if [ "$cmd_option" == "localwp" ] #TODO: needs to check SHELL env variables to detect it automatically
    then
        local_dev_env="localwp"
    fi
done

#Confirmation prompt
echo ""
echo "Wordget v1.2.4"
echo ""
if [ -z $target_directory ] 
then 
    target_directory=$(pwd);
fi
if [ "$local_dev_env" == "localwp" ]
then 
    echo "LocalWP detected!";
    echo "";
fi
echo "From: ${website_username}@${website_ipaddress}."
echo "Remote Directory: ${source_directory}"
echo "into Local Directory: ${target_directory}"
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

# What type of OS are we on?
host_uname="$(uname -s)"
case "${host_uname}" in
    Linux*)     host_os=Linux;;
    Darwin*)    host_os=Mac;;
    CYGWIN*)    host_os=Windows;;
    MINGW*)     host_os=Windows;;
    *)          host_os="UNKNOWN:${host_uname}"
esac

#Begin the process - We know enough 
if [ $local_dev_env ]
then 
    #Get the env variables that the specific site has.
    echo "Preparing Import";

    #get the local site domain name
    local_domain_url=$(wp option get siteurl)

     if [ $database_name ]
    then
        #Find out the MYSQL Socket that LocalWP is using
        mysql_socket=$(echo ${MYSQL_HOME//conf\//})"/mysqld.sock"
        #echo "Mysql socket is: $mysql_socket";
        #Get the remote site domain name
        remote_domain_url=$(ssh $website_username@$website_ipaddress -p $port_number "cd $source_directory && wp option get siteurl")
        echo "Remote URL is: $remote_domain_url";
        echo "Local URL is: $local_domain_url";
        echo "Fetching remote Database";
        #ssh to server and wp export db local.sql
        ssh $website_username@$website_ipaddress -p $port_number "cd $source_directory && wp db export local.sql --quiet && gzip -c local.sql > local.sql.gz"
        echo "Fetching Database";
        #rsync the database
        rsync  -e "ssh -i ~/.ssh/id_rsa -q -p $port_number -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no" -arpz --progress $website_username@$website_ipaddress:$source_directory/local.sql.gz $target_directory/local.sql.gz
        echo "Importing remote Database to LocalWP";
        gzip -d local.sql.gz 
        #Import the remote DB to local DB
        if [ "$host_os" == 'Windows' ];
        then
           #On Windows we need the mysql port
            mysql_port=$(grep port $MYSQL_HOME/my.cnf | tail -c6)
            wp db import local.sql --quiet --skip-optimization --port=$mysql_port
        else
            #On Linux/MacOS we need the socket
            wp db import local.sql --quiet --skip-optimization --socket="$mysql_socket"
        fi
        wp search-replace "$remote_domain_url" "$local_domain_url" --quiet
        # Cleaning up from Database fetch
        #delete remote db download file
        ssh $website_username@$website_ipaddress -p $port_number "cd $source_directory && rm local.sql.gz && rm local.sql"
        #delete local db download file
        rm local.sql
    fi
    #Get the remote files
    echo "Downloading Website files..."
    if [ $exclude_uploads ] 
    then 
        rsync  -e "ssh -i ~/.ssh/id_rsa -q -p $port_number -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no" -arpz --exclude --exclude 'wp-config.php' 'wp-content/uploads/*' --progress $website_username@$website_ipaddress:$source_directory $target_directory
    else 
        rsync  -e "ssh -i ~/.ssh/id_rsa -q -p $port_number -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no" -arpz --exclude 'wp-config.php' --progress $website_username@$website_ipaddress:$source_directory $target_directory
    fi
    #if we are on Linux make the certificate is trusted and if the command mkcert exists in the PATH
    if [ -x "$(command -v mkcert)" ] && [ "$host_os" == 'Linux' ];
    then
        local_domain_url_stripped=$(echo ${local_domain_url//https\:\/\//})
        local_domain_url_stripped=$(echo ${local_domain_url_stripped//http\:\/\//})
        mkcert $local_domain_url_stripped  2> /dev/null
        mv $local_domain_url_stripped.pem ~/.config/Local/run/router/nginx/certs/$local_domain_url_stripped.crt
        mv $local_domain_url_stripped-key.pem ~/.config/Local/run/router/nginx/certs/$local_domain_url_stripped.key
    fi
    #ssh to server and wp export db
    #TODO: have a unique id so that mutliple users can download from the same site concurrently
else
    #Default Local development environment
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
    mysqldump --column-statistics=0 --add-drop-database -P 3306 --host=$website_ipaddress --user=$WPDBUSER --password=$WPDBPASS $WPDBNAME 2> /dev/null > ${database_name}_temp_db.sql && \
    mysql --user=$local_db_user --password=$local_db_password --host=localhost -e "\
    CREATE DATABASE IF NOT EXISTS ${database_name}; \
    USE ${database_name}; \
    source ${database_name}_temp_db.sql;" 2> /dev/null \
    && rm ${database_name}_temp_db.sql

    #replace the wp-config password to connect to the database
    sed -i -e "s|${WPDBNAME}|${database_name}|g" ${target_directory}/wp-config.php
    sed -i -e "s|${WPDBUSER}|$local_db_user|g" ${target_directory}/wp-config.php
    sed -i -e "s|${WPDBPASS}|${local_db_password}|g" ${target_directory}/wp-config.php
    fi
fi