#!/bin/bash
#
# Find xpath present on an XML file or (if possible) and XSD file.
# source repo: https://github.com/mluis7/xml2xpath
# 

script_name=$(basename "$0")
version="0.10.0"

# Uncomment next 2 lines to write a debug log
# Warning: it may break some tests
#dbg_log="$HOME/tmp/a-sh-debug.log.$$"
#PS4='+($?):$BASH_SOURCE:${FUNCNAME[0]}:$LINENO:'; exec 2>"$dbg_log"; set -x

function version(){
    cat<<EOF-VER
xml2xpath.sh $version
Author: Luis Muñoz
EOF-VER
}

#---------------------------------------------------------------------------------------
# Help.
#---------------------------------------------------------------------------------------
usage_str="$script_name [-h] [-d file -f <tag name>] [-a -g -t -s <xpath>] [-n -p <ns prefix> -o <prefix>=URI -x <file>] [-l <file>]"
function print_help(){
    cat<<EOF-MAN
Print XPath present on xml or (if possible) xsd files. Based on xmllint utility, try to build all possible XPaths from an XML instance. The latter could be constructed from a provided XSD file.

Usage: $usage_str
       $script_name [-h] [COMMON OPTIONS] [XSD OPTIONS] [XML OPTIONS] [HMTL OPTIONS]


Options:

Basic:
  -h    print this help message.
  -v    print version

XML/HTML Common Options:
  -a    Show absolute Xpaths. Use -g too to add details. -s is used to filter but absolute paths are shown.
  -g    Print xmllint command for debugging or clarity. Implies -a.
  -r    Print repeated xpaths when -a is used. For debugging only.
  -s    Start printing XPath at an absolute or relative xpath, e.g.: /shiporder/shipto, //shipto.
          Must contain namespace prefix if needed. e.g.: //defaultns:entry, //xs:element
  -t    print XML element tree as provided by xmllint 'du' shell command.      

HTML options:
  -l    Use HTML parser

XML options:
  -n    Set namespaces found on root element. Default namespace prefix is 'defaultns' but may be overriden with -o option.
  -o    Override the default namespace definition by passing <prefix>=URI, e.g.: -o 'defns=urn:hl7-org:v3'
  -p    Namespace prefix to use. No need to pass -n if used. EXPERIMENTAL.
  -x    xml file, will take precedence over -d option.

XSD options:
  -d    xsd file path.
  -D    Same as -d but saves created xml instance to <xsd file path>.xml
  -f    name of the root element to build xml from xsd.
  
Examples:

  Print all xpaths and elements tree                                xml2xpath.sh -t -x test.xml

  Print xpaths starting at //shipto element                         xml2xpath.sh -s '//shipto' -x test.xml
    
  Print xpaths from generated xml                                   xml2xpath.sh -a -f shiporder -d tests/resources/shiporder.xsd 

  Use namespaces, show absolute paths and xmllint shell messages    xml2xpath.sh -a -n -g -x wiki.xml
    
  Add a namespace definition and use it in a relative expression    xml2xpath.sh -o 'defns=urn:hl7-org:v3' -s '//defns:addr' -x HL7.xml | sort | uniq
    
  Html file with absolute paths option                              xml2xpath.sh -a -n -l test.html

Reporting bugs:
  https://github.com/mluis7/xml2xpath/issues

EOF-MAN
}

function print_usage(){
    echo "Usage: $usage_str"
}

xsd=""
xml_file=""
keep_xml=0
tag1=""
du_path="/"
xprefix=""
isHtml=0
abs_path=0
print_tree=0
max_elements=1100000
uniq_xp=1
ns_prefix=''
defns=''
fs='¬'
xuuid="x$(uuidgen --sha1 --namespace @url --name "$(hostname)/$script_name")"
separator=$(printf '=%.0s' {1..80})

# commands as array
lint_cmd=(xmllint --shell)
dbg_cmd=(grep -v '\/ >')
declare -a all_opts

trap_with_arg() { # from https://stackoverflow.com/a/2183063/804678
  local func="$1"; shift
  for sig in "$@"; do
    trap "$func $sig" "$sig"
  done
}

