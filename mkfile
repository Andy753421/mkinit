# Copyright (C) 2009 Andy Spencer
# See COPYING for terms

install:V:
	install -d \
		$DESTDIR/etc \
		$DESTDIR/sbin \
		$DESTDIR/lib/mkinit/bin \
		$DESTDIR/lib/mkinit/state
	install -t $DESTDIR/lib/mkinit/bin \
 		./src/{mkinit,service,respawn}
	install -t $DESTDIR/etc  ./init.mk       
	ln -sf $DESTDIR/lib/mkinit/bin/mkinit $DESTDIR/sbin

uninstall:VE:
	rm -rf /lib/mkinit/bin/
	rm /lib/mkinit/cmd
	rm /sbin/mkinit
	rmdir /lib/mkinit/state/
	rmdir /lib/mkinit/
