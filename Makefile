# PREFIX is environment variable, but if it is not set, then set default value
ifeq	($(PREFIX),)
	PREFIX	:=	/usr/local
endif
mandir	:=	$(PREFIX)/man/man1

install:	xml2xpath.sh
	install	-d	$(PREFIX)/bin/
	install	-m	755	xml2xpath.sh	$(PREFIX)/bin/
	install	-d	$(mandir)
	install	-m	644	man/xml2xpath.sh.1	$(mandir)

uninstall:
	rm	$(PREFIX)/bin/xml2xpath.sh
	rm	$(mandir)/xml2xpath.sh.1