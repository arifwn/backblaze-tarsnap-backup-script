#!/usr/bin/env bash

system_name="test-backup"
bucket_name="gwd-backup-test-backup"
mail_recipient="arif@sainsmograf.com"

last_dir=`pwd`
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source_dir=$script_dir/tests/test-backup-dirs/source/ # webfaction: $HOME/webapps/
source_db_dir=$script_dir/tests/test-backup-dirs/source-db/  # webfaction: $HOME/backup/db-autodump/
backup_dir=$script_dir/tests/test-backup-dirs/backups/ # webfaction: $HOME/backup/tarballs/

# activate virtualenv
virtual_env_dir=$script_dir/.backblaze/
source "${virtual_env_dir}bin/activate"

tar_command="/usr/bin/env tar"
b2_command="/usr/bin/env b2"
python_command="/usr/bin/env python"
mail_command="/usr/bin/env mail"
delete_filter_script='trim-backup-filter.py'


delete_filter_script_path="${script_dir}/${delete_filter_script}"


notify_admins () {
    recipients="$1"
    subject="$2"
    body="$3"
    echo "sending mail to $recipients"
    echo "subject: $subject"
    echo "body: $body"

    # echo "$body" | mail -s "$subject" "$recipients"
}


echo "backup started started: `date`"


# create tarballs of all directories under source_dir
tarballs_counter=0
for target in $source_dir*/ ; do
    echo "creating tarball of directory $target"

    cd $target
    basename=${PWD##*/}

    cd $source_dir
    $tar_command --ignore-failed-read -czf ${backup_dir}/${basename}.tar.gz $basename

    exitcode=$?
    if [ "$exitcode" != "1" ] && [ "$exitcode" != "0" ]; then
        echo "- Could not create file: ${basename}.tar.gz" >&2
        notify_admins "$mail_recipient" "[$system_name] Could not create file: ${basename}.tar.gz" "Could not create file: ${basename}.tar.gz"
        exit 1
    fi
    tarballs_counter=$((tarballs_counter + 1))
    echo "+ ${basename}.tar.gz created"
done

# create tarballs of backup sql files
for target in $source_db_dir*.sql ; do
    cd $source_db_dir
    
    basename=$(basename $target)
    echo $basename
    echo "creating tarball of sql file $basename"

    cd $source_dir
    $tar_command -czf ${backup_dir}/${basename}.tar.gz $target

    exitcode=$?
    if [ "$exitcode" != "1" ] && [ "$exitcode" != "0" ]; then
        echo "- Could not create file: ${basename}.tar.gz" >&2
        notify_admins "$mail_recipient" "[$system_name] Could not create file: ${basename}.tar.gz" "Could not create file: ${basename}.tar.gz"
        exit 1
    fi
    tarballs_counter=$((tarballs_counter + 1))
    echo "+ ${basename}.tar.gz created"
done


# upload to b2 bucket
uploads_counter=0
for backup_file in $backup_dir*tar.gz ; do

    if test `find "$backup_file" -mmin +720`
    then
        echo "- file $backup_file is too old. skipping from upload..."
        continue;
    fi

    filename=${backup_file##*/}
    echo "+ uploading $filename"
    echo "$b2_command upload-file $bucket_name "$backup_file" `date +\%Y-\%m-\%d`/$filename"
    $b2_command upload-file $bucket_name "$backup_file" "`date +\%Y-\%m-\%d`/$filename"

    if [ $? -eq 0 ]
    then
        uploads_counter=$((uploads_counter + 1))
        echo "+ '$backup_file' uploaded!"
    else
        echo "- Could not upload file" >&2
        notify_admins "$mail_recipient" "[$system_name] Could not upload file: $backup_file" "Could not upload file: $backup_file"
        exit 1
    fi
done


# identify old backups that need to be purged

list_of_backups=`/usr/bin/mktemp` # /bin/mktemp on webfaction
list_of_backups_to_delete=`/usr/bin/mktemp`

# list all backups (in json format): 
echo "+retrieving backup list..."
$b2_command list-file-names $bucket_name > $list_of_backups

if [ $? -eq 0 ]
then
    echo "+ backup list retrieved"
else
    echo "- Could not retrieve backup list" >&2
    notify_admins "$mail_recipient" "[$system_name] Could not retrieve backup list" "Could not retrieve backup list"
    exit 1
fi

# pass it to external python script to determine which backup to delete
# returns a list of file id
$python_command $delete_filter_script_path $list_of_backups > $list_of_backups_to_delete

if [ $? -eq 0 ]
then
    echo "+ backup list processed"
else
    echo "- Could not process backup list" >&2
    notify_admins "$mail_recipient" "[$system_name] Could not process backup list" "Could not process backup list"
    exit 1
fi


#delete the backups
deletes_counter=0
while read target_backup; do
    echo $target_backup
    echo "$b2_command delete-file-version $target_backup"
    $b2_command delete-file-version $target_backup

    if [ $? -eq 0 ]
    then
        deletes_counter=$((deletes_counter + 1))
        echo "+ deleted: $target_backup"
    else
        echo "- Could not delete $target_backup" >&2
        notify_admins "$mail_recipient" "[$system_name] Could not delete $target_backup" "Could not delete $target_backup"
        exit 1
    fi

done <$list_of_backups_to_delete


echo "${tarballs_counter} tarballs created, ${uploads_counter} tarballs uploaded, ${deletes_counter} old backups deleted"

# sanity check:
# if no tarball created, raise alert
if [ "$tarballs_counter" -eq "0" ]; then
    echo "- no tarball created! sending alert!"
    notify_admins "$mail_recipient" "[$system_name] No tarball created. Possible backup issue!" "No tarball created. Possible backup issue!"
    exit 1
fi

# if no file uploaded, raise alert
if [ "$uploads_counter" -eq "0" ]; then
    echo "- no tarball uploaded! sending alert!"
    notify_admins "$mail_recipient" "[$system_name] No tarball uploaded. Possible backup issue!" "No tarball uploaded. Possible backup issue!"
    exit 1
fi

# if uploaded counter is lower than tarball counter
if [ "$uploads_counter" -lt "$tarballs_counter" ]; then
    echo "- not all tarballs are uploaded!"
    notify_admins "$mail_recipient" "[$system_name] Not all tarballs are uploaded. Possible backup issue!" "Not all tarballs are uploaded. Possible backup issue!"
    exit 1
fi

# if too many old backups deleted, raise alert
ceiling=$((tarballs_counter * 2))
if [ "$deletes_counter" -gt "$ceiling" ]; then
    echo "- too many old backups deleted!"
    notify_admins "$mail_recipient" "[$system_name] Possible backup issue!" "The number of deleted old backups seems to be larger than usual. Possible backup issue!"
    exit 1
fi

echo "sanity check passed. backup completed at `date`"
