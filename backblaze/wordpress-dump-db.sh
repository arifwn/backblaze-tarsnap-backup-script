#!/usr/bin/env bash

source_dir=/home/donnygrover/webapps/
backup_dir=/home/donnygrover/backup/db-autodump/
php=/usr/local/bin/php56
wp_cli=/home/donnygrover/bin/wp

for d in $source_dir*/ ; do
    echo "$d"
    cd $d
    basename=${PWD##*/}
    $php $wp_cli --skip-plugins db export "${backup_dir}${basename}.sql"
done
