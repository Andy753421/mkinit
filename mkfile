# Copyright (C) 2009 Andy Spencer
# See COPYING for terms

PROGS=src/initctld
CLEAN=src/*.o

default:V: all

install:V: all
	install -d \
		$DESTDIR/etc \
		$DESTDIR/sbin \
		$DESTDIR/lib/mkinit/bin \
		$DESTDIR/lib/mkinit/state
	install -t $DESTDIR/lib/mkinit/bin \
 		./src/{mkinit,service,respawn,initctld}
	install -t $DESTDIR/etc  ./init.mk       
	ln -sf $DESTDIR/lib/mkinit/bin/mkinit $DESTDIR/sbin

uninstall:VE:
	rm -rf /lib/mkinit/bin/
	rm /lib/mkinit/cmd
	rm /sbin/mkinit
	rmdir /lib/mkinit/state/
	rmdir /lib/mkinit/

<../mkcommon

# vim: ft=mk
