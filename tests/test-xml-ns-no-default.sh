#!/bin/bash
#
# Namespaces on root element but no default namespace
#

script_name=$(basename "$0")
source test-lib-src.sh
xml_file="resources/nodefaultns.xml"
test_opts=()
test_type_opts=(-x "$xml_file")

echo "*** XML tests - namespaces on root element but no default ns ($script_name) ***"
# Test case descriptions
TC01="Basic test (-x)"

test_run "TC01"
test_result "$?"