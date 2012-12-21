#!/bin/bash
# Copy the tags from a given object to another one. Note that Amazon CFN tags will be tail 
# truncated using ':' as the separator character 
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

USAGE_DESCRIPTION="Usage: `basename $0` -o OBJECT_WITH_TAGS -n OBJECT_TO_COPY_TAGS $EC2_PARAMS_DESC"

function parse_params
{
    while getopts ":n:o:$EC2_PARAMS_OPTS" opt; do
        case $opt in
        o)
            OBJECT_WITH_TAGS="$OPTARG"
            ;;
        n)
            OBJECT_TO_COPY_TAGS="$OPTARG"
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
check_given_mandatory_params OBJECT_WITH_TAGS OBJECT_TO_COPY_TAGS
TAG_CMD="ec2-describe-tags -F resource-id=\"$OBJECT_WITH_TAGS\" | awk '{print \$4\"=\"\$5}'"
execute "TAGS_TO_COPY" "$TAG_CMD" 
IFS=$'\n'
for tag in $TAGS_TO_COPY ; do
	TAG_KEY="$(echo $tag | cut -d'=' -f1 | awk -F':' '{print $NF}' | sed 's/-/\\-/g')"
	TAG_VALUE="$(echo $tag | cut -d'=' -f2 | sed 's/-/\\-/g')"
	TAGS_STRING="$TAGS_STRING --tag $TAG_KEY=$TAG_VALUE"
done
TAG_CMD="ec2-create-tags $TAGS_STRING $OBJECT_TO_COPY_TAGS"
execute TAG_OUTPUT "$TAG_CMD"