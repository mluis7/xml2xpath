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
#PS4='+($?) $(date "+%s.%N")\011:$BASH_SOURCE:${FUNCNAME[0]}:$LINENO:'; exec 2>"$dbg_log"; set -x

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
uniq_xp=1
ns_prefix=''
defns=''
fs='¬'
xuuid="x$(uuidgen --sha1 --namespace @url --name "$(hostname)/$script_name")"

# commands as array
lint_cmd=(xmllint --shell)
dbg_cmd=(grep -v '\/ >')
declare -a all_opts

#---------------------------------------------------------------------------------------
# print to stderr
#---------------------------------------------------------------------------------------
function log_error(){
    echo -e "$@" > /dev/stderr
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

function parse_line(){
    while read -r -u 3 xline; do 
        printf "%s\n" "$xline"
        if [ "$xline" == "/ > dir $xuuid" ]; then
            break 
        fi 
    done | sed -E -e :a -e '/^[1-9]/,/^(default|namespace)/ { $!N;s/\n(default|namespace)/¬\1/;ta }' -e 's/^([0-9]{1,5}) *ELEMENT *([^ ]*)/\1¬\2/' -e 's/(default)? ?namespace( [a-z0-9]+)? ?href=([^=]+)/\1\2=\3/g' -e '/^[1-9]/ P;D'  
}

function send_cmd(){
    echo "$1" >&4
}

function print_response(){
    local limit=0
    while IFS=$'\n' read -r -u 3 xline; do
        #read -r -u 3 xline
         printf "%s\n" "$xline"
        ((limit=limit+1))
        if [ "$xline" == "/ > bye" ] || [ -z "$1" ] || [ "$limit" -eq "$1" ]; then
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
# FIXME: kill bg process
        "${lint_cmd[@]}" "$xml_file" 1>&3 <&4 &
        set_root_ns 
        send_cmd "ls /*/namespace::*[local-name()!='xml']"
        send_cmd "ls $xprefix/namespace::*[count(./parent::*/namespace::*)]"
        send_cmd "dir $xuuid"
        send_cmd "du $du_path"
        send_cmd "bye"
        print_response 100000
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
        send_cmd "setrootns"
        if [ -n "$defns" ] ;then
            #echo "setns defaultns="
            send_cmd "setns $defns"
        fi
    fi
}

#---------------------------------------------------------------------------------------
#  Generate elements for unique_ns_arr (unique namespaces), mapping default ones to distinct prefixes.
#---------------------------------------------------------------------------------------
function make_unique_ns_arr(){
    local ni=0
    local nsxx='defaultns'
    if [ -n "${ns_prefix}" ];then
        nsxx="${ns_prefix}"
    fi
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

#---------------------------------------------------------------------------------------
# Find namespace prefix by uri in array from <prefix>=<uri> argument
#---------------------------------------------------------------------------------------
function get_ns_prefix_by_uri(){
    for nu in "${unique_ns_arr[@]}"; do
        # Compare uri
         if [ "${nu#*=}" == "${1#*=}" ]; then
            # return prefix
            echo "${nu%=*}"
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
    for nu in "${unique_ns_arr[@]}"; do
        echo "setns $nu"
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
    if [ -z "$xsd" ] && [ -z "$xml_file" ]; then
        log_error "FATAL: At least one of -d, -l or -x must be provided.\n"
        print_usage
        exit 1
    elif [ -f "$xsd" ] && [ -f "$xml_file" ]; then
        log_error "WARNING: both -d and -x were provided, -d will be ignored.\n"
        xsd=''
    fi
    # Set xpath expression start according to -s option
    if [ '//' = "${du_path:0:2}" ] || [ "$(echo "$du_path" | tr -s '/' ' ' | wc -w)" -gt 1 ] ; then
        xprefix="$du_path"
    else
        xprefix='/'
    fi
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
    g) dbg_cmd=(sed -En '/whereis/ s/^.*/\n&/p; /whereis|^[/] *> *$/! s/^.*/&/p')
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
    v) echo -e "xml2xpath.sh $version \nAuthor: Luis Muñoz"; exit;;
    *) 
       echo "Invalid option $arg"
       print_help
       exit 1;;
  esac