stop() {
  trap - SIGINT EXIT
  printf '\n%s\n' "received $1, bye!"
  print_separator
  rm -f "$fifo_in" "$fifo_out";
  pkill -f xmllint
  #kill -s SIGINT 0
}

function print_separator(){
    printf "%s (%s)\n" "$separator" "$(date '+%F %T %Z')"
}

#---------------------------------------------------------------------------------------
# print to stderr
#---------------------------------------------------------------------------------------
function log_error(){
    echo -e "$@" >> /dev/stderr
}

#---------------------------------------------------------------------------------------
# generate XML from XSD. Requires xmlbeans package.
#---------------------------------------------------------------------------------------
function create_xml_instance(){
    if [ ! -x /usr/bin/xsd2inst ]; then
        log_error "FATAL: packages xmlbeans, xmlbeans-scripts are not installed but are required for -d option. Aborting."
        exit 1
    fi
    if [ -z "$xsd" ]; then
        log_error "FATAL: XSD file path can not be empty if -d option is used."
        exit 1
    fi
    if [ -z "$xml_file_tmp" ]; then
        xml_file_tmp=$(mktemp)
    fi
    echo -e "Creating XML instance starting at element $tag1 from $xsd\n"
    XMLBEANS_LIB='/usr/share/java/xmlbeans/' xsd2inst "$xsd" -name "$tag1" > "$xml_file_tmp"
    xml_file="$xml_file_tmp"
}

