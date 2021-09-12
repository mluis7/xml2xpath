#!/bin/bash
#
# Example file
# https://xp-dev.com/svn/playgrnd/XMLExamples/readme.html
#
# Namespaces on root element, default namespace: urn:hl7-org:v3

# TODO: warning: failed to load external entity


source test-lib-src.sh
dbg=1
xml_file="resources/test.html"
test_opts=()
test_type_opts=(-l "$xml_file")
rel_xpath='//table[2]/thead/tr'

# Test case descriptions
TC01="Basic test (-l)"
TC02="HTML absolute paths (-a)"
TC03="HTML relative paths (-s)"
TC04="HTML absolute paths for relative expression (-a -s)"
TC05="HTML absolute paths with duplicates (-a -r)"

test_run "TC01"
test_result "$?"

test_opts=(-a)
test_run "TC02"
test_result "$?"

test_opts=(-s "${rel_xpath}")
test_run "TC03"
test_result "$?"

# FIXME: all elements returned. if -s is passed xpaths should discard first du level and prepend xpaths with $du_path
test_opts=(-a -s "${rel_xpath}")
test_run "TC04"
test_result "$?"

test_opts=(-a -r)
print_test_descr "TC05"
dup_cnt=$(test_run_count)
test_opts=(-a)
uniq_cnt=$(test_run_count)
#[ ! "$dup_cnt" -gt "$uniq_cnt" ] && echo "duplicates: $dup_cnt -gt $uniq_cnt $?"
[ ! "$dup_cnt" -gt "$uniq_cnt" ]
test_result "$?"

