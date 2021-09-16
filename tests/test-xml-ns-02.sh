#!/bin/bash
#
# Example file
# xml2xpath.sh -a -n -o 'xx=http://example.com' -x soap.xml
#
# Namespaces on root element and body - default namespace: http://example.com

source test-lib-src.sh
xml_file="resources/soap.xml"
test_opts=()
test_type_opts=(-x "$xml_file")
rel_xpath='//incident'

echo "*** XML tests - Namespaces on root element and body ***"
# Test case descriptions
TC01="Basic test (-x)"
TC02="Replace defaulns prefix, relative path"

test_run "TC01"
test_result "$?"

# PASSED: Replace defaulns prefix, relative path
test_opts=(-o 'defns=http://example.com' -s "//defns:incident")
test_run "TC02"
test_result "$?"