#!/bin/bash
#
# Test file from:
# https://www.w3.org/TR/XHTMLplusMathMLplusSVG/sample.xhtml
#
# Namespaces on root element and body. Multiple default namespaces across document.
#   default=http://www.w3.org/1999/xhtml
#   default=http://www.w3.org/1998/Math/MathML
#   svg=http://www.w3.org/2000/svg
# Mapped Namespaces:
#   defaultns=http://www.w3.org/1999/xhtml
#   defaultns1=http://www.w3.org/1998/Math/MathML
#   svg=http://www.w3.org/2000/svg
#

script_name=$(basename "$0")
source test-lib-src.sh
xml_file="resources/html5.html"
test_opts=()
test_type_opts=(-x "$xml_file")

echo_with_pid "*** XHTML tests - Namespaces on root element and body. Multiple default namespaces across document. ($script_name) ***"
# Test case descriptions
TC01="Basic test (-x)"
TC02="Replace 'defaultns' prefix (-p)"
TC03="Replace default namespace definition (-o), relative path (-s)"


test_run "TC01"
test_result "$?"

# PASSED: Replace 'defaultns' prefix, relative path
test_opts=(-p 'dft0')
#xml2xpath.sh "${test_opts[@]}" -x "$xml_file" | grep -q 'XPath error'
test_run "TC02"
test_result "$?"

# PASSED: Replace defaultns prefix, relative path
test_opts=(-o 'dft01=http://www.w3.org/1998/Math/MathML' -s '//dft01:math/dft01:mrow/dft01:mn')
test_run "TC03"
test_result "$?"

