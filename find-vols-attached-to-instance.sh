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
