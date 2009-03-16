compile:
	mkdir bin
	valac --pkg gtk+-2.0 --pkg hildon-1 -o bin/hildon-hello sample.vala

install:
	dh_install bin/hildon-hello usr/bin

clean:
	rm -rf bin