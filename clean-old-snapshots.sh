#!/bin/bash
# Clean old snapshots that match one or more given tags. It will keep all backups that
# aren't older than a given amount of days, a backup per day for all backups that aren't
# older than another amount of days (bigger than previous one), and delete all backups
# older than that.
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
[ -f <another_snapshot_filter ] -a <keep_all_backups_that_are_not_older_than_this_days> \
-d <one_per_day_days:delete_all_days> $EC2_PARAMS_DESC
Note that: 
  - F: Snapshot filters can be any accepted filters by command ec2-describe-snapshots
(http://docs.amazonwebservices.com/AWSEC2/latest/CommandLineReference/ApiReference-cmd-DescribeSnapshots.html)
  - d <x:y>: Backups older than y days will be deleted, backups older than x days but not
older than x days will be erased except one per day, and backups not older than x days
won't be erased"

function parse_params
{
    while getopts ":f:d:$EC2_PARAMS_OPTS" opt; do
        case $opt in
        f)
            create_or_append_to_var FILTERS "$OPTARG"
            ;;
        d)
            KEEP_ONE_PER_DAY_DAYS=`echo $OPTARG | cut -d':' -f1 | grep -E ^[0-9]+$`
            DELETE_ALL_DAYS=`echo $OPTARG | cut -d':' -f2 | grep -E ^[0-9]+$`
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
if [ -z "$KEEP_ONE_PER_DAY_DAYS" ] || [ -z "$DELETE_ALL_DAYS" ] ; then
    print_error "No days interval provided, or it was in a wrong format"
    usage "$USAGE_DESCRIPTION"
fi
if [ $KEEP_ONE_PER_DAY_DAYS -gt $DELETE_ALL_DAYS ] ; then
    print_error "Delete all backups days ($DELETE_ALL_DAYS) must be greater than \
keep one per day days ($KEEP_ONE_PER_DAY_DAYS)"
    usage "$USAGE_DESCRIPTION"
fi
if [ -z "$FILTERS" ] ; then
    print "Warning: no filters provided. ALL snapshots will be candidate for deletion"
    time=10
    while [ $time -gt -1 ] ; do echo -n "$time " ; time=`expr $time - 1` ; sleep 1 ; done
    echo
    print "Ok, here we go..."
fi
IFS=$'\n'
KEEP_ONE_PER_DAY_DATE=`date -d "$KEEP_ONE_PER_DAY_DAYS days ago" +%Y%m%d 2> /dev/null`
DELETE_ALL_DATE=`date -d "$DELETE_ALL_DAYS days ago" +%Y%m%d 2> /dev/null` # Won't work in BSD date
if [ -z "$KEEP_ONE_PER_DAY_DATE" ] ; then
    KEEP_ONE_PER_DAY_DATE=`date -v-"$KEEP_ONE_PER_DAY_DAYS"d +%Y%m%d`
    DELETE_ALL_DATE=`date -v-"$DELETE_ALL_DAYS"d +%Y%m%d` # Hack for Mac Os X
fi
if [ -z "$DELETE_ALL_DATE" ] || [ -z "$KEEP_ONE_PER_DAY_DATE" ] ; then
    print_error "Dates couln'd be calculated :-("
    exit 1
fi
print "Backups older than '$DELETE_ALL_DATE' will be erased. One backup per day will be \
kept for backups older than '$KEEP_ONE_PER_DAY_DATE' but not older than '$DELETE_ALL_DATE'. \
Backups not older than '$KEEP_ONE_PER_DAY_DATE' won't be erased"

create_or_append_to_var EC2_DESC_SNAPS_CMD "ec2-describe-snapshots --hide-tags"
IFS=$' '
for FILTER in $FILTERS ; do
    create_or_append_to_var EC2_DESC_SNAPS_CMD "-F '$FILTER'"
done
IFS=$'\n'
echo "Executing $EC2_DESC_SNAPS_CMD..."
for SNAP_DESC in `eval $EC2_DESC_SNAPS_CMD` ; do
    search_by_regexp SNAP_ID "$SNAP_DESC" '^snap-'
    search_by_regexp CREATION_DATE "$SNAP_DESC" "$DATE_REGEXP"
    create_or_append_to_var SNAPS_DESC "$CREATION_DATE $SNAP_ID" '\n'
done
if [ -z "$SNAP_DESC" ] ; then
    print_error "No snapshots found with the given criteria"
    usage
fi

for SNAP_DESC in `echo -e $SNAPS_DESC | awk '{ print $1" "$2 }' | sort -n` ; do
    SNAP_DATE=`echo $SNAP_DESC | cut -d' ' -f1 | cut -d'T' -f1 | tr -d '-'`
    SNAP_ID=`echo $SNAP_DESC | cut -d' ' -f2`
    if [ "$SNAP_DATE" -lt "$DELETE_ALL_DATE" ] ; then
        print "$SNAP_ID - $SNAP_DATE - older than $DELETE_ALL_DATE - deleting..."
    elif [ "$SNAP_DATE" -gt "$KEEP_ONE_PER_DAY_DATE" ] ; then
        if [ ! -z "$PREVIOUS_SNAP_DATE" ] ; then
            print "$PREVIOUS_SNAP_ID - $PREVIOUS_SNAP_DATE - last of its date - keeping..."
            PREVIOUS_SNAP_DATE=""
        fi
        print "$SNAP_ID - $SNAP_DATE - newer than $KEEP_ONE_PER_DAY_DATE - keeping..."
    else
        if [ ! -z "$PREVIOUS_SNAP_DATE" ] ; then
            if [ "$PREVIOUS_SNAP_DATE" == "$SNAP_DATE" ]; then
                print "$PREVIOUS_SNAP_ID - $PREVIOUS_SNAP_DATE - not the last of its date - deleting..."
            else
                print "$PREVIOUS_SNAP_ID - $PREVIOUS_SNAP_DATE - last of its date - keeping..."
            fi
        fi
        PREVIOUS_SNAP_ID="$SNAP_ID"
        PREVIOUS_SNAP_DATE="$SNAP_DATE"
    fi
done

