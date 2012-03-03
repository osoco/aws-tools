#!/bin/bash
# Clean old snapshots that match one or more given tags. 
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

USAGE_DESCRIPTION="Usage: `basename $0` [ -f <snapshot_filter> ] \
[ -f <another_snapshot_filter ] $EC2_PARAMS_DESC
Snapshot filters can be any accepted filters by command ec2-describe-snapshots
(http://docs.amazonwebservices.com/AWSEC2/latest/CommandLineReference/ApiReference-cmd-DescribeSnapshots.html)"

function parse_params
{
    while getopts ":f:$EC2_PARAMS_OPTS" opt; do
        case $opt in
        f)
            create_or_append_to_var FILTERS "$OPTARG"
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
if [ -z "$FILTERS" ] ; then
    print "Warning: no filters provided. ALL snapshots will be candidate for deletion"
    time=10
    while [ $time -gt -1 ] ; do echo -n "$time " ; time=`expr $time - 1` ; sleep 1 ; done
    echo
    print "Ok, here we go..."
fi
create_or_append_to_var EC2_DESC_SNAPS_CMD "ec2-describe-snapshots --hide-tags"
for FILTER in $FILTERS ; do
    create_or_append_to_var EC2_DESC_SNAPS_CMD "-F '$FILTER'"
done
IFS=$'\n'
for SNAP_DESC in `eval $EC2_DESC_SNAPS_CMD` ; do
    search_by_regexp SNAP_ID "$SNAP_DESC" '^snap-'
    search_by_regexp CREATION_DATE "$SNAP_DESC" "$DATE_REGEXP"
    create_or_append_to_var SNAPS_DESC "$CREATION_DATE $SNAP_ID" '\n'
done

for SNAP_DESC in `echo -e $SNAPS_DESC | awk '{ print $1" "$2 }' | sort -n` ; do
    echo "des:$SNAP_DESC"
done

