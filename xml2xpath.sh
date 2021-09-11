#!/bin/bash
#
# Find xpath present on an XML file or (if possible) and XSD file.
# source repo: https://github.com/mluis7/xml2xpath
# 

script_name=$(basename "$0")

# Uncomment next 2 lines to write a debug log
#dbg_log="$HOME/tmp/a-sh-debug.log.$$"
#PS4='+($?) $BASH_SOURCE:${FUNCNAME[0]}:$LINENO:'; exec 2>"$dbg_log"; set -x


#---------------------------------------------------------------------------------------
# Help.
#---------------------------------------------------------------------------------------
function print_help(){
	cat<<EOF-MAN
NAME
  $script_name - Print XPath present on xml or (if possible) xsd files.

SYNOPSIS
  $script_name [-h] [COMMON OPTIONS] [XSD OPTIONS] [XML OPTIONS] [HMTL OPTIONS]
  $script_name [-h] [-d file -f <tag name>] [-a -g -t -s <xpath>] [-n -p <ns prefix> -x <file>] [-l <file>]

DESCRIPTION
 Based on xmllint utility, try to build all possible XPaths from an XML instance. The latter could be constructed from a provided XSD file. 

OPTIONS
  Basic options
     -h   print this help message.
  XSD options
     -d   xsd file path.
     -D   Same as -d but saves created xml instance to <xsd file path>.xml
     -f   name of the root element to build xml from xsd.

  XML/HTML Common Options
    -a   Show absolute Xpaths. Use -g too to add details. -s is used to filter but absolute paths are shown.
    -g   Print xmllint command for debugging or clarity.
    -r   Print repeated xpaths when -a is used. For debugging only.
    -s   Start printing XPath at an absolute or relative xpath, e.g.: /shiporder/shipto ,//shipto
          Must contain namespace prefix if needed. Examples: //defaultns:entry, //xs:element
    -t   print XML element tree as provided by xmllint 'du' shell command.
          
  HTML options
     -l   Use HTML parser

  XML options
     -n   Set namespaces found on root element. Default namespace prefix is 'defaultns' but may be overriden with -o option.
     -o   Override the default namespace definition by passing <prefix>=URI, e.g.: -o 'defns=urn:hl7-org:v3'
     -p   Namespace prefix to use. No need to pass -n if used. EXPERIMENTAL.
     -x   xml file, will take precedence over -d option.
     
EXAMPLES
	# print all xpaths and elements tree
	xml2xpath.sh -t -x test.xml
	
	# print xpaths starting at //shipto element
	xml2xpath.sh -s '//shipto' -x test.xml
	
	# print xpaths from generated xml
	xml2xpath.sh -d test.xsd -f shiporder
	
	# Use namespaces, show absolute paths and xmllint shell messages
	xml2xpath.sh -a -n -g -x wiki.xml
	
	# Add a namespace definition and use it in a relative expression
	xml2xpath.sh -o 'defns=urn:hl7-org:v3' -s '//defns:addr' -x HL7.xml | sort | uniq
	
	# Html file with absolute paths option
	xml2xpath.sh -a -n -l test.html

REPORTING BUGS
        at: https://github.com/mluis7/xml2xpath

AUTHOR
       Written by Luis Muñoz

SEE ALSO
       Full documentation at: https://github.com/mluis7/xml2xpath
EOF-MAN
}

