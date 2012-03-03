#!/bin/bash
# Find one or many volumes that are attached to a given instance
# Depends on:
# - aws-common.sh

COMMON_SCRIPT_PATH="`dirname $0`/aws-common.sh"
if [ -f "$COMMON_SCRIPT_PATH" ] ; then
    source $COMMON_SCRIPT_PATH
else
    echo "aws-common.sh not found in $COMMON_SCRIPT_PATH... Exiting now" >&2
    exit 1
fi

USAGE_DESCRIPTION="Usage: `basename $0` -i <instance_id> $EC2_PARAMS_DESC"

function parse_params
{
    while getopts ":i:$EC2_PARAMS_OPTS" opt; do
        case $opt in
        i)
            INSTANCE_ID="$OPTARG"
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
if [ -z "$INSTANCE_ID" ] ; then
    print_error "No instance id provided"
    usage "$USAGE_DESCRIPTION"
fi

IFS=$'\n'
for INSTANCE_DESC in `ec2-describe-instances "$INSTANCE_ID" | grep ^BLOCKDEVICE`; do
    search_by_regexp VOLUME_ID "$INSTANCE_DESC" "vol-"
    if [ ! -z "$VOLUME_ID" ] ; then
        create_or_append_to_var VOLUMES_IDS "$VOLUME_ID"
    fi
done

echo "$VOLUMES_IDS"
