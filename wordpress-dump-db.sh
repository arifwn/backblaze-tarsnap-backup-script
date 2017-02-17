#!/usr/bin/env bash

source_dir=$HOME/webapps/
backup_dir=$HOME/backup/db-autodump/
php=/usr/local/bin/php56
wp_cli=$HOME/bin/wp

for d in $source_dir*/ ; do
    echo "$d"
    cd $d
    basename=${PWD##*/}
    $php $wp_cli --skip-plugins db export "${backup_dir}${basename}.sql"
done
