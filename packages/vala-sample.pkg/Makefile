compile:
	valac --pkg gtk+-2.0 --pkg hildon-1 -o hildon-hello sample.vala

install:
	mkdir -p "$(DESTDIR)/usr/bin/"
	cp hildon-hello "$(DESTDIR)/usr/bin/"