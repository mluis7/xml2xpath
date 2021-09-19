#!/bin/bash
#
# Test file from:
# https://github.com/HL7/C-CDA-Examples/blob/master/General/Parent%20Document%20Replace%20Relationship/CCD%20Parent%20Document%20Replace%20(C-CDAR2.1).xml
#
# Namespaces on root element, default namespace: urn:hl7-org:v3

source test-lib-src.sh
xml_file="resources/HL7.xml"
test_opts=()
test_type_opts=(-x "$xml_file")
rel_xpath='/defaultns:ClinicalDocument/defaultns:recordTarget'

echo "*** XML tests - namespaces on root element ***"
# Test case descriptions
TC01="Basic test (-x)"
TC02="Replace 'defaultns' prefix (-o), start at relative path (-s)"
TC03="Find nodes using namespaces (-n)"
TC04="Find nodes by absolute xpath using namespaces (-a -n)"
TCN01="NEGATIVE TEST - Find nodes by absolute xpath using namespaces (missing -n)"

test_run "TC01"
test_result "$?"

# PASSED: Replace 'defaultns' prefix, relative path
test_opts=(-o 'defns=urn:hl7-org:v3' -s '//defns:addr')
#xml2xpath.sh "${test_opts[@]}" -x "$xml_file" | grep -q 'XPath error'
test_run "TC02"
test_result "$?"

# PASSED: Find nodes using namespaces (-n)
test_opts=(-n -s "${rel_xpath}")
test_run "TC03"
test_result "$?"

# PASSED: Find nodes by absolute xpath using namespaces (-a -n)
# FIXME: absolute path turned into relative 'whereis /defaultns:recordTarget'
# xml2xpath.sh -a -g -n -s '/defaultns:ClinicalDocument/defaultns:recordTarget' -x HL7.xml
test_opts=(-a -n -s "${rel_xpath}")
test_run "TC04"
test_result "$?"

# FAILED: Find nodes by absolute xpath using namespaces (missing -n)
test_opts=(-s "${rel_xpath}")
test_run "TCN01"
test_result "$?" 0