done

fname='xff'
fout='xffout'
trap "rm -f $fname $fout" EXIT

[ ! -p "$fname" ] && mkfifo "$fname"
[ ! -p "$fout" ] && mkfifo "$fout"
stop='dir xxxxxxx'

exec 3<>"$fname"
exec 4<>"$fout"

init_env
if [ -n "$xsd" ]; then
    create_xml_instance
fi

# ################################################
# Start process
# ################################################
echo -e "\nxml2xpath: find XPath expressions on $xml_file"
printf "   %s\n" "${all_opts[@]}" 

# Get XML namespaces and structure with xmllint
# 'dir $xuuid' kinda NoOp that provides a record separator for awk
IFS=$'¬' read -r -d '' -a xml_info < <( get_xml_tree | awk -v fs="$fs" -v ers="dir $xuuid\n" 'BEGIN{ RS=ers }{ print $0 fs }'  && printf '\0' )

# Put all found namespaces in array as <prefix>=<uri>
IFS=$'\n' read -r -d '' -a xml_ns_arr < <(printf "%s\n" "${xml_info[0]}" | sed -nE '/^n +1 / s/^n +1 ([^ ]+) -> ([^ ]+)/\1=\2/p')
#printf ">>>>> %s\n" "${xml_info[0]}"
echo -e "\nNamespaces:"
# make unique_ns_arr array ready for 'setns'
IFS=$'\n' read -r -d '' -a unique_ns_arr < <(printf "%s\n" "${xml_ns_arr[@]}" | make_unique_ns_arr)
printf "%s\n" "${unique_ns_arr[@]}"

xml_tree=$(grep -Ev '^ *$|^\/' <<<"${xml_info[1]}")
if [ -n "$xml_tree" ];then
    
    # Array with elements like <indent level>¬element, e.g. 3¬thead
    IFS=$'\n' read -r -d '' -a xml_tree_ilvl < <(get_xml_tree_ilvl "$xml_tree")
    max_level=$(printf "%s\n" "${xml_tree_ilvl[@]}" | sort -nr -t '¬' | head -n1 | cut -d '¬' -f1)
    declare -a xpath_arr # tmp array to hold tree partially
    declare -a xpath_all # save all found xpath

    # ################################################
    # generate xpaths from tree based on indentation
    # ################################################
    for j in "${!xml_tree_ilvl[@]}"; do
        line=${xml_tree_ilvl[$j]}
        # Get indent level from beginning of array element, e.g. 4¬div
        indent_lvl="${line%¬*}"
        prev_lvl=$((indent_lvl - 1))
        
        ns_pfx=''
        if [ "$isHtml" -eq 0 ] ; then #&& [ "$abs_path" -eq 1 ]
            # xpath expression with no prefix so trying to split the line on ':' returns the same line
            # Element might still belong to a default namespace
            if [ "$line" = "${line%:*}" ] ;then
                ns_pfx="$(get_default_ns_prefix):"

                # namespace prefix not found, try default (may be from -o option)
                if [ -z "$ns_pfx" ] || [ "$ns_pfx" == ':' ]; then
                    ns_pfx="${ns_prefix}:"
                fi
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
        echo -e "XML tree:\n$xml_tree\n"
    fi
    # Print found xpath expressions to stdout
    if [ "$abs_path" -eq 1 ];then
        
        # Show absolute xpath expressions including attributes
        printf "\nFound %d XPath expressions (absolute, unique, use -r to override):\n\n" "${#xpath_all[@]}"
        
        if [ "$isHtml" -eq 1 ]; then
            print_all_xpath | "${lint_cmd[@]}" "$xml_file" | "${dbg_cmd[@]}"
        else
            (set_root_ns; print_all_xpath) | "${lint_cmd[@]}" "$xml_file" | "${dbg_cmd[@]}"
        fi
    else
        # Show xpath expressions
        if [ "${#xpath_all[@]}" -gt 0 ];then
            printf "\nFound %d XPath expressions (unique, use -r to override):\n\n" "${#xpath_all[@]}"
            printf "%s\n" "${xpath_all[@]}" | sort_unique_keep_order
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
rm xff
rm $fout
echo
    
