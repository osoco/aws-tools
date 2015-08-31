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

# Common utility EC2 functions. Meant to be sourced by other scripts
# Depends on:
# - ec2-api-tools
# - awk
# Author: diego.toharia@osoco.es - OSOCO

# execute OUPUT_VAR "some command and its opts"
# the output will be flatenned to one line

INSTANCE_POSSIBLE_STATUS="pending running shutting-down terminated stopping stopped"
DATE_REGEXP='^20[0-9][0-9]-[0-1][0-9]-[0-3][0-9]T'

function execute
{
    echo "Executing: $2" >&2
    export ${1}="$(eval $2)"
}

# print SOME_TEXT
function print
{
	echo -en "\033[0;36m############################################################\n"
	echo -en "##### $1""\033[0m \n"
}

# print_error SOME_TEXT
function print_error
{
    echo -e "$1" >&2
}

# usage USAGE_DESCRIPTION
function usage
{
    print_error "$1"
    exit 1
}

# check_for_runtime_value VARIABLE_TO_CHECK
function check_for_runtime_value {
	eval RUNTIME_VALUE="\$$1"
	if [ -z "$RUNTIME_VALUE" ] ; then
    	echo -en "Couldn't find a proper value for \033[1;31m$1\033[0m, exiting now...\n" >&2
    	exit 1
    else
    	echo -en "Found \033[1;33m$RUNTIME_VALUE\033[0m as the value for $1 \n"
   	fi
}

# search_by_regexp RESULT_VAR_NAME SOME_TEXT REGEXP_TO_SEARCH_IN_SOMETEXT
function search_by_regexp
{
    local result=`echo "$2" | awk -v regexp="$3" '{ for (i=1; i<=NF; i++) if ($i ~ regexp) print $i }'`
    export ${1}="$result"
}

# create_or_append_to_var VAR_NAME TEXT_TO_APPEND [ SEPARATOR=' ']
function create_or_append_to_var
{
    SEPARATOR="$3"
    if [ -z "$SEPARATOR" ] ; then SEPARATOR=' ' ; fi
    CURRENT_VAR_VALUE=$(eval echo "\$$1")
    if [ -z "$CURRENT_VAR_VALUE" ]; then
        local result="$2"
    else
        local result="$CURRENT_VAR_VALUE""$SEPARATOR""$2"
    fi
    export ${1}="$result"
}

function missing_param {
    echo "Missing mandatory parameter $1" >&2
    usage "$USAGE_DESCRIPTION"
    exit 1
}

function check_given_mandatory_params {
	IFS=$' '
	for PARAM in "$@" ; do
		eval "PARAM_VALUE=\$$PARAM"
		if [ -z "$PARAM_VALUE" ] ; then
			missing_param "$PARAM"
		fi
	done
}

# var_not_empty_or_fail BUCKET_NAME "The bucket can't be empty!"
function var_not_empty_or_fail
{
    eval local VAR_VALUE=\$$1
    if [ -z $"$VAR_VALUE" ] ; then
        print_error "$2"
        usage "$USAGE_DESCRIPTION"
    fi
}

function print_ec2_vars
{
	for i in EC2_PRIVATE_KEY EC2_CERT EC2_URL ; do
		VAR_VALUE="$(eval echo \$$i)"
		echo "Using $i=$VAR_VALUE" >&2
	done
}

EC2_PARAMS_DESC="[ -O aws_access_key ] [ -W aws_secret_key ] [ -U URL ]"
EC2_PARAMS_OPTS="O:W:U:"

# parse_common_ec2_params SOME_PARAM SOME_VALUE
function parse_common_ec2_param
{
    case $1 in
    O)
        export AWS_ACCESS_KEY="$OPTARG"
        ;;
    W)
        export AWS_SECRET_KEY="$OPTARG"
        ;;
    U)
        export EC2_URL="$OPTARG"
        ;;
    *)
        return 1
        ;;
    esac
}