#---------------------------------------------------------------------------------------
# Set xmllint HTML options
#---------------------------------------------------------------------------------------
function set_html_opts(){
    isHtml=1
    lint_cmd[${#lint_cmd[@]}]="--nowrap"
    lint_cmd[${#lint_cmd[@]}]="--recover"
    lint_cmd[${#lint_cmd[@]}]="--html"
}

function parse_ns_from_xpath(){
    while read -r -u 3 xline; do 
        printf "%s\n" "$xline"
        if [ "$xline" == "/ > dir $xuuid" ]; then
            break 
        fi 
    done | sed -E -e :a -e '/^[1-9]/,/^(default|namespace)/ { $!N;s/\n(default|namespace)/¦\1/;ta }' \
                  -e 's/^([0-9]{1,8}) *ELEMENT *([^ ]*)/\1¦\2/' \
                  -e 's/(default)? ?namespace ([a-z0-9]+)? ?href=([^=]+)¦?/\1\2=\3/g' \
                  -e '/^[1-9]/ P;D'  
}

function send_cmd(){
    echo -e "$1" >&4
}

function stop_reading(){ 
    [[ "$3" == "/ > bye" ]] || [[ -z "$1" || "$1" -eq "$2" ]]
}

function print_response(){
    local limit=0
    local how_many=1
    [ -n "$1" ] && how_many="$1"
    
    while IFS=$'\n' read -r -u 3 xline; do
         printf "%s\n" "$xline"
        ((limit=limit+1))
        if [ "$xline" == "/ > dir $xuuid" ] || stop_reading "$how_many" "$limit" "$xline" ; then
            break 
        fi 
    done
}

#---------------------------------------------------------------------------------------
# Get elements tree as provided by xmllint 'du' xmllint shell command 
# and get all namespaces as provided by 'ls //namespace::*' xmllint shell command
#---------------------------------------------------------------------------------------
function get_xml_tree(){
    if [ -n "$xml_file" ]; then
        "${lint_cmd[@]}" "$xml_file" 1>&3 <&4 &
        
        # send commands to xmllint shell
        set_root_ns >&4

        if [ $isHtml -eq 0 ]; then
            # xpath command contains namespace declaration at the node
            #   so it will be used to make a lookup array since it provides element index.
            send_cmd "xpath //*"
            send_cmd "dir $xuuid"
            parse_ns_from_xpath
            send_cmd "dir $xuuid"
            print_response "$max_elements"
        else
            send_cmd "\ndir $xuuid"
            print_response 2
        fi
       
        # namespaces at root element
        send_cmd "ls /*/namespace::*[local-name()!='xml']"
        # namespaces at root element descendants. Provides full length uris.
        send_cmd "ls /*//*/namespace::*[local-name()!='xml'][count(./parent::*/namespace::*[local-name()!='xml'])]"
        send_cmd "dir $xuuid"
        print_response "$max_elements"
        
        send_cmd "du $du_path"
        send_cmd "dir $xuuid"
        print_response "$max_elements"
        send_cmd "bye"
    else
        log_error "ERROR: No XML file. Either provide an XSD to create an instance from (-d option) or pass the path to an XML valid file"
        exit 1
    fi
}

#---------------------------------------------------------------------------------------
# Return tree elements in the form <indent level>¬element, e.g. 3¬thead
#---------------------------------------------------------------------------------------
function get_xml_tree_ilvl(){
    printf "%s\n" "$1" | gawk '{ $0=gensub(/( *)([^ ]+)/, "\\1¬\\2","g",$0); split($0, a, /¬/); print length(a[1])/2 "¬" a[2] }'
}

#---------------------------------------------------------------------------------------
# Set namespaces present on root element
#---------------------------------------------------------------------------------------
function set_root_ns(){
    if [ -n "$ns_prefix" ];then
        echo "setrootns"
        if [ -n "$defns" ] ;then
            echo "setns defaultns="
            #extns=( $(tr ',' ' ' <<<"$defns") )
            OLD_IFS="$IFS"
            IFS=$'¦' read -r -a extns <<<"$defns"
            IFS=$"$OLD_IFS"
            for n in "${extns[@]}"; do
                echo "setns $n"
            done
            defns="${extns[0]}"
        fi
    fi
}

#---------------------------------------------------------------------------------------
#  Generate elements for unique_ns_arr (unique namespaces), mapping default ones to distinct prefixes.
#---------------------------------------------------------------------------------------
function make_unique_ns_arr(){
    local ni=0
    local nsxx='defaultns'
#    if [ -n "${ns_prefix}" ];then
#        nsxx="${ns_prefix}"
#    fi
    sort_unique_keep_order | while IFS= read -r name_uri; do
        case "${name_uri%%=*}" in
           default)
                # -o ; if uri matches, override ns
                if [ "${defns##*=}" == "${name_uri##*=}" ]; then
                    echo "${defns}"
                elif [ "$ni" -gt 0 ]; then
                    echo "${nsxx}${ni}=${name_uri##*=}"
                else
                    echo "${nsxx}=${name_uri##*=}"
                fi
                ((ni=ni+1))
                ;;
           *) echo "$name_uri" ;;
       esac
    done
}

function get_ns_by_short_uri(){
    for nu in "${root_ns_arr[@]}"; do
        local query="${1}"
        local uri="${nu#*=}"
         if [ "${uri:0:40}" == "${query:0:40}" ];then
            echo "${nu}"
            break
         fi
    done
}

#---------------------------------------------------------------------------------------
# Find namespace prefix by uri in array from <prefix>=<uri> argument
#---------------------------------------------------------------------------------------
function get_ns_prefix_by_uri(){
    for nu in "${unique_ns_arr[@]}"; do
        local query="${1#*=}"
        local uri="${nu#*=}"
        local prefix="${nu%=*}"
        # Compare uri
         if [ "${uri}" == "${query}" ]; then
            # return prefix
            echo "${prefix}"
            break
         elif [[ "${query}" =~ \.\.\.$ ]] && [ "${uri:0:40}" == "${query:0:40}" ];then
            # should not be needed
            echo "${prefix}"
            break
         fi
    done
}

#---------------------------------------------------------------------------------------
# Find first default namespace prefix in array
#---------------------------------------------------------------------------------------
function get_default_ns_prefix(){
    for nu in "${unique_ns_arr[@]}"; do
        # Compare uri
         if [ "${nu%=*}" == "defaultns" ]; then
            # return renamed prefix
            get_ns_prefix_by_uri "${nu}"
            break
         fi
    done
}

#---------------------------------------------------------------------------------------
# Print all xpaths
#---------------------------------------------------------------------------------------
function print_all_xpath(){
    # set all root namespaces
    for nu in "${root_ns_arr[@]}"; do
        [ -n "$nu" ] && echo "setns $nu"
    done
    # set other namespaces found
    for nu in "${unique_ns_arr[@]}"; do
        [ -n "$nu" ] && echo "setns $nu"
    done
    for i in "${!xpath_all[@]}"; do
        printf "whereis %s\nwhereis %s/@*\n" "${xpath_all[$i]}" "${xpath_all[$i]}"
    done | print_unique_xpath
}

#---------------------------------------------------------------------------------------
# Print unique xpaths keepeing original order
#---------------------------------------------------------------------------------------
function print_unique_xpath(){
    if [ "$uniq_xp" -eq 1 ] ; then
        sort_unique_keep_order
    else
        cat
    fi
}

#---------------------------------------------------------------------------------------
# Get unique keepeing original order
# b -> b
# c    c
# b    a
# a
#---------------------------------------------------------------------------------------
function sort_unique_keep_order(){
    nl -s "$fs" -nln | tr -s -d '\011\r' ' ' | sort -t "$fs" -k2,2 | uniq --skip-fields=1 | sort -t "$fs" -n -k1,1 | cut -d "$fs" -f2,3
}

#---------------------------------------------------------------------------------------
# Check initial conditions
#---------------------------------------------------------------------------------------
function init_env(){
    if [[ -z "$xml_file"  || !  -f "$xml_file" ]] && [[ -z "$xsd"  || ! -f "$xsd" ]]; then
        log_error "FATAL: At least one of -d, -l or -x must be provided and be an existing file.\n"
        print_usage
        exit 1
    fi
    if [ -f "$xsd" ] && [ -f "$xml_file" ]; then
        log_error "WARNING: both -d and -x were provided, -d will be ignored.\n"
        xsd=''
    fi
    # Set xpath expression start according to -s option
    if [ '//' = "${du_path:0:2}" ] || [ "$(echo "$du_path" | tr -s '/' ' ' | wc -w)" -gt 1 ] ; then
        xprefix="$du_path"
    else
        xprefix='/'
    fi

    fifo_in='xffin'
    fifo_out='xffout'
    trap_with_arg 'stop' EXIT SIGINT SIGTERM SIGHUP
    
    [ ! -p "$fifo_in" ] && mkfifo "$fifo_in"
    [ ! -p "$fifo_out" ] && mkfifo "$fifo_out"
    
    exec 3<>"$fifo_in"
    exec 4<>"$fifo_out"
}

function clean_tmp_files(){
    if [ "$keep_xml" -eq 0 ] && [ -f "$xml_file_tmp" ]; then
        rm "$xml_file_tmp"
    fi
}

while getopts ad:D:f:ghl:no:p:rs:tx:v arg
do
  case $arg in
    a) abs_path=1
       all_opts[${#all_opts[@]}]="-a ; abs_path=$abs_path" 
        ;;
    h) print_help; exit;;
    d) xsd=$OPTARG
       all_opts[${#all_opts[@]}]="-d"
       ;;
    D) xsd=$OPTARG
       xml_file_tmp="${xsd}.xml"
       keep_xml=1
       ;;
    f) tag1=$OPTARG
       all_opts[${#all_opts[@]}]="-f ; tag1=$tag1"
        ;;
    g) dbg_cmd=(sed -En '/whereis/ s/^[/] > whereis (.*)/\nSearch: \1/p; /whereis|^([/] >)? *$/! s/^[/][^ ].*/&/p')
        abs_path=1
        all_opts[${#all_opts[@]}]="-g ; abs_path=$abs_path ; debug command: '$dbg_cmd'"
        ;;
    n|p) [ -n "$OPTARG" ] && ns_prefix=$OPTARG && all_opts[${#all_opts[@]}]="-p ; ns prefix=$ns_prefix"
         [ -z "$OPTARG" ] && ns_prefix="defaultns" && all_opts[${#all_opts[@]}]="-n ; default ns prefix: $ns_prefix"
        ;;
    o) defns="$OPTARG"
        ns_prefix=$(cut -d '=' -f1 <<<"$defns")
        all_opts[${#all_opts[@]}]="-o ; ns prefix: $ns_prefix ; default ns override: $defns"
        ;;
    r) uniq_xp=0;;
    s) du_path=$OPTARG
       all_opts[${#all_opts[@]}]="-s ; Start tree at: '$du_path' (du_path)"
        ;;
    
    t) print_tree=1
        all_opts[${#all_opts[@]}]="-t"
        ;;
    l) 
        xml_file=$OPTARG
        set_html_opts
        all_opts[${#all_opts[@]}]="-l ; HTML file: $xml_file"
        ;;
    x) xml_file=$OPTARG
        all_opts[${#all_opts[@]}]="-x ; XML file: $xml_file"
        ;;
    v) version; exit;;
    *) 
       echo "Invalid option $arg"
       print_help
       exit 1;;
  esac
done

init_env
if [ -n "$xsd" ]; then
    create_xml_instance
fi

# ################################################
# Start process
# ################################################
echo -e "\nxml2xpath: find XPath expressions on $xml_file"
print_separator
echo
printf "   %s\n" "${all_opts[@]}" 

# Get XML namespaces and doc tree with xmllint
# 'dir $xuuid' kinda NoOp that provides a record separator for awk
IFS=$'¬' read -r -d '' -a xml_info < <( get_xml_tree | awk -v fs="$fs" -v ers="dir $xuuid\n" 'BEGIN{ RS=ers }{ print $0 fs }'  && printf '\0' )

# Put all found namespaces in array as <prefix>=<uri>
IFS=$'\n' read -r -d '' -a root_ns_arr < <(printf "%s\n" "${xml_info[1]}" | sed -nE '/^n +1 / s/^n +1 ([^ ]+) -> ([^ ]+)/\1=\2/p' | sort_unique_keep_order)

declare -a arrns
#arrns+=( "${root_ns_arr[@]}" )
#arrns[0]="${root_ns_arr[0]}"
while IFS=$'\n' read -r line;do
    OLD_IFS="$IFS"
    IFS=$'¦' read -r -a elem <<<"$line"
    IFS=$"$OLD_IFS"
  
    if [ "${elem[2]}" == "xml=http://www.w3.org/XML/1998/namespace" ] || [[ ! "${elem[0]}" =~ [[:digit:]]{1,} ]];then
        continue
    fi
    ((k=elem[0]-1))

    # xpath command may truncate uri to around 40 characters
    if [ -n "${elem[2]}" ] && [[ "${elem[2]}" =~ \.\.\.$ ]];then
        # try to find full uri on root_ns_arr
        lu="$(get_ns_by_short_uri "${elem[2]#*=}")"
        arrns[$k]="$lu"
    # element start with a number, a known one
    elif [ -n "${elem[2]}" ] && [[ "${elem[0]}" =~ [[:digit:]]{1,} ]];then
        arrns[$k]="${elem[2]}"
    fi
done < <(printf "%s\n" "${xml_info[0]}" && printf '\0')
print_separator
# make unique_ns_arr array ready for 'setns'
IFS=$'\n' read -r -d '' -a unique_ns_arr < <(printf "%s\n" "${arrns[@]}" | make_unique_ns_arr | grep -v '^ *$')
if [ "${#root_ns_arr[@]}" -gt 0 ] || [ "${#unique_ns_arr[@]}" -gt 0 ];then 
    echo -e "\nRoot Namespaces:"
    printf "  %s\n" "${root_ns_arr[@]}"
    print_separator
    echo -e "\nMapped Namespaces:"
    printf "  %s\n" "${unique_ns_arr[@]}"
else
    printf "\nNamespaces: None\n"
fi
print_separator

xml_tree=$(grep -Ev '^ *$|^\/' <<<"${xml_info[2]}")
if [ -n "$xml_tree" ];then
    
    # Array with elements like <indent level>¬element, e.g. 3¬thead
    IFS=$'\n' read -r -d '' -a xml_tree_ilvl < <(get_xml_tree_ilvl "$xml_tree")
    max_level=$(printf "%s\n" "${xml_tree_ilvl[@]}" | sort -nr -t '¬' | head -n1 | cut -d '¬' -f1)
    declare -a xpath_arr # tmp array to hold tree partially
    declare -a xpath_all # save all found xpath
printf "\nElements to process (build xpath, add prefix) %d\n" "${#xml_tree_ilvl[@]}"
    # ################################################
    # generate xpaths from tree based on indentation
    # ################################################
    ns_pfx=''
    prev_ns_pfx=''
    prev_ns_lvl=0
    declare -a ns_by_indent_lvl
    for j in "${!xml_tree_ilvl[@]}"; do
        line=${xml_tree_ilvl[$j]}
        if [ "$j" -le 0 ]; then
            prev_line=''
            prev_line_lvl=0
        else
            prev_line="${xml_tree_ilvl[$j-1]}"
            prev_line_lvl="${prev_line%¬*}"
        fi
        
        # Get indent level from beginning of array element, e.g. 4¬div
        indent_lvl="${line%¬*}"
        prev_lvl=$((indent_lvl - 1))
        
        if [ "$isHtml" -eq 0 ] && [ "$abs_path" -eq 1 ] && [ "${#unique_ns_arr[@]}" -gt 0 ]; then
            # xpath expression with no prefix so trying to split the line on ':' returns the same line
            # Element might still belong to a default namespace
            if [ "$line" = "${line%:*}" ] ;then
                if [ -n "${arrns[$j]}" ]; then
                    ns_pfx="$(get_ns_prefix_by_uri "${arrns[$j]}"):"
                    ns_by_indent_lvl[$indent_lvl]="${arrns[$j]}"
                elif [ -z "${arrns[$j]}" ] && [ "$indent_lvl" -gt "$prev_ns_lvl" ]; then
                    ns_by_indent_lvl[$indent_lvl]="${ns_by_indent_lvl[$prev_lvl]}"
                    ns_pfx="$(get_ns_prefix_by_uri "${ns_by_indent_lvl[$prev_lvl]}"):"
                fi
                # namespace prefix not found, try getting the last know at this tree level 
                #  or the default (may be from -o option)
                if [[ -z "$ns_pfx" || "$ns_pfx" == ':' ]]; then
                    ns_pfx="${ns_prefix}:"
                fi
            else
                ns_pfx=''
            fi
        fi
    
        if [ "$indent_lvl" -eq 0 ] ; then
            if [ "$du_path" == '/' ]; then
                #no indent level, xpath root
                xpath_arr[0]="${ns_pfx}${line#*¬}"
                xpath="${xpath_arr[0]}"
            elif [ "$du_path" != '/' ]; then
                # an xpath expression has been provided with -s so first element is discarded
                # as $prefix will supply the beginning of the expression.
                xpath_arr[0]=""
                xpath="${xpath_arr[0]}"
            fi
        elif [ "$indent_lvl" -gt 0 ] && [ "$indent_lvl" -le "$max_level" ]; then
            # append element to previous by indentation level
            xpath="${xpath_arr[$prev_lvl]}/${ns_pfx}${line#*¬}"
            # store current xpath
            xpath_arr[$indent_lvl]="${xpath}"
        fi
    
        idx=${#xpath_all[@]}
        xpath_all[$idx]="${xprefix}${xpath}"
    done

    # -t option was passed, show tree as is.
    if [ "$print_tree" -eq 1 ]; then
        echo -e "\nXML tree:\n$xml_tree\n"
    fi
    # Print found xpath expressions to stdout
    if [ "$abs_path" -eq 1 ];then
        # Show absolute xpath expressions including attributes
        printf "\nXPath expressions found: %d (absolute, unique elements, use -r to override)\n" "${#xpath_all[@]}"
        print_separator
        printf '\n'
        
        if [ "$isHtml" -eq 1 ]; then
            print_all_xpath | "${lint_cmd[@]}" "$xml_file" | "${dbg_cmd[@]}"
        else
            (set_root_ns; print_all_xpath) | "${lint_cmd[@]}" "$xml_file" | "${dbg_cmd[@]}"
        fi
    else
        # Show xpath expressions
        if [ "${#xpath_all[@]}" -gt 0 ];then
            ret=$(printf "%s\n" "${xpath_all[@]}" | sort_unique_keep_order)
            uniq_count=$(printf "%s\n" "$ret" | sort_unique_keep_order | wc -l)
            printf "\nXPath expressions found: %d (%d unique elements, use -r to override)\n" "${#xpath_all[@]}" "$uniq_count"
            printf "%s\n" "$ret"
        else
            log_error "ERROR: should have not happened but the code reached here :-("
            clean_tmp_files
            exit 1
        fi
    fi
else
    log_error "No xpath found"
    clean_tmp_files
    exit 127
fi
exec 3>&-
exec 4>&-
rm $fifo_in
rm $fifo_out
echo
    
