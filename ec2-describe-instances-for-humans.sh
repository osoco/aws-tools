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

USAGE_DESCRIPTION="Usage: `basename $0` $EC2_PARAMS_DESC"

function parse_params
{
    while getopts ":$EC2_PARAMS_OPTS" opt; do
        case $opt in
        r)
            REGION="$OPTARG"
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

function print_current_instance_info
{
    print "Instance $INSTANCE_ID of type $TYPE, $STATUS since $START_TIME
Reservation: $RESERVATION_ID - AMI: $AMI_ID
DNS (public-private): $PUBLIC_DNS - $PRIVATE_DNS
SSH key name: $SSH_KEY"
}

function clean_instance_info
{
    INSTANCE_ID=""
}

parse_params $@

if [ -z "$REGION" ] ; then
    print_error "No region provided. All regions will be used"
    IFS=$'\n'
    for region in `ec2-describe-regions | awk '{print $2}'` ; do
        create_or_append_to_var REGIONS "$region"
    done
else
    REGIONS="$REGION"
fi

IFS=$' '
for region in $REGIONS ; do
    IFS=$'\n'
    for instance_line in `ec2-describe-instances --region "$region"`; do
        line_type=`echo "$instance_line" | cut -f1`
        case "$line_type" in
        RESERVATION)
            if [ ! -z "$INSTANCE_ID" ] ; then
                print_current_instance_info
                clean_instance_info
            fi
            search_by_regexp RESERVATION_ID "$instance_line" "^r-"
        ;;
        INSTANCE)
            search_by_regexp INSTANCE_ID "$instance_line" "^i-"
            search_by_regexp AMI_ID "$instance_line" "^ami-"
            search_by_regexp PUBLIC_DNS "$instance_line" "^ec2-"
            search_by_regexp PRIVATE_DNS "$instance_line" "^ip-"
            search_by_regexp SSH_KEY "$instance_line" "-key$"
            search_by_regexp START_TIME "$instance_line" "$DATE_REGEXP"
            TYPE="`ec2-describe-instance-attribute -t i-44110d33 | awk '{ print $3}'`"
            IFS=$' '
            for status in $INSTANCE_POSSIBLE_STATUS ; do
                search_by_regexp STATUS "$instance_line" "$status"
            done
        ;;
        BLOCKDEVICE)
        ;;
        TAG)
        ;;
        esac
    done
done