function print_usage(){
	echo "Usage: $script_name [-h] [-a -g] [-d file -f <tag name>] [-n -p <ns prefix> -x <file> -t] [-l <file>]"
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
ns_cmd='cat'
ns_prefix=''
defns=''
lint_cmd=(xmllint --shell)
dbg_cmd=(grep -v '\/ >')

#---------------------------------------------------------------------------------------
# get white space indentation as multiple dots, count them and divide by 2
#---------------------------------------------------------------------------------------
function space2dots(){
	sed -nre '/^ / s/^( +).*/\1/p' | tr ' ' '.'
}

#---------------------------------------------------------------------------------------
# get white space indentation as multiple dots, count them and divide by 2
#---------------------------------------------------------------------------------------
function get_indent_level(){
    for c in $(echo "$@" | space2dots | sort | uniq); do
        echo $((${#c}/2)) 
    done
}

#---------------------------------------------------------------------------------------
# generate XML from XSD. Requires xmlbeans package.
#---------------------------------------------------------------------------------------
function create_xml_instance(){
	if [ ! -x /usr/bin/xsd2inst ]; then
		echo "FATAL: packages xmlbeans, xmlbeans-scripts are not installed but are required for -d option. Aborting." > /dev/stderr
		exit 1
	fi
	if [ -z "$xsd" ]; then
		echo -e "FATAL: XSD file path can not be empty if -d option is used." > /dev/stderr
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

#---------------------------------------------------------------------------------------
# Get elements tree as provided by xmllint 'du' command 
#---------------------------------------------------------------------------------------
function get_xml_tree(){
	if [ -n "$xml_file" ]; then
		(set_ns_prefix; echo "du $du_path") | "${lint_cmd[@]}" "$xml_file" | grep -v '\/[^ >]*'
	else
		echo "ERROR: No XML file. Either provide an XSD to create an instance from (-d option) or pass the path to an XML valid file" > /dev/stderr
		exit 1
	fi
}

#---------------------------------------------------------------------------------------
# Print all xpaths
#---------------------------------------------------------------------------------------
function add_namespace_prefix(){
	while read -r line; do
		if [ -n "$ns_prefix" ]; then
			# xpath expression with no prefix
			if ! grep -q ':' <<<"$line" ;then
				sed -re "s/([/][/]?)([^/@]+)/\1${ns_prefix}:\2/g" <<<"$line"
			else
				idxx=2
				if grep -q '^[/][/]' <<<"$line"; then
					idxx=3
				fi
				echo "$line" | gawk -v pr="${ns_prefix}" -v idx="$idxx" 'BEGIN{FS="[/]"; OFS="/"}{for(i=idx; i<=NF; i++) {if($i !~ /[@:]/){ $i = pr ":" $i}}} END { print $0 }'
			fi
		else
			echo "$line"
		fi
	done
}

#---------------------------------------------------------------------------------------
# Set namespaces
#---------------------------------------------------------------------------------------
function set_ns_prefix(){
	if [ -n "$ns_prefix" ];then
		echo "setrootns"
		if [ -n "$defns" ] ;then
			echo "setns defaultns="
			echo "setns $defns"
		fi
	else
		echo
	fi
}

#---------------------------------------------------------------------------------------
# Print all xpaths
#---------------------------------------------------------------------------------------
function print_all_xpath(){
	if [ "$uniq_xp" -eq 1 ] ; then
 		print_unique_xpath
	else
		for pth in "${xpath_all[@]}"; do
			if [ "$isHtml" -eq 0 ]; then
				fixedPath="$(echo "$pth" | add_namespace_prefix)"
			else
				fixedPath="$pth"
			fi
	        printf "whereis %s\nwhereis %s/@*\n" "${fixedPath}" "${fixedPath}"
	    done 
	fi
}

#---------------------------------------------------------------------------------------
# Print unique xpaths keepeing original order
#---------------------------------------------------------------------------------------
function print_unique_xpath(){
    for pth in "${xpath_all[@]}"; do
    	if [ "$isHtml" -eq 0 ]; then
			fixedPath="$(echo "$pth" | add_namespace_prefix)"
		else
			fixedPath="$pth"
		fi
		printf "whereis %s\nwhereis %s/@*\n" "${fixedPath}" "${fixedPath}"
    done | nl -nln | tr -s -d '\011\r' ' ' | sort -k3,3 | uniq --skip-fields=2 | sort -n -k1,1 | cut -d ' ' -f2,3
}

#---------------------------------------------------------------------------------------
# Check initial conditions
#---------------------------------------------------------------------------------------
function init_env(){
	if [ -z "$xsd" ] && [ -z "$xml_file" ]; then
		echo -e "FATAL: At least one of -d or -x must be provided.\n" > /dev/stderr
		print_usage
		exit 1
	elif [ -f "$xsd" ] && [ -f "$xml_file" ]; then
		echo -e "WARNING: both -d and -x were provided, -d will be ignored.\n" > /dev/stderr
		xsd=''
	fi
	if grep -q '^[/][/]' <<<"$du_path" || [ "$(echo "$du_path" | tr -s '/' ' ' | wc -w)" -gt 1 ] ; then
		xprefix='//'
	else
		xprefix='/'
	fi
}

while getopts ad:D:f:ghl:no:p:rs:tx: arg
do
  case $arg in
    a) abs_path=1;;
    h) print_help; exit;;
	d) xsd=$OPTARG
       ;;
	D) xsd=$OPTARG
       xml_file_tmp="${xsd}.xml"
       keep_xml=1
       ;;
	f) tag1=$OPTARG;;
	g) dbg_cmd=(cat);;
	n|p) [ -n "$OPTARG" ] && ns_prefix=$OPTARG
		 [ -z "$OPTARG" ] && ns_prefix="defaultns"
        ;;
    o) defns="$OPTARG"
    	ns_prefix=$(cut -d '=' -f1 <<<"$defns")
    	;;
    r) uniq_xp=0;;
	s) du_path=$OPTARG;;
	t) print_tree=1;;
	l) 
        xml_file=$OPTARG
		set_html_opts
        ;;
	x) xml_file=$OPTARG;;
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
# get elements tree with xmllint
xml_tree=$(get_xml_tree)

