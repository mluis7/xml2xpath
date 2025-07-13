#!/bin/bash
#
# Namespaces on root element but no default namespace
#

script_name=$(basename "$0")
source test-lib-src.sh
xml_file="resources/simple.xml"
test_opts=()
test_type_opts=("$xml_file")

echo_with_pid "*** XML tests - simple xml document ($script_name) ***"
# Test case descriptions
TC01="Basic XML test"

test_run "TC01"
test_result "$?"