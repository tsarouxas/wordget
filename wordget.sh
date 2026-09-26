#!/bin/bash
#------------------
# WordGet - pull a WordPress site (files + database) into a local/target install
# George Tsarouchas
# tsarouxas@hellenictechnologies.com
# Created December 2019
# Install: curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | bash
# ------------------
#Local MySQL credentials used for plain (MAMP/XAMPP/Valet) imports
local_db_user='wp'
local_db_password='wp'
rsync_options='-arpz'
quiet=''
show_instructions(){
    echo "WordGet v1.7.0"
    echo "--------------------------------"
    echo "(C) 2020-2021 Hellenic Technologies"
    echo "https://hellenictechnologies.com"
    echo ""
    echo "Pulls a WordPress website's files and database into your local development environment (pull-only: the source is never modified)"
    echo ""
    echo "USAGE:"
    echo "wordget                (no parameters: interactive setup)"
    echo "wordget -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads"
    echo ""
    echo "REQUIREMENTS:"
    echo "Make sure that your SSH PUBLIC key is installed on the source server."
    echo ""
    echo "MODES (detected automatically on the first SSH connection):"
    echo "  wp-cli mode - wp-cli works on the server: the database is exported with 'wp db export'"
    echo "  sftp mode   - no wp-cli on the server: the database is dumped with mysqldump using the credentials in wp-config.php"
    echo "The local side is detected too: LocalWP (run from 'Open Site Shell'), an existing WordPress site with wp-cli (e.g. VVV), or plain MySQL (MAMP/XAMPP)."
    echo ""
    echo "EXAMPLES:"
    echo "1) Download the whole project into a LocalWP site"
    echo "wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t ~/Sites/electropop/htdocs/ -d local -o exclude-uploads"
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
    echo -e "\t-d [LOCAL DATABASE NAME - also switches on the database download]"
    echo -e "\t-p [OPTIONAL SSH PORT NUMBER]"
    echo -e "\t-o [OPTIONAL, COMMA SEPARATED: exclude-uploads, localmode (no prompt, quiet), localwp / vvv (force local environment)]"
    echo ""
    exit 1
}
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
info(){ [ -n "$quiet" ] || printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# add_slash DIR -> DIR with exactly one trailing /  (rsync copies the folder CONTENTS only with a trailing /)
add_slash(){
    case "$1" in
        */) printf '%s' "$1" ;;
        *)  printf '%s/' "$1" ;;
    esac
}

# ------------------
# Local side detection
#   localwp - running inside LocalWP's "Open Site Shell"
#   wpcli   - target is already a working WordPress site and local wp-cli can reach it (VVV, Valet, ...)
#   plain   - anything else: create/import the DB with the mysql client, point wp-config.php at it
# ------------------
detect_local(){
    local_env=""
    local_domain_url=""
    case "$forced_local_env" in
        localwp|wpcli) local_env="$forced_local_env" ;;
        *)
            if [ -n "$MYSQL_HOME" ] && [[ "$MYSQL_HOME" == *Local* ]]; then
                local_env="localwp"
            elif command -v wp >/dev/null 2>&1 && wp --path="$1" option get siteurl >/dev/null 2>&1; then
                local_env="wpcli"
            else
                local_env="plain"
            fi
            ;;
    esac
    if [ "$local_env" != "plain" ]; then
        local_domain_url=$(wp --path="$1" option get siteurl 2>/dev/null)
    fi
}
local_env_label(){
    case "$local_env" in
        localwp) echo "LocalWP site (${local_domain_url:-url unknown})" ;;
        wpcli)   echo "existing WordPress site, local wp-cli (${local_domain_url:-url unknown})" ;;
        plain)   echo "plain MySQL - MAMP / XAMPP (user: $local_db_user)" ;;
    esac
}

