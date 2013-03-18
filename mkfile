# Copyright (C) 2009,2013 Andy Spencer
# See COPYING for terms

all:V: src/initctld

src/initctld: src/initctld.c
	gcc -Wall -o $target $prereq

install:V: all
	install -d $DESTDIR/lib/mkinit/state
	install -m 755 -D src/mkinit   $DESTDIR/sbin/mkinit
	install -m 755 -D src/service  $DESTDIR/lib/mkinit/bin/service
	install -m 755 -D src/respawn  $DESTDIR/lib/mkinit/bin/respawn
	install -m 755 -D src/initctld $DESTDIR/lib/mkinit/bin/initctld
	install -m 644 -D init.mk      $DESTDIR/etc/init.mk.example
	install -m 644 -D services.mk  $DESTDIR/etc/services.mk.example

uninstall:VE:
	rm -rf $DESTDIR/lib/mkinit
	rm $DESTDIR/sbin/mkinit

clean:
	rm -f src/initctld
