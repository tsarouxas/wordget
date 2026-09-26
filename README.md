<h1 align="center">WordGet</h1>

<p align="center">
  <strong>Pull a live WordPress site &mdash; files and database &mdash; into a local staging replica with one command.</strong>
</p>

<p align="center">
  <img alt="Linux | macOS" src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS-555">
  <img alt="Bash 3.2+" src="https://img.shields.io/badge/bash-3.2%2B-4EAA25?logo=gnubash&logoColor=white">
  <img alt="Pull-only" src="https://img.shields.io/badge/source-read--only-0a7">
</p>

For LocalWP, MAMP / XAMPP, Valet, VVV or a plain server. WordGet detects wp-cli on the source and your local setup, streams the database over SSH, fixes the URLs and `wp-config.php` for the local copy, and never touches the source site.

```bash
curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | bash
cd ~/Sites/my-site && wordget
```

<sub>&copy; 202[0-6] <a href="https://hellenictechnologies.com/">Hellenic Technologies</a> &middot; <a href="mailto:tsarouxas@hellenictechnologies.com">tsarouxas@hellenictechnologies.com</a></sub>

---

HOW IT WORKS - PULL ONLY:

WordGet is a pull-only tool. It never deploys, pushes or syncs anything back to the source site.

1. Set up a new, empty WordPress project where you want the copy: on your machine (LocalWP, VVV, MAMP/XAMPP) or on another server.
2. Run wordget from that target. It connects to the source over SSH and fetches the files (rsync) and, if you ask for it with -d, the database.
3. Everything WordGet changes is on the target side: the downloaded files, the local database import, URL search-replace, and the local wp-config.php.

The source site is treated as read-only: no files are uploaded to it, and its files and database are never modified.
The database dump is streamed straight over SSH, so nothing is written on the source server either.

Direction is always SOURCE (-h/-u/-s) --> TARGET (-t / current folder). To go the other way, use a deployment tool, not WordGet.

INSTALLATION (Linux & macOS):

```bash
curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | bash
```

Installs wordget into ~/.local/bin for the current user (no sudo). If that folder isn't in your PATH, the installer prints the line to add to ~/.zshrc or ~/.bashrc.
Run the same command again to upgrade.

Options (environment variables):
- `WORDGET_INSTALL_DIR=~/bin` install somewhere else
- `WORDGET_REF=localwp` install from another branch or tag

e.g.
```bash
curl -fsSL https://raw.githubusercontent.com/tsarouxas/wordget/master/install.sh | WORDGET_INSTALL_DIR=~/bin bash
```

USAGE: 

Interactive setup - cd into your new (target) project folder and run wordget with no parameters:

```bash
cd ~/Sites/mysite/htdocs
wordget
```

It asks for the server, SSH user, port (default 22), remote and local directories, database and uploads, then prints the equivalent one-line command so you can skip the questions next time.
A trailing / is added to both directories automatically (~/public_html becomes ~/public_html/), so the folder's contents are copied, not the folder itself.

Or pass everything as parameters:

wordget -h website_ipaddress -u website_username -s source_directory -t target_directory -d local_database_name -o exclude-uploads

MODES (detected automatically - nothing to choose):

On the first SSH connection WordGet checks the source server and tells you which mode it picked:
- wp-cli mode: wp-cli works on the server. The database is exported with `wp db export`.
- sftp mode: no wp-cli on the server. Files still come over rsync/SSH; the database is dumped with `mysqldump`, using the credentials in the remote wp-config.php (or a Bedrock .env).

The local side is detected too:
- LocalWP: when run from LocalWP's "Open Site Shell". Imports into the LocalWP site's database and replaces the URLs.
- Existing WordPress site: the target already runs WordPress and local wp-cli works there (VVV, Valet, ...). Same as LocalWP.
- Plain MySQL (MAMP/XAMPP/Homebrew): creates the database given with -d and points wp-config.php at it.
  The local MySQL login is checked before anything is downloaded: saved settings for this site first, then the login in an existing local wp-config.php (only if it really works). Otherwise WordGet asks for user, password and host (host, host:port or host:/socket).