# ------------------
# Interactive setup - runs when wordget is started with no parameters
# ------------------
# ask VAR "Question" "default" [required]
ask(){
    local __var=$1 __q=$2 __def=$3 __req=$4 __ans
    while :; do
        if [ -n "$__def" ]; then
            printf '\033[1;36m?\033[0m \033[1m%s\033[0m \033[2m(%s)\033[0m: ' "$__q" "$__def"
        else
            printf '\033[1;36m?\033[0m \033[1m%s\033[0m: ' "$__q"
        fi
        read -e -r __ans < /dev/tty || { echo ""; exit 1; }
        __ans="${__ans:-$__def}"
        if [ -n "$__ans" ] || [ -z "$__req" ]; then break; fi
        printf '  \033[1;31mThis is required.\033[0m\n'
    done
    printf -v "$__var" '%s' "$__ans"
}
# ask_yn VAR "Question" y|n   -> VAR is 1 for yes, empty for no
ask_yn(){
    local __var=$1 __q=$2 __def=$3 __hint __ans
    if [ "$__def" == "y" ]; then __hint="Y/n"; else __hint="y/N"; fi
    while :; do
        printf '\033[1;36m?\033[0m \033[1m%s\033[0m \033[2m(%s)\033[0m: ' "$__q" "$__hint"
        read -r __ans < /dev/tty || { echo ""; exit 1; }
        __ans="${__ans:-$__def}"
        case "$__ans" in
            [yY]|[yY][eE][sS]) printf -v "$__var" '%s' 1; return ;;
            [nN]|[nN][oO])     printf -v "$__var" '%s' ""; return ;;
        esac
    done
}
run_wizard(){
    local bold='\033[1m' yellow='\033[1;33m' dim='\033[2m' reset='\033[0m' answer
    echo ""
    printf "${yellow}==============================================================${reset}\n"
    printf "${yellow}  WordGet - interactive setup${reset}\n"
    printf "${yellow}==============================================================${reset}\n"
    printf "${yellow}  RUN THIS FROM INSIDE YOUR NEW (TARGET) PROJECT FOLDER${reset}\n"
    printf "${yellow}  The site will be pulled INTO:${reset}\n"
    printf "${bold}      %s${reset}\n" "$PWD"
    printf "${yellow}  WordGet is pull-only: the source site is never modified.${reset}\n"
    printf "${yellow}==============================================================${reset}\n"
    echo ""
    ask_yn answer "Is this the right project folder?" n
    if [ -z "$answer" ]; then
        echo ""
        echo "cd into your target project folder and run wordget again."
        exit 0
    fi

    echo ""
    printf "${dim}Source - the site to copy FROM${reset}\n"
    ask website_ipaddress "Server host or IP address" "" required
    ask website_username  "SSH username" "" required
    while :; do
        ask port_number "SSH port" "22"
        case "$port_number" in ''|*[!0-9]*) printf '  \033[1;31mPort must be a number.\033[0m\n' ;; *) break ;; esac
    done
    ask source_directory "Remote WordPress directory (e.g. /home/user/public_html)" "" required

    echo ""
    printf "${dim}Target - this machine${reset}\n"
    ask target_directory "Local directory" "$PWD"
    #expand a leading ~ typed by the user
    target_directory="${target_directory/#\~/$HOME}"

    detect_local "$target_directory"
    printf "  Local environment detected: ${bold}%s${reset}\n" "$(local_env_label)"

    echo ""
    local want_db
    if [ "$local_env" == "plain" ]; then
        ask_yn want_db "Download and import the database?" n
        if [ -n "$want_db" ]; then
            local db_default
            db_default=$(basename "$target_directory" | tr -c 'A-Za-z0-9_\n' '_')
            ask database_name "Local database name" "$db_default"
        fi
    else
        ask_yn want_db "Download and import the database into this site?" y
        #localwp/wpcli import into the site's own database - the name is only a switch
        if [ -n "$want_db" ]; then database_name="local"; fi
    fi

    local skip_uploads
    ask_yn skip_uploads "Skip the wp-content/uploads folder?" n
    if [ -n "$skip_uploads" ]; then extra_options="exclude-uploads"; fi

    #Show the equivalent one-liner so it can be re-run without the wizard
    local cmd="wordget -h $website_ipaddress -u $website_username -s $(add_slash "$source_directory") -t $(add_slash "$target_directory")"
    [ "$port_number" != "22" ] && cmd="$cmd -p $port_number"
    [ -n "$database_name" ] && cmd="$cmd -d $database_name"
    [ -n "$extra_options" ] && cmd="$cmd -o $extra_options"
    echo ""
    printf "${dim}Next time you can skip the questions with:${reset}\n"
    printf "  %s\n" "$cmd"
}

