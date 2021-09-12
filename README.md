# xml2xpath
Extract and list XPath expressions from XML/HTML file. Latest version shows XPath attributes as well.

A wrapper around `xmllint` tool that provides convenience options to inspect documents listing namespaces and xpaths expressions.

Table of contents
=================

* [Basic usage](#basic-usage)
* [Absolute paths and namespaces](#absolute-paths-and-namespaces)
* [Default namespaces](#default-namespaces)
* [XPath expressions at a given element](#xpath-expressions-at-a-given-element)
* [Using found XPaths](#using-found-xpaths)
* [XPaths on HTML](#xpaths-on-html)
* [Generate an XML from an XSD and show its XPaths](#generate-an-xml-from-an-xsd-and-show-its-xpaths)
* [Script help](#help)

## Basic usage
Get all element xpaths from an XML file. To show attribute XPaths also, add `-a` (absolute XPaths)

`xml2xpath.sh -x soap.xml`

Result:

	Namespaces:
	
	  default http://example.com
	  soap1 http://schemas.xmlsoap.org/soap/envelope/xxxxxxxxx
	  soap http://schemas.xmlsoap.org/soap/envelope/
	  xml http://www.w3.org/XML/1998/namespace
	
	Found XPath:
	
	/
	/soap:Envelope
	/soap:Envelope/soap:Body
	/soap:Envelope/soap:Body/incident
	/soap:Envelope/soap:Body/incident/Company



## Absolute paths and namespaces
Given an XML with namespaces, the following command will show absolute paths in numeric format

`xml2xpath.sh -a -n -x wiki.xml`

`xmllint` does not show element names in full paths

    /*
    /*/*[8]
    /*/*[9]
    /*/*[8]/*[6]
    /*/*[9]/*[6]
    /*/*[8]/*[3]/@rel
    /*/*[8]/*[3]/@type
    /*/*[8]/*[3]/@href

Adding `-g` would show the qualified xpath used to generate absolute paths

    / > whereis /defaultns:feed/defaultns:entry
    /*/*[8]
    /*/*[9]
    / > whereis /defaultns:feed/defaultns:entry/defaultns:author
    /*/*[8]/*[6]
    /*/*[9]/*[6]
    / > whereis /defaultns:feed/defaultns:entry/defaultns:author/defaultns:name/@*
    / > whereis /defaultns:feed/defaultns:entry/defaultns:id/@*
    / > whereis /defaultns:feed/defaultns:entry/defaultns:link/@*
    /*/*[8]/*[3]/@rel
    /*/*[8]/*[3]/@type
    /*/*[8]/*[3]/@href
    /*/*[9]/*[3]/@rel
    /*/*[9]/*[3]/@type
    /*/*[9]/*[3]/@href

This XPath

    /defaultns:feed/defaultns:entry/defaultns:author

Could generate

    /*/*[8]/*[6]
    /*/*[9]/*[6]

## Default namespaces
This start root element has a default namespace, i.e. without a prefix

`<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">`

Passing `-n` will map that namespace to a `defaultns` prefix by default.
To change that, pass `-o` option with the desired definition in the form `<prefix>:<uri>`

`xml2xpath.sh -n -o 'ns1=http://www.w3.org/2005/Atom' -s '//ns1:entry[descendant::ns1:name[.="author2"]]' -x tests/resources/wiki.xml`

Try this command:

`xml2xpath.sh -a -g -n -o 'ns1=http://www.w3.org/2005/Atom' -s '//ns1:entry[descendant::ns1:name[.="author2"]]' -t -x tests/resources/wiki.xml`

## XPath expressions at a given element
Passing `-s` option to show xpath expressions starting at an specific element or elements.

`xml2xpath.sh -n -s '//defaultns:entry/defaultns:author' -x wiki.xml`

Result:

	Namespaces:
	
	  default http://www.w3.org/2005/Atom
	  xml http://www.w3.org/XML/1998/namespace
	
	Found XPath:
	
	//defaultns:entry/defaultns:author
	//defaultns:entry/defaultns:author
	//defaultns:entry/defaultns:author/name
	//defaultns:entry/defaultns:author
	//defaultns:entry/defaultns:author/name
	//defaultns:entry/defaultns:author
	//defaultns:entry/defaultns:author/name


## Using found XPaths
A couple of commands to show how to use found Xpaths:

Given this xpaths generated with `-a -g` it says there are 4 `entry` elements where the first has the absolute position 8 for any element.

    / > whereis //defaultns:entry
    /*/*[8]
    /*/*[9]
    /*/*[10]
    /*/*[11]

The first one `/*/*[8]` would be equivalent to `//defaultns:entry[1]`, the eight element and the first `entry` element for that xpath expression.

Find all attributes under a qualified path with this shell command

    (echo "setrootns"; echo "cat /defaultns:feed/defaultns:entry/defaultns:link/@*") | xmllint --shell wiki.xml 
    
Result showing `rel`, `type` and `href` attributes:

    / > setrootns
    / > cat /defaultns:feed/defaultns:entry/defaultns:link/@*
    -------
    rel="alternate"
    -------
    type="text/html"
    -------
    href="https://en.wikipedia.org/w/index.php?title=Title%202"
    -------
    rel="alternate"
    -------
    type="text/html"
    -------
    href="https://en.wikipedia.org/w/index.php?title=some_title"
    / >

Find `@rel` attribute under a specific path with this shell command

    (echo "setrootns"; echo "cat /*/*[8]/*[3]/@rel") | xmllint --shell wiki.xml 

Result of specific `@rel` attribute:

    / > setrootns
    / > cat /*/*[8]/*[3]/@rel
    -------
    rel="alternate"

 
 
Adding `p` allows to pass a namespace prefix to search for (experimental).

## XPaths on HTML

`xml2xpath.sh -a -s '//table[2]/thead/tr' -l resources/test.html`

Result:

	Namespaces:
	
	  xml http://www.w3.org/XML/1998/namespace
	
	
	Found Xpath (absolute):
	
	/html/body/table[2]/thead/tr
	/html/body/table[2]/thead/tr/@class
	/html/body/table[2]/thead/tr/th[1]
	/html/body/table[2]/thead/tr/th[2]
	/html/body/table[2]/thead/tr/th[3]
	/html/body/table[2]/thead/tr/th[4]

## Generate an XML from an XSD and show its XPaths
If an XSD file is provided and **xmlbeans** package is installed, try to create an XML instance and print the XPath from it.

Taking [an XSD example from w3schools](https://www.w3schools.com/xml/schema_example.asp) the script will print

`xml2xpath.sh -a -f shiporder -d shiporder.xsd `

Result:

    Creating XML instance starting at element shiporder from shiporder.xsd


    Found Xpath (absolute):

    /shiporder
    /shiporder/@orderid
    /shiporder/item
    /shiporder/item/note
    /shiporder/item/price
    /shiporder/item/quantity
    /shiporder/item/title
    /shiporder/orderperson
    /shiporder/shipto
    /shiporder/shipto/address
    /shiporder/shipto/city
    /shiporder/shipto/country
    /shiporder/shipto/name

Relative paths starting at an element are also possible

`xml2xpath.sh -s '//shipto' -f shiporder -d shiporder.xsd `

Result:

    Creating XML instance starting at element shiporder from shiporder.xsd

    Found XPath:

    //shipto
    //shipto/name
    //shipto/address
    //shipto/city
    //shipto/country

If -t option is passed it will print XML elements tree also

	shiporder
	  orderperson
	  shipto
	    name
	    address
	    city
	    country
	  item
	    title
	    note
	    quantity
	    price

## Help

```text
NAME
  xml2xpath.sh - Print XPath present on xml or (if possible) xsd files.

SYNOPSIS
  xml2xpath.sh [-h] [COMMON OPTIONS] [XSD OPTIONS] [XML OPTIONS] [HMTL OPTIONS]
  xml2xpath.sh [-h] [-d file -f <tag name>] [-a -g -t -s <xpath>] [-n -p <ns prefix> -x <file>] [-l <file>]

DESCRIPTION
 Based on xmllint utility, try to build all possible XPaths from an XML instance. The latter could be constructed from a provided XSD file. 

OPTIONS
  Basic options
     -h   print this help message.
  XSD options
     -d   xsd file path.
     -D   Same as -d but saves created xml instance to <xsd file path>.xml
     -f   name of the root element to build xml from xsd.

  XML/HTML Common Options
    -a   Show absolute Xpaths. Use -g too to add details. -s is used to filter but absolute paths are shown.
    -g   Print xmllint command for debugging or clarity.
    -r   Print repeated xpaths when -a is used. For debugging only.
    -s   Start printing XPath at an absolute or relative xpath, e.g.: /shiporder/shipto ,//shipto
          Must contain namespace prefix if needed. Examples: //defaultns:entry, //xs:element
    -t   print XML element tree as provided by xmllint 'du' shell command.
          
  HTML options
     -l   Use HTML parser

  XML options
     -n   Set namespaces found on root element. Default namespace prefix is 'defaultns'.
     -o   Add a namespace definition in the form <prefix>=URI, e.g.: -o 'defns=urn:hl7-org:v3'
     -p   Namespace prefix to use. No need to pass -n if used. EXPERIMENTAL.
     -x   xml file, will take precedence over -d option.
     
EXAMPLES
        # print all xpaths and elements tree
        xml2xpath.sh -t -x test.xml

        # print xpaths starting at //shipto element
        xml2xpath.sh -s '//shipto' -x test.xml

        # print xpaths from generated xml
        xml2xpath.sh -d test.xsd -f shiporder

        # Use namespaces, show absolute paths and xmllint shell messages
        xml2xpath.sh -a -n -g -x wiki.xml

        # Add a namespace definition and use it in a relative expression
        xml2xpath.sh -o 'defns=urn:hl7-org:v3' -s '//defns:addr' -x HL7.xml | sort | uniq

        # Html file with absolute paths option
        xml2xpath.sh -a -n -l test.html

REPORTING BUGS
        at: https://github.com/mluis7/xml2xpath

AUTHOR
       Written by Luis Muñoz

SEE ALSO
       Full documentation at: https://github.com/mluis7/xml2xpath
```
        
