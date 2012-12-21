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
[ -t <backup_tag=backup_tag_value> ] [ -t <backup_tag=backup_tag_value> ] $EC2_PARAMS_DESC"

function volumes_ids_or_exit
{
    if [ -z "$VOLUMES_IDS" ] ; then
        print_error "No volume or volumes to backup..."
        usage "$USAGE_DESCRIPTION"
    fi
}

function parse_params
{
    while getopts ":v:t:d:s$EC2_PARAMS_OPTS" opt; do
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
    search_by_regexp SNAPSHOT_ID "$SNAPSHOT_CREATION_OUTPUT" "^snap-"
    if [ -z "$SNAPSHOT_ID" ] ; then
        print_error "Failed to obtain a snapshot for volume $VOLUME_ID. Obtained output $SNAPSHOT_CREATION_OUTPUT"
    else
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
        if [ ! -z "$SYNC" ] ; then
            print "Waiting for snapshot $SNAPSHOT_ID to be completed..."
            while [ -z "$COMPLETED" ]; do
                sleep 15
                execute COMPLETED 'ec2-describe-snapshots --hide-tags -F status=completed "'"$SNAPSHOT_ID"'"'
            done
            print "Snapshot $SNAPSHOT_ID has been completed: $COMPLETED"
        fi
        print "Backed up vol '$VOLUME_ID' in snapshot '$SNAPSHOT_ID'"
    fi
done