# ------------------
# Remote side: one SSH connection to detect the mode, then streaming DB dumps
# Nothing is written on the source server.
# ------------------
remote(){
    #remote "script" -> runs the script with bash on the source, $1 = source directory
    #extra arguments are passed to the remote script after the directory
    #keepalives stop long database dumps from being dropped by idle NAT/firewall timeouts
    ssh -p "$port_number" -o ConnectTimeout=15 -o ServerAliveInterval=30 -o ServerAliveCountMax=10 \
        "$website_username@$website_ipaddress" "bash -s -- $source_directory $*"
}
detect_remote(){
    local out rc
    out=$(remote <<'EOF'
cd "$1" 2>/dev/null || { echo "NODIR"; exit 0; }
{ [ -f wp-config.php ] || [ -f ../wp-config.php ]; } && echo "WPCONFIG"
if command -v wp >/dev/null 2>&1 && v=$(wp core version --skip-plugins --skip-themes 2>/dev/null); then
    echo "WPCLI $v"
fi
command -v mysqldump >/dev/null 2>&1 && echo "MYSQLDUMP"
echo "OK"
EOF
)
    rc=$?
    grep -q '^NODIR$' <<< "$out" && die "Remote directory ${source_directory} does not exist on ${website_ipaddress}"
    if [ $rc -ne 0 ] || ! grep -q '^OK$' <<< "$out"; then
        die "Could not connect to ${website_username}@${website_ipaddress} on port ${port_number} over SSH (is your public key installed on the server?)"
    fi
    grep -q '^WPCONFIG$' <<< "$out" || printf '\033[1;33mWARNING:\033[0m no wp-config.php found in %s - is this a WordPress site?\n' "$source_directory"
    remote_has_mysqldump=""
    grep -q '^MYSQLDUMP$' <<< "$out" && remote_has_mysqldump=1
    remote_wp_version=$(sed -n 's/^WPCLI //p' <<< "$out")
    if [ -n "$remote_wp_version" ]; then
        remote_mode="wp-cli"
    else
        remote_mode="sftp"
    fi
}
# dump_remote_db FILE -> gzipped SQL of the source database
dump_remote_db(){
    remote "$remote_mode" > "$1" <<'EOF'
set -o pipefail
cd "$1" || exit 1
mode=$2
cfg=wp-config.php; [ -f "$cfg" ] || cfg=../wp-config.php
#define( 'DB_NAME', 'value' ); in wp-config.php, or DB_NAME=value in a (Bedrock) .env
get(){
    local v
    #value in '...' or "..." - several defines on one line are fine
    v=$(sed -n -e "s/.*define *( *['\"]$1['\"] *, *'\([^']*\)'.*/\1/p" \
               -e "s/.*define *( *['\"]$1['\"] *, *\"\([^\"]*\)\".*/\1/p" "$cfg" 2>/dev/null | head -n1)
    if [ -z "$v" ]; then
        for f in .env ../.env ../../.env; do
            [ -f "$f" ] && v=$(sed -n "s/^$1=['\"]\{0,1\}\([^'\"]*\)['\"]\{0,1\}[[:space:]]*$/\1/p" "$f" | head -n1)
            [ -n "$v" ] && break
        done
    fi
    printf '%s' "$v"
}
#Dump in the charset WordPress itself connects with. Old sites with DB_CHARSET 'latin1'
#holding UTF-8 bytes must be dumped as latin1, or every non-ASCII character gets double-encoded.
charset=""
[ "$mode" = "wp-cli" ] && charset=$(wp config get DB_CHARSET --skip-plugins --skip-themes 2>/dev/null)
[ -n "$charset" ] || charset=$(get DB_CHARSET)
[ -n "$charset" ] || charset=utf8mb4
#--single-transaction: consistent InnoDB snapshot without locking the live site
#--max-allowed-packet: rows bigger than the client default (16-24M) would abort the dump
if [ "$mode" = "wp-cli" ]; then
    #boolean flags as =1 so wp-cli passes them through to mysqldump
    wp db export - --no-tablespaces=1 --single-transaction=1 --quick=1 --max-allowed-packet=1G \
        --default-character-set="$charset" --skip-plugins --skip-themes --quiet | gzip
else
    name=$(get DB_NAME); user=$(get DB_USER); pass=$(get DB_PASSWORD); host=$(get DB_HOST)
    [ -n "$name" ] && [ -n "$user" ] || { echo "Could not read the database credentials from wp-config.php" >&2; exit 2; }
    host=${host:-localhost}
    args=(-u "$user" -h "${host%%:*}")
    case "$host" in
        *:/*) args+=(-S "${host#*:}") ;;
        *:*)  args+=(-P "${host#*:}") ;;
    esac
    MYSQL_PWD="$pass" mysqldump --no-tablespaces --single-transaction --quick --max-allowed-packet=1G \
        --default-character-set="$charset" "${args[@]}" "$name" | gzip
fi
EOF
}

# ------------------
# Parameters
# ------------------
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
      ? ) show_instructions ;;
   esac
done

# Extra options
forced_local_env=""
no_prompt=""
IFS=',' read -r -a array <<< "$extra_options"
for cmd_option in "${array[@]}"
do
    case "$cmd_option" in
        exclude-uploads) exclude_uploads=1 ;;
        localwp)         forced_local_env="localwp" ;;
        vvv)             forced_local_env="wpcli" ;;
        localmode)       no_prompt=1; quiet=1; rsync_options="-qarpz" ;;
    esac
done

#No parameters: interactive setup (only when a terminal is attached)
if [ $# -eq 0 ]
then
    if (: </dev/tty) 2>/dev/null; then run_wizard; else show_instructions; fi
    #the wizard may have set exclude-uploads
    [ "$extra_options" == "exclude-uploads" ] && exclude_uploads=1
fi

#Check if all parameters are given by user
if [ -z "$website_ipaddress" ] || [ -z "$website_username" ] || [ -z "$source_directory" ]
then
   show_instructions
fi

[ -n "$target_directory" ] || target_directory=$(pwd)
[ -n "$port_number" ] || port_number=22
#Always sync directory CONTENTS: ~/public_html -> ~/public_html/
source_directory=$(add_slash "$source_directory")
target_directory=$(add_slash "$target_directory")
mkdir -p "$target_directory" || die "Could not create ${target_directory}"

# What type of OS are we on?
host_uname="$(uname -s)"
case "${host_uname}" in
    Linux*)     host_os=Linux;;
    Darwin*)    host_os=Mac;;
    CYGWIN*)    host_os=Windows;;
    MINGW*)     host_os=Windows;;
    *)          host_os="UNKNOWN:${host_uname}"
esac

# ------------------
# Detect both sides
# ------------------
[ -n "$local_env" ] || detect_local "$target_directory"
info "Connecting to ${website_username}@${website_ipaddress}..."
detect_remote

if [ "$remote_mode" == "wp-cli" ]; then
    mode_label="wp-cli mode (wp-cli found on the server, WordPress ${remote_wp_version})"
else
    mode_label="sftp mode (no wp-cli on the server - files via rsync, database via mysqldump)"
fi
if [ -n "$database_name" ]; then
    if [ "$remote_mode" == "sftp" ] && [ -z "$remote_has_mysqldump" ]; then
        die "No wp-cli and no mysqldump on the server - cannot download the database. Run again without -d to download files only."
    fi
    if [ "$local_env" == "plain" ]; then
        command -v mysql >/dev/null 2>&1 || die "The mysql client is needed locally to import the database."
    fi
fi

# ------------------
# Summary + confirmation
# ------------------
if [ -z "$quiet" ]; then
    echo ""
    printf '\033[1mMode:\033[0m   %s\n' "$mode_label"
    printf '\033[1mLocal:\033[0m  %s\n' "$(local_env_label)"
    echo ""
    echo "From: ${website_username}@${website_ipaddress}:${source_directory} (port ${port_number})"
    echo "Into: ${target_directory}"
    [ -n "$exclude_uploads" ] && echo "The uploads/ folder will not be downloaded."
    if [ -n "$database_name" ]; then
        if [ "$local_env" == "plain" ]; then
            echo "The remote database will be downloaded and imported into your local database: $database_name."
        else
            echo "The remote database will be downloaded and REPLACE this site's local database."
        fi
    else
        echo "The remote database will not be downloaded."
    fi
fi
if [ -z "$no_prompt" ]; then
    echo ""
    read -r -p "Are you sure you want to continue? <y/N> " prompt
    if [[ $prompt != "y" && $prompt != "Y" && $prompt != "yes" && $prompt != "Yes" ]]
    then
        exit 0
    fi
fi

# ------------------
# Files
# ------------------
info "Downloading website files..."
rsync_excludes=(--exclude 'wp-content/cache/*')
[ -n "$exclude_uploads" ] && rsync_excludes+=(--exclude 'wp-content/uploads/*')
#an existing local site keeps its own wp-config.php; plain imports take the remote one and repoint it
[ "$local_env" != "plain" ] && rsync_excludes+=(--exclude 'wp-config.php')
rsync -e "ssh -i ~/.ssh/id_rsa -q -p $port_number -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no" \
    $rsync_options --progress "${rsync_excludes[@]}" \
    "$website_username@$website_ipaddress:$source_directory" "$target_directory" \
    || die "File download failed"

# ------------------
# Database
# ------------------
#how wp db commands reach LocalWP's MySQL: port on Windows, socket on Linux/macOS
wp_db_conn=()
if [ "$local_env" == "localwp" ]; then
    if [ "$host_os" == 'Windows' ]; then
        wp_db_conn=(--port="$(grep port "$MYSQL_HOME/my.cnf" | tail -c6)")
    else
        wp_db_conn=(--socket="${MYSQL_HOME//conf\//}/mysqld.sock")
    fi
fi
lwp(){ wp --path="$target_directory" "$@"; }

if [ -n "$database_name" ]; then
    info "Downloading database ($remote_mode mode)..."
    db_dump=$(mktemp "${TMPDIR:-/tmp}/wordget-db.XXXXXX")
    trap 'rm -f "$db_dump"' EXIT
    dump_remote_db "$db_dump" || die "Database download failed"
    gzip -t "$db_dump" 2>/dev/null && [ -s "$db_dump" ] || die "Database download is empty or corrupt"

    if [ "$local_env" == "plain" ]; then
        info "Importing into local database $database_name"
        mysql --user=$local_db_user --password=$local_db_password --host=localhost \
            -e "CREATE DATABASE IF NOT EXISTS \`${database_name}\`;" \
            && gunzip -c "$db_dump" | mysql --max-allowed-packet=1G --user=$local_db_user --password=$local_db_password --host=localhost "$database_name" \
            || die "Database import failed"
        #point wp-config.php at the local database (portable: no sed -i)
        wpconfig="${target_directory}wp-config.php"
        if [ -f "$wpconfig" ]; then
            set_define(){ sed "s/\(define *( *['\"]$1['\"] *, *\)['\"].*['\"]\( *)\)/\1'$2'\2/"; }
            set_define DB_NAME "$database_name" < "$wpconfig" \
                | set_define DB_USER "$local_db_user" \
                | set_define DB_PASSWORD "$local_db_password" \
                | set_define DB_HOST "localhost" > "$wpconfig.wordget" \
                && cat "$wpconfig.wordget" > "$wpconfig" && rm -f "$wpconfig.wordget"
        else
            printf '\033[1;33mWARNING:\033[0m no wp-config.php in %s - point your config at database %s yourself\n' "$target_directory" "$database_name"
        fi
    else
        info "Importing into the local site's database"
        gunzip -c "$db_dump" | lwp db import - --quiet --force --skip-optimization --max-allowed-packet=1G "${wp_db_conn[@]}" \
            || die "Database import failed"
        #the imported options table still holds the source URL
        remote_domain_url=$(lwp db query "SELECT option_value FROM $(lwp db prefix)options WHERE option_name='siteurl'" --skip-column-names "${wp_db_conn[@]}" 2>/dev/null | tail -n1)
        if [ -n "$remote_domain_url" ] && [ -n "$local_domain_url" ] && [ "$remote_domain_url" != "$local_domain_url" ]; then
            info "Replacing $remote_domain_url with $local_domain_url"
            lwp search-replace "$remote_domain_url" "$local_domain_url" --quiet
        else
            printf '\033[1;33mWARNING:\033[0m could not determine the URLs - skipped search-replace (source: %s, local: %s)\n' "${remote_domain_url:-?}" "${local_domain_url:-?}"
        fi
    fi
fi

# ------------------
# Finalize (sites with local wp-cli)
# ------------------
if [ "$local_env" != "plain" ]; then
    #LocalWP on Linux: make Chrome trust the local certificate if mkcert is installed
    if [ "$local_env" == "localwp" ] && [ -x "$(command -v mkcert)" ] && [ "$host_os" == 'Linux' ]; then
        local_domain_url_stripped=$(echo ${local_domain_url//https\:\/\//})
        local_domain_url_stripped=$(echo ${local_domain_url_stripped//http\:\/\//})
        mkcert $local_domain_url_stripped  2> /dev/null
        mv $local_domain_url_stripped.pem ~/.config/Local/run/router/nginx/certs/$local_domain_url_stripped.crt
        mv $local_domain_url_stripped-key.pem ~/.config/Local/run/router/nginx/certs/$local_domain_url_stripped.key
    fi
    #tidy up the local site after download
    lwp cache flush && lwp rewrite flush && lwp transient delete --all && lwp db optimize "${wp_db_conn[@]}"
fi
info "Done."