LOCAL URL, WP-CONFIG.PHP AND SEARCH-REPLACE:

WordGet builds a local staging replica of the source site:
- It always asks for the full local URL, with http:// or https:// (e.g. http://spentzos-gr.test).
- rsync never overwrites your local wp-config.php. Instead the source wp-config.php is fetched and merged: everything comes from the source (constants, $table_prefix, ...) except
  - DB_NAME / DB_USER / DB_PASSWORD / DB_HOST: the local login (an existing local install keeps its own; plain MySQL uses the login you entered and the -d database)
  - WP_HOME / WP_SITEURL: the local URL (any path such as /wp is kept)
  - WP_CACHE_KEY_SALT: the source host inside it is replaced with the local host
  The previous local wp-config.php is kept as wp-config.php.wordget-backup.
- With -d it asks whether to search-replace the source URL in the LOCAL database (the source is never touched). It collects every source URL - the home/siteurl options in the imported database and WP_HOME/WP_SITEURL in the source wp-config.php - and runs `wp search-replace --all-tables-with-prefix` for https:// and http:// of each, plus the JSON-escaped https:\/\/ form used by Elementor/blocks, always to the exact local URL (so https:// on the source becomes your local scheme). Then `wp cache flush`.
- Local wp-cli is needed for the search-replace (it is serialization-safe); without it WordGet prints the commands to run later.

SAVED SETTINGS:

After the wizard, or when you typed in a MySQL login, WordGet asks whether to save the settings for this project folder in ~/.config/wordget/<folder-name> (file mode 600, folder 700 - readable only by you). Next time you run `wordget` in that folder it shows them and asks "Use these settings?", so you skip the questions.
The file contains the server/user/path (no server secrets - SSH uses your key) and, for plain MySQL imports, your LOCAL MySQL password in plain text, like ~/.my.cnf. Don't use it for production database passwords. Delete the file to forget a site.

For existing sites, wp-config.php is never overwritten. Force the local side with -o localwp or -o vvv if detection gets it wrong. -o localmode runs without the confirmation prompt and without output.

EXAMPLES: 
1) Download the whole project into a LocalWP site (run from "Open Site Shell" inside LocalWP)
wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t ~/Sites/electropop/htdocs/ -d local -o exclude-uploads
    
2) Download files only without the database or the uploads folder
wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -t /Users/george/Sites/electropop/htdocs/ -o exclude-uploads

3) Download all files and database in current folder
wordget -h 88.99.242.152 -u electropop -s /home/electropop/dev.electropop.gr/ -d mylocaldbname

REQUIREMENTS:
- Your SSH public key installed on the source server. ssh and rsync locally.
- Database downloads: wp-cli OR mysqldump on the source server.
- Database imports: local wp-cli (LocalWP / existing sites) or the mysql client (plain MySQL).
- Windows users MUST always run Wordget from a GIT BASH shell


CHANGELOG:
- 2026-09-26 v1.8.0 local MySQL login (from saved settings, the local wp-config.php, or asked); saved per-site settings in ~/.config/wordget; always asks for the full local URL; source wp-config.php merged into the local one (local DB login, WP_HOME/WP_SITEURL, WP_CACHE_KEY_SALT) with a backup; URL search-replace in the local database; wp cache flush
- 2026-09-26 v1.7.0 wp-cli / sftp mode and local environment detected automatically; database streamed over SSH (nothing written on the source); charset from DB_CHARSET, max-allowed-packet 1G, single-transaction; interactive setup when run without parameters; curl | bash installer
- 2020-07-26 direct integration with LocalWP - using option localwp
- 2020-06-29 fixed mysqldump downloading of remote database

