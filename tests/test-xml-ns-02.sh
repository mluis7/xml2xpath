#!/bin/bash
#
# Example file
# xml2xpath.sh -a -n -o 'xx=http://example.com' -x soap.xml
#
# Namespaces on root element and body - default namespace: http://example.com

# TODO: warning: failed to load external entity

source test-lib-src.sh
dbg=1
xml_file="resources/soap.xml"
test_opts=()
test_type_opts=(-x "$xml_file")
rel_xpath='//incident'

# Test case descriptions
TC01="Basic test (-x)"
TC02="Replace defaulns prefix, relative path"
TC03="Find nodes using namespaces (-n)"
TC04="Find nodes by absolute xpath using namespaces (-a -n)"
TCN01="NEGATIVE TEST - Find nodes by absolute xpath using namespaces (missing -n)"

test_run "TC01"
test_result "$?"

# PASSED: Replace defaulns prefix, relative path
test_opts=(-o 'defns=xxx:http://example.com' -s "${rel_xpath}")
test_run "TC02"
test_result "$?"