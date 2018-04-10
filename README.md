# xml2xpath
Print XPath present on XML file. If an XSD file is provided and *xmlbeans* package is installed, try to create an XML instance and print the XPath from it.

Taking [this XSD example from w3schools](https://www.w3schools.com/xml/schema_example.asp) the script will print

	/shiporder
	/shiporder/orderperson
	/shiporder/shipto
	/shiporder/shipto/name
	/shiporder/shipto/address
	/shiporder/shipto/city
	/shiporder/shipto/country
	/shiporder/item
	/shiporder/item/title
	/shiporder/item/note
	/shiporder/item/quantity
	/shiporder/item/price

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

NAME
====
	xml2xpath.sh - Print XPath present on xml or (if possible) xsd files.

SYNOPSIS
========
	xml2xpath.sh [-h] [-d file -t <tag name>] [-x file]

DESCRIPTION
===========
Print XPath present on XML file. If an XSD file is provided and **xmlbeans** package is installed, try to create an XML instance and print the XPath from it.

OPTIONS
========
     -d   xsd file path.

     -h   print this help message.

     -f   tag name to start searching for xpath strings.

     -t   print XML element tree as provided by xmllint 'du' shell command.

     -x   xml file, not to use with -d option.
