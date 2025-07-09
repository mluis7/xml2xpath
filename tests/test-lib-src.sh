#!/bin/bash
#
DBG=0
[ -n "$dbg" ] && DBG="$dbg"

TRACE_FILE='/dev/null'
[[ -n "$trace" && "$trace" != '/dev/null' ]] && TRACE_FILE="$trace" ;

echo_with_pid(){
	printf "[%d] %b\n" "$$" "$@"
}

#---------------------------------------------------------------------------------------
# Verify test case result and return result and description
#---------------------------------------------------------------------------------------
test_result(){
    retval=1
    [ -n "$2" ] && retval="$2"
    
    tc_result="FAILED"
    if [ "$1" -eq "$retval" ]; then
        tc_result="PASSED"
        echo_with_pid "${tc_result}"
    else
        echo_with_pid "${tc_result}" | show_color
    fi
    
}

show_color(){
    while read -r line; do 
        echo -e "\e[01;31m$line\e[0m"
    done
}

quote_opts(){
    local str=''
    for o in "$@"; do
        if grep -q "^[-][a-z]" <<<"$o"; then
            str+=" $o "
        else
            str+="\"$o\""
        fi
    done
    echo "$str" | tr -s ' '
}

#---------------------------------------------------------------------------------------
# Run test case
#---------------------------------------------------------------------------------------
show_errors(){
	err_pattern='XPath error|No xpath found|Boolean : false'
    if [ "$DBG" -eq 1 ]; then
        tee /dev/stderr 2> >(show_color) | grep -Eq "$err_pattern"
    else
        grep -Eq "$err_pattern"
    fi
}

#---------------------------------------------------------------------------------------
# Print test case description
#---------------------------------------------------------------------------------------
print_test_descr(){
    descr="$1   : ${!1}"
    echo_with_pid "$descr"
    if [ "$DBG" -eq 1 ]; then
        topts=$(quote_opts "${test_opts[@]}")
        echo_with_pid "cmd    : ../xml2xpath.sh $topts ${test_type_opts[*]}"
    fi
}

#---------------------------------------------------------------------------------------
# Run test case
#---------------------------------------------------------------------------------------
test_run(){
    if [ ! -f "${test_type_opts[${#test_type_opts[@]} - 1]}" ]; then
        echo_with_pid "ERROR file not found: ${test_type_opts[${#test_type_opts[@]} - 1]}"  | show_color
        exit 1
    fi
    print_test_descr "$1" | tee -a "$TRACE_FILE"
    ../xml2xpath.sh "${test_opts[@]}" "${test_type_opts[@]}" 2>&1 1>>"$TRACE_FILE" | show_errors
}

#---------------------------------------------------------------------------------------
# Run count test case
#---------------------------------------------------------------------------------------
test_run_count(){
	if [ ! -f "${test_type_opts[${#test_type_opts[@]} - 1]}" ]; then
        echo_with_pid "ERROR file not found: ${test_type_opts[${#test_type_opts[@]} - 1]}"  | show_color
        exit 1
    fi
    print_test_descr "$1" | tee -a "$TRACE_FILE"
    result=$(../xml2xpath.sh "${test_opts[@]}" "${test_type_opts[@]}")
	gawk 'BEGIN{RS="\n\n";FS="\n"}
    {
        if(NR == 1) printf "%s\n","setrootns"
        for(i=1; i<=NF; i++) {
            if($i == "") continue 
            if($0 ~ /^[^=\/]+=/){
                printf "%s\n", "setns " $i
            } else {
                printf "%s\n", "xpath count(" $i ") > 0"
            }
        }
    }END{ printf "bye\n" }' <<<"$result" | xmllint --shell "${test_type_opts[@]}" 2>&1 | show_errors
}

#---------------------------------------------------------------------------------------
# Run test case for duplicates count
#---------------------------------------------------------------------------------------
test_run_basic_count(){
    ../xml2xpath.sh "${test_opts[@]}" "${test_type_opts[@]}" | wc -l
}
