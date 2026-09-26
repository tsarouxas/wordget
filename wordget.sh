#!/bin/bash
#------------------
# WordGet - pull a WordPress site (files + database) into a local/target install
# George Tsarouchas
# tsarouxas@hellenictechnologies.com
# Created December 2019
# Install: curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | bash
# ------------------
#Local MySQL login for plain (MAMP/XAMPP/Homebrew) imports - read from the local wp-config.php or asked for
local_db_user=''
local_db_password=''
local_db_host='localhost'
#Saved per-site settings (only with the user's consent): one file per target folder, mode 600
site_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wordget"
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
        plain)   echo "plain MySQL - MAMP / XAMPP / Homebrew" ;;
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
    echo "HOME $(wp option get home --skip-plugins --skip-themes 2>/dev/null)"
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
    remote_site_url=$(sed -n 's/^HOME //p' <<< "$out")
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
# Local MySQL login (plain mode)
# ------------------
# lmysql ARGS... -> mysql client with the local login; host may be host, host:port or host:/socket (like DB_HOST)
lmysql(){
    local conn=(--user="$local_db_user" --host="${local_db_host%%:*}")
    case "$local_db_host" in
        *:/*) conn+=(--socket="${local_db_host#*:}") ;;
        *:*)  conn+=(--protocol=TCP --port="${local_db_host#*:}") ;;
    esac
    #password via the environment: not visible in ps, no "insecure password" warning
    MYSQL_PWD="$local_db_password" mysql "${conn[@]}" "$@"
}
try_local_login(){
    local_db_user=$1; local_db_password=$2; local_db_host=$3
    lmysql -e 'SELECT 1' </dev/null >/dev/null 2>&1
}
find_local_login(){
    login_asked=""
    #1) saved settings for this site
    if [ -f "$site_config" ] && [ -n "$(saved_value "$site_config" local_db_user)" ]; then
        try_local_login "$(saved_value "$site_config" local_db_user)" \
                        "$(saved_value "$site_config" local_db_password)" \
                        "$(saved_value "$site_config" local_db_host)" \
            && { login_source="saved settings"; return 0; }
        printf '\033[1;33mWARNING:\033[0m the saved local MySQL login no longer works\n'
    fi
    #2) an existing local wp-config.php - only if the login really works
    local wpc="${target_directory}wp-config.php" u p h
    if [ -f "$wpc" ]; then
        if command -v wp >/dev/null 2>&1; then
            u=$(wp --path="$target_directory" config get DB_USER 2>/dev/null)
            p=$(wp --path="$target_directory" config get DB_PASSWORD 2>/dev/null)
            h=$(wp --path="$target_directory" config get DB_HOST 2>/dev/null)
        fi
        if [ -z "$u" ]; then
            u=$(config_value "$wpc" DB_USER); p=$(config_value "$wpc" DB_PASSWORD); h=$(config_value "$wpc" DB_HOST)
        fi
        if [ -n "$u" ] && try_local_login "$u" "$p" "${h:-localhost}"; then
            login_source="local wp-config.php"; return 0
        fi
    fi
    #3) ask
    (: </dev/tty) 2>/dev/null || die "No working local MySQL login. Run wordget in a terminal to enter it (and save it for this site)."
    echo ""
    printf '\033[1mLocal MySQL login\033[0m - needed to import the database \033[2m(MAMP: root/root, Homebrew/DBngin: root with no password)\033[0m\n'
    local user password host error
    while :; do
        ask user "Local MySQL user" "root"
        printf '\033[1;36m?\033[0m \033[1mLocal MySQL password\033[0m \033[2m(hidden, empty for none)\033[0m: '
        read -r -s password < /dev/tty || { echo ""; exit 1; }
        echo ""
        ask host "Local MySQL host (host, host:port or host:/path/to/socket)" "localhost"
        try_local_login "$user" "$password" "$host" && break
        error=$(lmysql -e 'SELECT 1' 2>&1 </dev/null >/dev/null | tail -n1)
        printf '  \033[1;31m%s\033[0m\n' "${error:-Login failed}"
    done
    login_source="entered"
    login_asked=1
}
# config_value FILE NAME -> value of define('NAME', '...') in a local wp-config.php
config_value(){
    sed -n -e "s/.*define *( *['\"]$2['\"] *, *'\([^']*\)'.*/\1/p" \
           -e "s/.*define *( *['\"]$2['\"] *, *\"\([^\"]*\)\".*/\1/p" "$1" 2>/dev/null | head -n1
}

# ------------------
# Saved per-site settings
# ------------------
saved_fields="website_ipaddress website_username port_number source_directory target_directory database_name extra_options local_db_user local_db_password local_db_host local_url search_replace"
# saved_value FILE VAR -> value of VAR in a saved settings file (read in a subshell)
saved_value(){
    ( unset $saved_fields; . "$1" >/dev/null 2>&1; printf '%s' "${!2}" )
}
# site_config_file DIR -> settings file for that target folder: ~/.config/wordget/<folder-name>
# (a second folder with the same name gets a checksum suffix)
site_config_file(){
    local dir name f
    dir=$(add_slash "$1")
    name=$(basename "$dir" | tr -c 'A-Za-z0-9._\n-' '_')
    f="$site_config_dir/$name"
    if [ -f "$f" ] && [ "$(saved_value "$f" target_directory)" != "$dir" ]; then
        f="$f-$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
    fi
    printf '%s' "$f"
}
# sq VALUE -> VALUE in single quotes, safe to source back (no ~ or $ expansion)
sq(){ printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
save_site_config(){
    local extra=""
    [ -n "$exclude_uploads" ] && extra="exclude-uploads"
    ( umask 077
      mkdir -p "$site_config_dir" && chmod 700 "$site_config_dir" || exit 1
      {
        echo "# WordGet saved settings for ${target_directory} - written $(date '+%Y-%m-%d %H:%M')"
        echo "website_ipaddress=$(sq "$website_ipaddress")"
        echo "website_username=$(sq "$website_username")"
        echo "port_number=$(sq "$port_number")"
        echo "source_directory=$(sq "$source_directory")"
        echo "target_directory=$(sq "$target_directory")"
        echo "database_name=$(sq "$database_name")"
        echo "extra_options=$(sq "$extra")"
        echo "local_url=$(sq "$local_url")"
        [ -n "$database_name" ] && echo "search_replace=$(sq "$search_replace")"
        if [ "$local_env" == "plain" ] && [ -n "$database_name" ]; then
            echo "local_db_user=$(sq "$local_db_user")"
            echo "local_db_password=$(sq "$local_db_password")"
            echo "local_db_host=$(sq "$local_db_host")"
        fi
      } > "$site_config" && chmod 600 "$site_config"
    ) && info "Saved to $site_config" || printf '\033[1;33mWARNING:\033[0m could not save %s\n' "$site_config"
}

# ------------------
# wp-config.php and URL helpers
# ------------------
# set_define NAME VALUE < wp-config.php -> wp-config.php with define('NAME', 'VALUE')
set_define(){
    #escape for a PHP '...' string, then for the sed replacement
    local v
    v=$(printf '%s' "$2" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g" | sed -e 's/[\\/&]/\\&/g')
    sed "s/\(define *( *['\"]$1['\"] *, *\)['\"].*['\"]\( *)\)/\1'$v'\2/"
}
# url_origin URL -> scheme://host[:port]
url_origin(){ printf '%s' "$1" | sed -n 's#^\(https\{0,1\}://[^/]*\).*#\1#p'; }
# ask_local_url: the local site URL (always with http:// or https://) and whether to search-replace the DB
ask_local_url(){
    local saved_sr="" saved_url="" interactive=""
    if [ -f "$site_config" ]; then
        saved_sr=$(saved_value "$site_config" search_replace)
        saved_url=$(saved_value "$site_config" local_url)
    fi
    [ -z "$no_prompt" ] && (: </dev/tty) 2>/dev/null && interactive=1
    if [ -n "$saved_url" ]; then
        local_url="$saved_url"
    elif [ -n "$interactive" ]; then
        local guess="$local_domain_url"
        [ -n "$guess" ] || guess="http://$(basename "${target_directory%/}" | tr 'A-Z' 'a-z').test"
        echo ""
        while :; do
            ask local_url "Local site URL - full, with http:// or https://" "$guess"
            local_url="${local_url%/}"
            case "$local_url" in
                http://?*|https://?*) break ;;
                *) printf '  \033[1;31mStart with http:// or https:// (e.g. %s)\033[0m\n' "$guess" ;;
            esac
        done
        url_asked=1
    else
        #unattended: only what we know for sure
        local_url="${local_domain_url%/}"
    fi
    search_replace=no
    if [ -n "$database_name" ] && [ -n "$local_url" ]; then
        if [ -n "$saved_sr" ]; then
            search_replace="$saved_sr"
        elif [ -n "$interactive" ]; then
            local answer
            ask_yn answer "After the import, search-replace the source URL with $local_url in the local database?" y
            if [ -n "$answer" ]; then search_replace=yes; fi
            url_asked=1
        else
            search_replace=yes
        fi
    fi
}
# local_db_creds: DB_NAME/USER/PASSWORD/HOST the local wp-config.php must keep
local_db_creds(){
    cfg_db_name=""; cfg_db_user=""; cfg_db_password=""; cfg_db_host=""
    local wpc="${target_directory}wp-config.php"
    if [ "$local_env" == "plain" ] && [ -n "$database_name" ]; then
        cfg_db_name="$database_name"; cfg_db_user="$local_db_user"; cfg_db_password="$local_db_password"; cfg_db_host="$local_db_host"
    elif [ -f "$wpc" ]; then
        #the existing local install's own login
        if command -v wp >/dev/null 2>&1; then
            cfg_db_name=$(wp --path="$target_directory" config get DB_NAME 2>/dev/null)
            cfg_db_user=$(wp --path="$target_directory" config get DB_USER 2>/dev/null)
            cfg_db_password=$(wp --path="$target_directory" config get DB_PASSWORD 2>/dev/null)
            cfg_db_host=$(wp --path="$target_directory" config get DB_HOST 2>/dev/null)
        fi
        if [ -z "$cfg_db_user" ]; then
            cfg_db_name=$(config_value "$wpc" DB_NAME); cfg_db_user=$(config_value "$wpc" DB_USER)
            cfg_db_password=$(config_value "$wpc" DB_PASSWORD); cfg_db_host=$(config_value "$wpc" DB_HOST)
        fi
    fi
}
# fetch_source_config FILE -> the source site's wp-config.php
fetch_source_config(){
    remote > "$1" <<'EOF'
cd "$1" || exit 1
if [ -f wp-config.php ]; then cat wp-config.php; elif [ -f ../wp-config.php ]; then cat ../wp-config.php; else exit 3; fi
EOF
}
# url_host URL -> host[:port]
url_host(){ local o; o=$(url_origin "$1"); printf '%s' "${o#*://}"; }
# merge_wp_config: source wp-config.php, with the local DB login, local URLs and cache salt
merge_wp_config(){
    local src wpc="${target_directory}wp-config.php" tmp="${target_directory}wp-config.php.wordget"
    src=$(mktemp "${TMPDIR:-/tmp}/wordget-cfg.XXXXXX")
    if ! fetch_source_config "$src" || [ ! -s "$src" ]; then
        rm -f "$src"
        printf '\033[1;33mWARNING:\033[0m no wp-config.php on the source - local wp-config.php left as it is\n'
        return 0
    fi
    src_home=$(config_value "$src" WP_HOME)
    src_siteurl=$(config_value "$src" WP_SITEURL)
    local salt new_salt local_host h
    salt=$(config_value "$src" WP_CACHE_KEY_SALT)
    local_host=$(url_host "$local_url")
    if [ -n "$salt" ] && [ -n "$local_host" ]; then
        new_salt="$salt"
        for h in $(url_host "$src_home") $(url_host "$src_siteurl") $(url_host "$remote_site_url"); do
            new_salt="${new_salt//$h/$local_host}"
        done
        #no source host inside it: just use the local host
        [ "$new_salt" == "$salt" ] && new_salt="$local_host"
    fi
    [ -z "$cfg_db_user" ] && printf '\033[1;33mWARNING:\033[0m no local database login known - wp-config.php keeps the source DB_* settings\n'
    #each step only touches a define that exists in the source file
    step(){ if [ -n "$2" ]; then set_define "$1" "$2"; else cat; fi; }
    step DB_NAME "$cfg_db_name" < "$src" \
        | step DB_USER "$cfg_db_user" \
        | { if [ -n "$cfg_db_user" ]; then set_define DB_PASSWORD "$cfg_db_password"; else cat; fi; } \
        | step DB_HOST "$cfg_db_host" \
        | step WP_HOME "${src_home:+$local_url${src_home#$(url_origin "$src_home")}}" \
        | step WP_SITEURL "${src_siteurl:+$local_url${src_siteurl#$(url_origin "$src_siteurl")}}" \
        | step WP_CACHE_KEY_SALT "$new_salt" > "$tmp" || { rm -f "$src" "$tmp"; die "Could not write wp-config.php"; }
    rm -f "$src"
    #keep the previous local config once, if it was different
    if [ -f "$wpc" ] && ! cmp -s "$wpc" "$tmp"; then
        cp -p "$wpc" "${wpc}.wordget-backup"
        info "Previous local wp-config.php saved as wp-config.php.wordget-backup"
    fi
    if [ -f "$wpc" ]; then cat "$tmp" > "$wpc"; rm -f "$tmp"; else mv "$tmp" "$wpc"; fi
    info "wp-config.php from the source${cfg_db_user:+, with the local database login}${local_url:+, URLs -> $local_url}${new_salt:+, WP_CACHE_KEY_SALT -> $new_salt}"
}
# replace_urls: after the import - source URL(s) -> $local_url in the LOCAL database only
replace_urls(){
    local wpconfig="${target_directory}wp-config.php" prefix db_home db_siteurl
    if [ "$local_env" == "plain" ]; then
        prefix=$(sed -n "s/^[[:space:]]*\$table_prefix[[:space:]]*=[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "$wpconfig" 2>/dev/null | head -n1)
        prefix=${prefix:-wp_}
        db_home=$(lmysql -N -e "SELECT option_value FROM \`${prefix}options\` WHERE option_name='home'" "$database_name" 2>/dev/null </dev/null)
        db_siteurl=$(lmysql -N -e "SELECT option_value FROM \`${prefix}options\` WHERE option_name='siteurl'" "$database_name" 2>/dev/null </dev/null)
    else
        prefix=$(lwp db prefix 2>/dev/null)
        db_home=$(lwp db query "SELECT option_value FROM ${prefix}options WHERE option_name='home'" --skip-column-names "${wp_db_conn[@]}" 2>/dev/null | tail -n1)
        db_siteurl=$(lwp db query "SELECT option_value FROM ${prefix}options WHERE option_name='siteurl'" --skip-column-names "${wp_db_conn[@]}" 2>/dev/null | tail -n1)
    fi
    #distinct source origins (DB options and the source wp-config constants can differ, e.g. a dev copy of a live DB)
    local origins="" v o
    for v in "$db_home" "$db_siteurl" "$src_home" "$src_siteurl"; do
        o=$(url_origin "$v")
        [ -n "$o" ] && [ "$o" != "$local_url" ] || continue
        case " $origins " in *" $o "*) ;; *) origins="$origins $o" ;; esac
    done
    if [ -z "$origins" ]; then
        info "Database URLs already match $local_url - nothing to replace"
        return 0
    fi
    if ! command -v wp >/dev/null 2>&1; then
        printf '\033[1;33mWARNING:\033[0m local wp-cli not found - search-replace skipped (it must be serialization-safe). Run later:\n'
        for o in $origins; do printf '  wp --path=%s search-replace %s %s --all-tables-with-prefix\n' "$target_directory" "$o" "$local_url"; done
        return 0
    fi
    local host from f to count esc_to pair
    esc_to=$(printf '%s' "$local_url" | sed 's#/#\\/#g')
    for o in $origins; do
        host=${o#*://}
        for from in "https://$host" "http://$host"; do
            [ "$from" == "$local_url" ] && continue
            #never replace a prefix of the target itself (https://site.gr -> http://site.gr.test would repeat)
            case "$local_url" in "$from"*) continue ;; esac
            for pair in plain escaped; do
                if [ "$pair" == "plain" ]; then to="$local_url"; f="$from"
                else f=$(printf '%s' "$from" | sed 's#/#\\/#g'); to="$esc_to"; fi
                count=$(lwp search-replace "$f" "$to" --all-tables-with-prefix --skip-plugins --skip-themes --format=count 2>/dev/null)
                case "$count" in ''|0) ;; *) info "Replaced $count x $f -> $to" ;; esac
            done
        done
    done
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
    (: </dev/tty) 2>/dev/null || show_instructions
    site_config=$(site_config_file "$PWD")
    use_saved=""
    if [ -f "$site_config" ]; then
        echo ""
        printf '\033[1mSaved settings for this folder\033[0m \033[2m(%s)\033[0m\n' "$site_config"
        printf '  From: %s@%s:%s (port %s)\n' "$(saved_value "$site_config" website_username)" "$(saved_value "$site_config" website_ipaddress)" \
            "$(saved_value "$site_config" source_directory)" "$(saved_value "$site_config" port_number)"
        printf '  Into: %s\n' "$(saved_value "$site_config" target_directory)"
        [ -n "$(saved_value "$site_config" database_name)" ] && printf '  Database: %s\n' "$(saved_value "$site_config" database_name)"
        [ -n "$(saved_value "$site_config" extra_options)" ] && printf '  Options: %s\n' "$(saved_value "$site_config" extra_options)"
        echo ""
        ask_yn use_saved "Use these settings?" y
    fi
    if [ -n "$use_saved" ]; then
        . "$site_config"
        used_saved_settings=1
    else
        run_wizard
        from_wizard=1
    fi
    #the wizard / saved settings may have set exclude-uploads
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
site_config=$(site_config_file "$target_directory")

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
        find_local_login
    fi
fi

ask_local_url

#Offer to save what was typed in (wizard answers, a MySQL login or URL answers entered by hand)
if [ -z "$no_prompt" ] && { [ -n "$from_wizard" ] || [ -n "$login_asked" ] || [ -n "$url_asked" ]; } && (: </dev/tty) 2>/dev/null; then
    echo ""
    if [ "$local_env" == "plain" ] && [ -n "$database_name" ] && [ -n "$local_db_password" ]; then
        save_note="readable only by you - includes your LOCAL MySQL password in plain text"
    else
        save_note="readable only by you"
    fi
    ask_yn save_it "Save these settings so next time you don't have to answer again? (${site_config}, ${save_note})" y
    [ -n "$save_it" ] && save_site_config
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
    echo "wp-config.php: taken from the source (the local one is backed up), with the local database login${local_url:+ and URLs set to $local_url}."
    if [ -n "$database_name" ]; then
        if [ "$local_env" == "plain" ]; then
            echo "The remote database will be downloaded and imported into your local database: $database_name (as ${local_db_user}@${local_db_host}, login from ${login_source})."
        else
            echo "The remote database will be downloaded and REPLACE this site's local database."
        fi
        if [ "$search_replace" == "yes" ]; then
            echo "Source site URLs will be replaced with ${local_url} in the local database."
        else
            echo "No URL search-replace in the database."
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
# Files - wp-config.php is never overwritten by rsync; it is merged below
# ------------------
local_db_creds
info "Downloading website files..."
rsync_excludes=(--exclude 'wp-content/cache/*' --exclude 'wp-config.php' --exclude 'wp-config.php.wordget*')
[ -n "$exclude_uploads" ] && rsync_excludes+=(--exclude 'wp-content/uploads/*')
rsync -e "ssh -i ~/.ssh/id_rsa -q -p $port_number -o PasswordAuthentication=no -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no" \
    $rsync_options --progress "${rsync_excludes[@]}" \
    "$website_username@$website_ipaddress:$source_directory" "$target_directory" \
    || die "File download failed"
merge_wp_config

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
        lmysql -e "CREATE DATABASE IF NOT EXISTS \`${database_name}\`;" </dev/null \
            && gunzip -c "$db_dump" | lmysql --max-allowed-packet=1G "$database_name" \
            || die "Database import failed"
    else
        info "Importing into the local site's database"
        gunzip -c "$db_dump" | lwp db import - --quiet --force --skip-optimization --max-allowed-packet=1G "${wp_db_conn[@]}" \
            || die "Database import failed"
    fi
    [ "$search_replace" == "yes" ] && replace_urls
fi

# ------------------
# Finalize
# ------------------
#LocalWP on Linux: make Chrome trust the local certificate if mkcert is installed
if [ "$local_env" == "localwp" ] && [ -x "$(command -v mkcert)" ] && [ "$host_os" == 'Linux' ]; then
    local_domain_url_stripped=$(echo ${local_domain_url//https\:\/\//})
    local_domain_url_stripped=$(echo ${local_domain_url_stripped//http\:\/\//})
    mkcert $local_domain_url_stripped  2> /dev/null
    mv $local_domain_url_stripped.pem ~/.config/Local/run/router/nginx/certs/$local_domain_url_stripped.crt
    mv $local_domain_url_stripped-key.pem ~/.config/Local/run/router/nginx/certs/$local_domain_url_stripped.key
fi
if command -v wp >/dev/null 2>&1 && [ -n "$database_name" ]; then
    info "Flushing caches"
    lwp cache flush --skip-plugins --skip-themes >/dev/null 2>&1 || printf '\033[1;33mWARNING:\033[0m wp cache flush failed\n'
    if [ "$local_env" != "plain" ]; then
        lwp rewrite flush >/dev/null 2>&1; lwp transient delete --all >/dev/null 2>&1; lwp db optimize "${wp_db_conn[@]}" >/dev/null 2>&1
    fi
fi
info "Done."
