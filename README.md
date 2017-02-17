
Backup sites files and database dumps to Backblaze B2 and database dumps to Tarsnap.


Setup
=====

- Clone this repo

- Create a python virtualenv inside this project directory:
  - `virtualenv .backblaze --python=python2.7`
  - `source .backblaze/bin/activate`

- Install dependencies:
  - `pip install -r requirements.txt`

- Login to your B2 account:
  - `b2 authorize_account <account-id>`

- Create a bucket to store your backups:
  - `b2 create_bucket gwd-backup-<bucketName> allPrivate`

- copy `./backup.sh` to `backup-prod.sh`, replace preset variables with appropriate value for your server.

- Test the backup script:
  - `./backup-prod.sh`

