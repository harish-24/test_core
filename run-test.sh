#!/bin/bash

TCDIR=$(dirname $(readlink -f $BASH_SOURCE))
export TESTNAME="test"
VERBOSE=""
TESTCASE_FILTER=""
SCRIPT=false # script mode

while getopts vs:t:f:S OPT ; do
    case $OPT in
        "v" ) VERBOSE="-v" ;;
        "s" ) KERNEL_SRC="${OPTARG}" ;;
        "t" ) export TESTNAME="${OPTARG}" ;;
        "f" ) export TESTCASE_FILTER="${OPTARG}" ;;
        "S" ) SCRIPT=true
    esac
done

shift $[OPTIND-1]
RECIPEFILE=$1

# Test root directory
export TRDIR=$(dirname $(readlink -f $RECIPEFILE))

. ${TCDIR}/setup_generic.sh
. ${TCDIR}/setup_test_core.sh

if [ "$SCRIPT" == true ] ; then
    bash ${RECIPEFILE}
else
    while read line ; do
        [ ! "$line" ] && continue
        [[ $line =~ ^# ]] && continue

        if [ "$line" = do_test_sync ] ; then
            do_test "$TEST_PROGRAM -p ${PIPE} ${VERBOSE}"
        elif [ "$line" = do_test_async ] ; then
            do_test_async
        else
            eval $line
        fi
    done < ${RECIPEFILE}
fi

show_summary
