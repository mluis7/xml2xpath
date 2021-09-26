#!/bin/bash
#
dbg=0
[ -n "$dbg" ] && dbg=1

#---------------------------------------------------------------------------------------
# Verify test case result and return result and description
#---------------------------------------------------------------------------------------
function test_result(){
    retval=1
    [ -n "$2" ] && retval="$2"
    
    tc_result="FAILED"
    if [ "$1" -eq "$retval" ]; then
        tc_result="PASSED"
        echo "${tc_result}"
    else
        echo "${tc_result}" | show_color
    fi
    
}

function show_color(){
    while read -r line; do 
        echo -e "  \e[01;31m$line\e[0m" >&2
    done
}

#---------------------------------------------------------------------------------------
# Run test case
#---------------------------------------------------------------------------------------
function show_errors(){
    if [ "$dbg" -eq 1 ]; then
        tee /dev/stderr 2> >(show_color) | grep -Eq 'XPath error|No xpath found'
    else
        grep -Eq 'XPath error|No xpath found'
    fi
}

#---------------------------------------------------------------------------------------
# Run test case
#---------------------------------------------------------------------------------------
function print_test_descr(){
    echo -e "\n$1   : ${!1}"
    if [ "$dbg" -eq 1 ]; then
        echo "cmd    : ../xml2xpath.sh ${test_opts[*]} ${test_type_opts[*]}"
    fi
}

#---------------------------------------------------------------------------------------
# Run test case
#---------------------------------------------------------------------------------------
function test_run(){
    if [ ! -f "${test_type_opts[${#test_type_opts[@]} - 1]}" ]; then
        echo "ERROR file not found: ${test_type_opts[${#test_type_opts[@]} - 1]}"  | show_color
        exit 1
    fi
    print_test_descr "$1"
    ../xml2xpath.sh "${test_opts[@]}" "${test_type_opts[@]}" 2>&1 1>/dev/null | show_errors
}

#---------------------------------------------------------------------------------------
# Run test case for duplicates count
#---------------------------------------------------------------------------------------
function test_run_count(){
    ../xml2xpath.sh "${test_opts[@]}" "${test_type_opts[@]}" | wc -l
}