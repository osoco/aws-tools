#!/bin/bash
# Find one or more volumes using a given tag or tag and value
# Depends on:
# - aws-common.sh
# - ec2-api-tools
# Author: diego.toharia@osoco.es - OSOCO

COMMON_SCRIPT_PATH="`dirname $0`/aws-common.sh"
if [ -f "$COMMON_SCRIPT_PATH" ] ; then
    source $COMMON_SCRIPT_PATH
else
    echo "aws-common.sh not found in $COMMON_SCRIPT_PATH... Exiting now" >&2
    exit 1
fi

USAGE_DESCRIPTION="Usage: `basename $0` -t <tag=tag_value> $EC2_PARAMS_DESC"

function parse_params
{
    while getopts ":t:$EC2_PARAMS_OPTS" opt; do
        case $opt in
        t)
            TAG="$OPTARG"
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
if [ -z "$TAG" ] ; then
    print_error "No tag provided"
    usage "$USAGE_DESCRIPTION"
fi

IFS=$'\n'
for VOL_DESC in `ec2-describe-volumes -F tag:"$TAG" --hide-tags | grep ^VOLUME`; do
    search_by_regexp VOLUME_ID "$VOL_DESC" "^vol-"
    create_or_append_to_var VOLUMES_IDS "$VOLUME_ID"
done
echo $VOLUMES_IDS
