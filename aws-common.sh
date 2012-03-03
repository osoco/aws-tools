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
    echo "Executing: $2"
    local result=$(eval $2)
    export ${1}="$result"
}

# print SOME_TEXT
function print 
{
    echo "##################################################################"
    echo "##### $1"
}

# print_error SOME_TEXT
function print_error
{
    echo "$1" >&2
}

# usage USAGE_DESCRIPTION
function usage
{
    print_error "$1"
    exit 1
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

EC2_PARAMS_DESC="[ -K ec2_private_key ] [ -C ec2_cert ] [ -r ec2_region ]"
EC2_PARAMS_OPTS="K:C:r:"

# parse_common_ec2_params SOME_PARAM SOME_VALUE 
function parse_common_ec2_param
{
    case $1 in
    K)
        export EC2_PRIVATE_KEY="$OPTARG"
        ;;
    C)
        export EC2_CERT="$OPTARG"
        ;;
    r)
        export EC2_URL="https://ec2.$OPTARG.amazonaws.com"
        ;;
    *)
        return 1
        ;;
    esac
}


