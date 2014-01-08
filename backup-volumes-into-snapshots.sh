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
# Backup a given volume or volumes by making an snapshot. Supports snapshot description
# and multiple tagging. By default is asynchronous, but can be configured to wait until
# snapshot creation gets completed
# Depends on:
# - aws-common.sh
# - ec2-api-tools
# - tr
# Author: diego.toharia@osoco.es - OSOCO

COMMON_SCRIPT_PATH="`dirname $0`/aws-common.sh"
if [ -f "$COMMON_SCRIPT_PATH" ] ; then
    source $COMMON_SCRIPT_PATH
else
    echo "aws-common.sh not found in $COMMON_SCRIPT_PATH... Exiting now" >&2
    exit 1
fi

USAGE_DESCRIPTION="Usage: `basename $0` -v <volume_id> [ -v <another_volume_id> ] \
[ -d <backup_description_with_dashes_instead_spaces> ] \
[ -t <backup_tag=backup_tag_value> ] [ -t <backup_tag=backup_tag_value> ] (-v) (-c) $EC2_PARAMS_DESC
Options:
	-v VOLUME_ID a volume id to backup. You can pass this option multiple times
	-d DESCRIPTION the backup description. Due to getopts restrictions, must use dashes instead spaces (the dashes will be substituted by spaces for AWS)
	-t KEY=VALUE a tag consisting of a pair of key and value that will be used to tag the created snapshot
	-s If passed, the script will be synchronous (i.e won't finish until the snapshot is completed)
	-c If passed, the volume tags will be copied to the snapshot
"

function volumes_ids_or_exit
{
    if [ -z "$VOLUMES_IDS" ] ; then
        print_error "No volume or volumes to backup..."
        usage "$USAGE_DESCRIPTION"
    fi
}

function parse_params
{
    while getopts ":v:t:d:sc$EC2_PARAMS_OPTS" opt; do
    	echo "$opt -> $OPTARG"
        case $opt in
        v)
            create_or_append_to_var VOLUMES_IDS "$OPTARG"
            ;;
        d)
            SNAPSHOT_DESCRIPTION="`echo $OPTARG | tr '_' ' '`"
            ;;
        t)
            create_or_append_to_var TAGS "$OPTARG"
            ;;
        s)
            SYNC="yes"
            ;;
        c)
        	COPY_TAGS="yes"
        	;;
        \?)
            print_error "Unknown option -$OPTARG"
            usage "$USAGE_DESCRIPTION"
            ;;
        *)
            parse_common_ec2_param "$opt" "$OPTARG"
            ;;
        esac
    done
}

parse_params $@
check_given_mandatory_params $VOLUME_IDS
print_ec2_vars
volumes_ids_or_exit

IFS=$' '
for VOLUME_ID in $VOLUMES_IDS ; do
    print "Making a snapshot for $VOLUME_ID..."
    create_or_append_to_var CREATE_SNAP_CMD "ec2-create-snapshot"
    if [ ! -z "$SNAPSHOT_DESCRIPTION" ]; then
        create_or_append_to_var CREATE_SNAP_CMD "-d '$SNAPSHOT_DESCRIPTION'"
    fi
    create_or_append_to_var CREATE_SNAP_CMD "$VOLUME_ID"
    execute SNAPSHOT_CREATION_OUTPUT "$CREATE_SNAP_CMD"
    check_for_runtime_value SNAPSHOT_CREATION_OUTPUT
    search_by_regexp SNAPSHOT_ID "$SNAPSHOT_CREATION_OUTPUT" "^snap-"
    check_for_runtime_value SNAPSHOT_ID
    if [ ! -z "$TAGS" ] ; then
        IFS=$' '
        for TAG in $TAGS ; do
            TAG_SNAP_CMD=''
            print "Tagging snapshot '$SNAPSHOT_ID' with tag $TAG"
            create_or_append_to_var TAG_SNAP_CMD "ec2-create-tags"
            create_or_append_to_var TAG_SNAP_CMD "$SNAPSHOT_ID"
            create_or_append_to_var TAG_SNAP_CMD "-t $TAG"
            execute TAG_SNAP_OUTPUT "$TAG_SNAP_CMD"
        done
    fi
    if [ ! -z "$COPY_TAGS" ] ; then
    	COPY_TAGS_CMD="`dirname $0`/copy-tags.sh -o $VOLUME_ID -n $SNAPSHOT_ID"
    	echo "Executing '$COPY_TAGS_CMD'"
    	eval $COPY_TAGS_CMD
    fi
    if [ ! -z "$SYNC" ] ; then
        print "Waiting for snapshot $SNAPSHOT_ID to be completed..."
        while [ -z "$COMPLETED" ]; do
            sleep 15
            execute COMPLETED 'ec2-describe-snapshots --hide-tags -F status=completed "'"$SNAPSHOT_ID"'"'
        done
        print "Snapshot $SNAPSHOT_ID has been completed: $COMPLETED"
    fi
    print "Backed up vol '$VOLUME_ID' in snapshot '$SNAPSHOT_ID'"
done
