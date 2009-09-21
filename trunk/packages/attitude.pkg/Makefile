compile:
	py_compilefiles *.py

install:
	dh_install main.py* providers.py* framework.py* usr/lib/python2.5/site-packages/attitude
	dh_install attitude usr/bin

clean:
	rm *.py[oc]
