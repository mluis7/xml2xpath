#!/bin/bash
#
# Example file
# https://xp-dev.com/svn/playgrnd/XMLExamples/readme.html
#
script_name=$(basename "$0")

source test-lib-src.sh
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
TC06="HTML relative paths (-s) containing axes expression axes::elem"
# TODO: invalid html 

echo "*** HTML tests ($script_name) ***"
test_run "TC01"
test_result "$?"

test_opts=(-a)
test_run "TC02"
test_result "$?"

test_opts=(-s "${rel_xpath}")
test_run "TC03"
test_result "$?"

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

test_opts=(-a -s "//table[@id[.='t1'] and descendant::tr[@class='headerRow']]")
test_run "TC06"
test_result "$?"



