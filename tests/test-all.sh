#!/bin/bash
#
#
#

sep="\n-------------------------------------------------------------\n"

echo

./test-html-base.sh
echo -e "$sep"
./test-xml-ns-01.sh
echo -e "$sep"
./test-xml-ns-02.sh

