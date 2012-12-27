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

USAGE_DESCRIPTION="Usage: `basename $0` -o OLD_VOLUME_ID -s SNAPSHOT_ID (-d) $EC2_PARAMS_DESC
Options:
\t -o OLD_VOLUME_ID The volume id to replace
\t -s SNAPSHOT_ID The snapshot id that will be used to create the new volume
\t -d If passed, the old volume will be deleted after replacing it"

function parse_params
{
    while getopts ":o:s:d$EC2_PARAMS_OPTS" opt; do
        case $opt in
        o)
            OLD_VOLUME_ID="$OPTARG"
            ;;
        s)
            SNAPSHOT_ID="$OPTARG"
            ;;
        d)
        	DELETE_OLD_VOLUME="true"
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
check_given_mandatory_params OLD_VOLUME_ID SNAPSHOT_ID
print_ec2_vars

print "Finding old volume properties"
VOL_DESC_CMD="ec2-describe-volumes \"$OLD_VOLUME_ID\" | grep -E \"^(VOLUME|ATTACHMENT)\""
execute VOL_DESC "$VOL_DESC_CMD"
VOL_TYPE="$(echo $VOL_DESC | awk '{print $8}')"
if [ "$VOL_TYPE" == "io1" ] ; then
	VOL_TYPE="$VOL_TYPE --iops $(echo $VOL_DESC | awk '{print $9}')"
fi
VOL_SIZE="$(echo $VOL_DESC | grep ^VOLUME | awk '{print $3}')"
VOL_ZONE="$(echo $VOL_DESC | grep ^VOLUME | awk '{print $5}')"
search_by_regexp VOL_INSTANCE_ID "$VOL_DESC" "^i-"
search_by_regexp VOL_MOUNT_POINT "$VOL_DESC" "dev"
check_for_runtime_value "VOL_INSTANCE_ID"
check_for_runtime_value "VOL_MOUNT_POINT"
check_for_runtime_value "VOL_SIZE"
check_for_runtime_value "VOL_TYPE"
check_for_runtime_value "VOL_ZONE"

print "Detaching volume $OLD_VOLUME_ID"
DETACH_VOL_CMD="ec2-detach-volume $OLD_VOLUME_ID"
execute DETACH_VOL_CMD_OUTPUT "$DETACH_VOL_CMD"
check_for_runtime_value "DETACH_VOL_CMD_OUTPUT"

print "Waiting for old volume to be available"
DESC_VOL_CMD="ec2-describe-volumes $OLD_VOLUME_ID | grep ^VOLUME"
while [ -z "$VOL_AVAILABLE_STATUS" ] ; do
	execute OLD_VOLUME_ID_STATUS_OUTPUT "$DESC_VOL_CMD"
	check_for_runtime_value OLD_VOLUME_ID_STATUS_OUTPUT
	search_by_regexp VOL_AVAILABLE_STATUS "$OLD_VOLUME_ID_STATUS_OUTPUT" "^available$"
	sleep 5
done

print "Creating new volume"	
CREATE_VOL_CMD="ec2-create-volume --snapshot $SNAPSHOT_ID --size $VOL_SIZE \
	--availability-zone $VOL_ZONE --type $VOL_TYPE"
execute CREATE_VOLUME_OUTPUT "$CREATE_VOL_CMD"
check_for_runtime_value "CREATE_VOLUME_OUTPUT" 
search_by_regexp CREATED_VOLUME "$CREATE_VOLUME_OUTPUT" "^vol-"
check_for_runtime_value "CREATED_VOLUME"

print "Waiting for new volume to be available"
DESC_VOL_CMD="ec2-describe-volumes $CREATED_VOLUME | grep ^VOLUME"
while [ -z "$VOL_AVAILABLE_STATUS" ] ; do
	execute CREATED_VOLUME_STATUS_OUTPUT "$DESC_VOL_CMD"
	check_for_runtime_value CREATED_VOLUME_STATUS_OUTPUT
	search_by_regexp VOL_AVAILABLE_STATUS "$CREATED_VOLUME_STATUS_OUTPUT" "^available$"
	sleep 5
done

print "Copying tags from old volume to created one"
COPY_TAGS_CMD="`dirname $0`/copy-tags.sh -o \"$OLD_VOLUME_ID\" -n \"$CREATED_VOLUME\""
echo "Excuting $COPY_TAGS_CMD"
eval "$COPY_TAGS_CMD"

print "Attaching created volume $CREATED_VOLUME to $VOL_INSTANCE_ID"
ATTACH_VOL_CMD="ec2-attach-volume --instance $VOL_INSTANCE_ID \
	--device $VOL_MOUNT_POINT $CREATED_VOLUME"
execute ATTACH_VOL_CMD_OUTPUT "$ATTACH_VOL_CMD"
check_for_runtime_value "ATTACH_VOL_CMD_OUTPUT"
	
print "Waiting for new volume $CREATED_VOLUME to be attached"
DESC_VOL_CMD="ec2-describe-volumes $CREATED_VOLUME | grep ^ATTACHMENT"
while [ -z "$VOL_ATTACHED_STATUS" ] ; do
	execute CREATED_VOLUME_STATUS_OUTPUT "$DESC_VOL_CMD"
	check_for_runtime_value CREATED_VOLUME_STATUS_OUTPUT
	search_by_regexp VOL_ATTACHED_STATUS "$CREATED_VOLUME_STATUS_OUTPUT" "^attached$"
	sleep 5
done

if [ ! -z "$DELETE_OLD_VOLUME" ] ; then
	print "Deleting old volume $OLD_VOLUME_ID"
	DEL_VOL_CMD="ec2-delete-volume $OLD_VOLUME_ID"
	execute DEL_VOL_CMD_OUTPUT "$DEL_VOL_CMD"
	check_for_runtime_value "DEL_VOL_CMD_OUTPUT"
fi

print "Created volume $CREATED_VOLUME and attached it to $VOL_INSTANCE_ID"