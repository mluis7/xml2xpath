#!/bin/bash

print_help(){
cat <<EOFH
Count nodes found with xml2xpath.sh as is; sets namespaces if found.
Zero nodes count means something went wrong with xpath generation.
Receives same options as xml2xpath, -q is required and will be added if not present.
Examples:
  Raw output:
    ./count_test.sh -n -p "ns" -x tests/resources/soap.xml
  Errors only:
    ./count_test.sh -n -p 'ns' -x tests/resources/HL7.xml | grep -iE 'error|number : 0$'
EOFH
}

#---------------------------------------------------------------------------------------
# Set xmllint HTML options
#---------------------------------------------------------------------------------------
set_html_opts(){
    isHtml=1
    lint_cmd[${#lint_cmd[@]}]="--nowrap"
    lint_cmd[${#lint_cmd[@]}]="--recover"
    lint_cmd[${#lint_cmd[@]}]="--html"
}

#---------------------------------------------------------------------------------------
# Generic wrapper to read from stdin with timeout.
# First argument is the command to pipe stdin to.
#---------------------------------------------------------------------------------------
while_read_wrapper(){
	cmd="$1"
	while IFS= read -r -t 3 line; do
		printf "%b\n" "$line"
	done | "$1"
}

#---------------------------------------------------------------------------------------
# Generate xmllint --shell commands from xml2xpath.sh -q output
#---------------------------------------------------------------------------------------
get_shell_commands(){
	gawk 'BEGIN{RS="\n\n";FS="\n"}
    {
        if(NR == 1) printf "%s\n","setrootns"
        for(i=1; i<=NF; i++) {
            if($i == "") continue 
            if($0 ~ /^[^=\/]+=/){
                printf "%s\n", "setns " $i
            } else {
                printf "%s\n", "xpath count(" $i ")"
            }
        }
    }END{ printf "bye\n" }'
}

# options to xmllint command
declare -a lint_cmd
# options to xml2xpath.sh command
declare -a rem_opts
rem_opts+=("-q")

while getopts ad:D:f:ghl:no:p:qrs:tx:v arg
do
  case $arg in
    h) print_help; exit;;
    l) 
        xml_file=$OPTARG
        set_html_opts
        rem_opts+=("-l" "$xml_file")
        ;;
    x) xml_file=$OPTARG
        lint_cmd+=("$xml_file")
        rem_opts+=("-$arg" "$xml_file")
        ;;
    a|d|D|f|g|n|o|p|q|r|s|t|v)
    	rem_opts+=("-$arg")
    	[ -n "$OPTARG" ] && rem_opts+=("$OPTARG") 
    	;;
    *) 
       echo "Invalid option"
       print_help
       exit 1;;
  esac
done

if [ -z "$xml_file" ];then
	shift $((OPTIND - 1))
	rem_opts+=("-x" "$1")
	lint_cmd+=("$1")
fi

xml2xpath.sh "${rem_opts[@]}" | get_shell_commands | xmllint --shell "${lint_cmd[@]}" 2>&1 

