#!/bin/bash
#
# Example file
# xml2xpath.sh -a -n -o 'xx=http://example.com' -x soap.xml
#
# Namespaces on root element and body
#   xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
#   xmlns="http://example.com/ns1"
#   xmlns="http://example.com/ns2"
#

script_name=$(basename "$0")
source test-lib-src.sh
xml_file="resources/soap.xml"
test_opts=()
test_type_opts=(-x "$xml_file")
rel_xpath='//incident'

echo_with_pid "*** XML tests - Namespaces on root element and body ($script_name) ***"
# Test case descriptions
TC01="Basic test (-x)"
TC02="Replace default namespace definition (-o), relative path (-s)"

test_run "TC01"
test_result "$?"

# PASSED: Replace defaultns prefix, relative path
test_opts=(-o 'defns=http://example.com/ns2' -s "//defns:incident")
test_run "TC02"
test_result "$?"