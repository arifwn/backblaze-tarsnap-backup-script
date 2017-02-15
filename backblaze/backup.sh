#!/usr/bin/env bash

# b2 authorize-account <account-id>
system_name="test-backup"
source_dir=/Users/arif/tmp/test-backup/source/
backup_dir=/Users/arif/tmp/test-backup/backups/
bucket_name="gwd-backup-test-backup"
mail_recipient='arif@sainsmograf.com'

b2_command=b2
py_dir_to_delete='trim-backup-filter.py'

last_dir=`pwd`
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
py_dir_to_delete="${script_dir}/${py_dir_to_delete}"

# create tarballs of all directories under source_dir
for target in $source_dir*/ ; do
    echo "creating tarball of directory $target"

    cd $target
    basename=${PWD##*/}

    cd $source_dir
    tar -czf ${backup_dir}/${basename}.tar.gz $basename
    if [ $? -eq 0 ]
    then
        echo "+ ${basename}.tar.gz created"
    else
        echo "- Could not create file: ${basename}.tar.gz" >&2
        # echo "Could not create file: ${basename}.tar.gz" | mail -s "[$system_name] Could not create file: ${basename}.tar.gz" $mail_recipient
        exit 1
    fi
done

# upload to b2 bucket
for backup_file in $backup_dir*tar.gz ; do
    filename=${backup_file##*/}
    echo "+ uploading $filename"
    echo "$b2_command upload-file $bucket_name "$backup_file" `date +\%Y-\%m-\%d`/$filename"
    $b2_command upload-file $bucket_name "$backup_file" "`date +\%Y-\%m-\%d`/$filename"

    if [ $? -eq 0 ]
    then
        echo "+ '$backup_file' uploaded!"
    else
        echo "- Could not upload file" >&2
        # echo "Could not upload file: $backup_file" | mail -s "[$system_name] Could not upload file: $backup_file" $mail_recipient
        exit 1
    fi
done


# identify old backups that need to be purged

list_of_backups=`/usr/bin/mktemp`
list_of_backups_to_delete=`/usr/bin/mktemp`

# list all backups (in json format): 
echo "+retrieving backup list..."
$b2_command list-file-names $bucket_name > $list_of_backups

if [ $? -eq 0 ]
then
    echo "+ backup list retrieved"
else
    echo "- Could not retrieve backup list" >&2
    # echo "Could not retrieve backup list" | mail -s "[$system_name] Could not retrieve backup list" $mail_recipient
    exit 1
fi

# pass it to external python script to determine which backup to delete
# returns a list of file id
$py_dir_to_delete $list_of_backups > $list_of_backups_to_delete

if [ $? -eq 0 ]
then
    echo "+ backup list processed"
else
    echo "- Could not process backup list" >&2
    # echo "Could not process backup list" | mail -s "[$system_name] Could not process backup list" $mail_recipient
    exit 1
fi


#delete the backups
while read target_backup; do
    echo $target_backup
    echo "$b2_command delete-file-version $target_backup"
    $b2_command delete-file-version $target_backup

    if [ $? -eq 0 ]
    then
        echo "+ deleted: $target_backup"
    else
        echo "- Could not delete $target_backup" >&2
        # echo "Could not delete $target_backup" | mail -s "[$system_name] Could not delete $target_backup" $mail_recipient
        exit 1
    fi

done <$list_of_backups_to_delete


# sanity check:
# if no file uploaded, raise alert
# if total uploaded size is too small or too large than before, raise alert
# if too many old backups deleted, raise alert

echo "backup complete"
