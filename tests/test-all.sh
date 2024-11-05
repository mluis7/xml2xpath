#!/bin/bash
#
#
#
BG=${BG:-0}

run_tests_in_background(){
	./test-html-base.sh &
	./test-xml-ns-01.sh &
	./test-xml-ns-02.sh &
	./test-xml-ns-03.sh &
	./test-xml-ns-no-default.sh &	
}

sep="\n-------------------------------------------------------------\n"

echo

if [ "$BG" -eq 1 ];then
	# sorting stdout by PID keeps test description and results more or less ordered but it's not perfect.
	# To get a clean output run tests without BG=1. Added at issue #15.
	for i in 1 2 3;do
		# BG=1 ./test-all.sh
		run_tests_in_background
	done | sort -k1,2r
	
else
	./test-html-base.sh
	echo -e "$sep"
	./test-xml-ns-01.sh
	echo -e "$sep"
	./test-xml-ns-02.sh
	
	echo -e "$sep"
	./test-xml-ns-03.sh
	
	echo -e "$sep"
	./test-xml-ns-no-default.sh
fi
