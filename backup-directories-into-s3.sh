#  Copyright 2013 Orange Software S.L. (OSOCO)
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

#!/bin/bash
# Backup a given list of directories into S3 by compressing and splitting them (in case
# is necessary).
# Depends on:
# - aws-common.sh
# - s3cmd
# - bzip2
# Author: diego.toharia@osoco.es - OSOCO

COMMON_SCRIPT_PATH="`dirname $0`/aws-common.sh"
if [ -f "$COMMON_SCRIPT_PATH" ] ; then
    source $COMMON_SCRIPT_PATH
else
    echo "aws-common.sh not found in $COMMON_SCRIPT_PATH... Exiting now" >&2
    exit 1
fi

USAGE_DESCRIPTION="Usage: `basename $0` -b <bucket_path>] [ -p <backup_path> ] \
[-t <tmp_directory>] [ -d ] <directory_to_backup> [<another_directory_to_backup>]\n\
Options description:\n\
-b <bucket_path> The bucket where the backups will be uploaded\n\
-p <backup_path> The path that will be prepended to each backup filename (by default, /)\n\
-t <tmp_directory> The temporary directory to use (by default, /tmp)\n\
-d When passed, each directory will be backuped in its own S3 directory\n\n\
The script needs s3cmd to be installed and configured"

BACKUP_PATH="/"
TMP_DIR="/tmp/"
function parse_params
{
    while getopts ":b:p:d" opt; do
        case $opt in
        b)
            BUCKET_PATH="$OPTARG"
            ;;
        p)
            BACKUP_PATH="$OPTARG"
            ;;
        t)
            TMP_DIR="$OPTARG"
            ;;
        d)
            DIRECTORY_BY_BACKUP="YES"
            ;;
        \?)
            print_error "Unknown option -$OPTARG"
            usage "$USAGE_DESCRIPTION"
            ;;
        esac
    done
}

parse_params $@
shift `expr $OPTIND - 1`
var_not_empty_or_fail BUCKET_PATH "The bucket can't be empty!"
S3CMD_PATH="`which s3cmd`"
var_not_empty_or_fail S3CMD_PATH "s3cmd not found in path!"

TMP_DIR="$TMP_DIR/`basename $0`.$$"
mkdir "$TMP_DIR"
print "'$TMP_DIR' will be used as temporary directory"

while [[ ! -z "$1" ]]; do
    print "Backing up directory '$1'"
    if [[ -d "$1" ]]; then
        BACKUPED_FILE="$TMP_DIR/`basename $1`_`date +%F_%H-%M-%S`.tar.bz2"
        CURRENT_BACKUP_PATH=`echo "$BACKUP_PATH" | sed -e 's/^[/]*//' | sed -e 's/[/]*$//'`
        if [[ ! -z "$CURRENT_BACKUP_PATH" ]] ; then
            CURRENT_BACKUP_PATH="$CURRENT_BACKUP_PATH"'/'
        fi
        if [[ ! -z "$DIRECTORY_BY_BACKUP" ]]; then
            CURRENT_BACKUP_PATH="$CURRENT_BACKUP_PATH`basename $1`/"
        fi
        S3_FILE="$BUCKET_PATH/$CURRENT_BACKUP_PATH`basename $BACKUPED_FILE`"
        tar jcvf "$BACKUPED_FILE" "$1" &> /dev/null && $S3CMD_PATH put "$BACKUPED_FILE" "$S3_FILE"
    else
        print_error "$1 doesn't exists, skipping..."
    fi
    shift
done

rm -rf "$TMP_DIR"