if [ "$print_tree" -eq 1 ]; then
	echo -e "XML tree:\n$xml_tree\n"
fi

indent_levels=$(get_indent_level "$xml_tree")
max_level=$(echo "$indent_levels" | tail -n1)
declare -a xpath_arr # tmp array to hold tree partially
declare -a xpath_all # save all found xpath

# generate xpaths from tree based on indentation
while IFS='' read -r line; do
    indent=$(echo "$line" | space2dots)
    # divide by 2 since xmllint uses 2 spaces to indent.
    # Only indentation level is needed, no the indentation itself.
    indent_lvl=$((${#indent}/2))
    prev_lvl=$((indent_lvl - 1))

    if [ "$indent_lvl" -eq 0 ]; then
        #no indent level, xpath root
        xpath_arr[0]="$line"
        xpath="${xpath_arr[0]}"
    elif [ "$indent_lvl" -le "$max_level" ]; then
        # append element to previous by indentation level
        xpath="${xpath_arr[$prev_lvl]}/$(echo "$line" | tr -d ' ')"
        # store current xpath
        xpath_arr[$indent_lvl]="${xpath}"
    fi

	idx=${#xpath_all[*]}
	xpath_all[$idx]="${xprefix}${xpath}"
done < <(echo "$xml_tree")

#printf ">>>> %s\n" "${xpath_all[@]}"

# Show absolute xpath including attributes
if [ "$abs_path" -eq 1 ];then
    echo -e "\nFound Xpath (absolute):\n"
    if [ "$isHtml" -eq 1 ]; then
    	print_all_xpath | "${lint_cmd[@]}" "$xml_file" | "${dbg_cmd[@]}"
    else
        (set_ns_prefix ; print_all_xpath) | "${lint_cmd[@]}" "$xml_file" | "${dbg_cmd[@]}"
    fi
else
    echo -e "Found XPath:\n"
    printf "%s\n" "${xpath_all[@]}"
fi
echo
	
if [ "$keep_xml" -eq 0 ] && [ -f "$xml_file_tmp" ]; then
	rm "$xml_file_tmp"
fi
