# xml2xpath
Extract and list XPath expressions from XML file. Latest version shows XPath attributes as well.

Table of contents
=================

* [Basic usage](#basic-usage)
* [Absolute paths and namespaces](#absolute-paths-and-namespaces)
* [Using found XPaths](#using-found-xPaths)
* [XPaths on HTML](#xpaths-on-html)
* [Generate an XML from an XSD and show its XPaths](#generate-an-xml-from-an-xsd-and-show-its-xpaths)
* [Script help](#help)

## Basic usage
Get all element xpaths from an XML file. To show attribute XPaths also add `-a` (absolute XPaths)

`xml2xpath.sh -x soap.xml`

Result:

    Found XPath:

    /soap:Envelope
    /soap:Envelope/soap:Body
    /soap:Envelope/soap:Body/operation
    /soap:Envelope/soap:Body/operation/name



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

Adding `-g` would show the qualfied xpath used to generate absolute paths

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
    href="https://en.wikipedia.org/w/index.php?title=Tranquility_Base_Hotel_%26_Casino&amp;diff=1042409471&amp;oldid=1042409347"
    -------
    rel="alternate"
    -------
    type="text/html"
    -------
    href="https://en.wikipedia.org/w/index.php?title=Pettibone_(company)&amp;diff=1042409464&amp;oldid=1042409224"
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

`xml2xpath.sh -a -g -s '//div/div/h3[1]' -l test.html`

Result:

    Found Xpath (absolute):

    / > whereis /@*
    / > whereis //h3
    /div/div/h3[1]
    /div/div/h3[2]
    /div/div/h3[3]
    /div/div/h3[4]
    / > 

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
        
