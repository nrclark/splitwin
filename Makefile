MIRROR_URL := http://mirrors.kernel.org/sourceware/cygwin
ARCH := x86_64
PACKAGES := 
SHELL := /bin/bash

test:
	@echo "Hello"

setup.ini:
	wget -O $@ "$(MIRROR_URL)/$(ARCH)/setup.ini"

setup.shelf: setup.ini
	./extract_control.py --ini=$< --shelf=$@

package_list.mk: setup.shelf
	printf "PACKAGES :=" > $@
	./extract_control.py --shelf=$< -r -e | tr '\n' ' ' >> $@
	printf "\n" >> $@

-include package_list.mk
#PACKAGES := $(wordlist 1,8,$(PACKAGES))

all: $(foreach x,$(PACKAGES),out/$(x).ipk)

#aa.DELETE_ON_ERROR:
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x)/control/control)
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x)/control/postinst)
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x)/control/prerm)
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x)/install)
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x)/data.tar.xz)
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x)/data.tar.gz)
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x)/control.tar.gz)
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x).ipk)
.INTERMEDIATE: $(foreach x,$(PACKAGES),$(x))

%/control/control: setup.shelf
	@mkdir -p $(dir $@)
	./extract_control.py --shelf=$< -r -c $* >> $@

%/control/postinst:
	@mkdir -p $(dir $@)
	printf "#!/bin/sh\n\nexit 0;\n" > $@
	chmod +x $@

%/control/prerm:
	@mkdir -p $(dir $@)
	printf "#!/bin/sh\n\nexit 0;\n" > $@
	chmod +x $@

%/control.tar.gz: %/control/control %/control/postinst %/control/prerm
	@mkdir -p $(dir $@)
	cd $(dir $@)control && tar cf $(abspath $@) $(notdir $^)
	rm -r $*/control

%/debian-binary:
	@mkdir -p $(dir $@)
	printf "2.0\n" > $@

%/install: setup.shelf
	@mkdir -p $(dir $@)
	./extract_control.py --shelf=$< -r -i $* > $(dir $@)install

	touch $@

%/data.tar.gz: %/data.tar.xz %/install
	export FILENAME=`cat $(dir $@)install | grep 'File:' | sed "s/^File[:] //g"` && \
	export CHECKSUM=`cat $(dir $@)install | grep 'Checksum:' | sed "s/^Checksum[:] //g"` && \
	wget "$(MIRROR_URL)/$$FILENAME" -O $*/$$FILENAME && \
	echo "$$CHECKSUM $*/$$FILENAME" | sha512sum -c - && \
	cd $* && ../smart_extract.sh $$FILENAME
	xz -d -f $*/data.tar.xz
	gzip -f $*/data.tar

%.ipk: %/data.tar.gz %/control.tar.gz %/debian-binary
	cd $* && tar cf $(abspath $@) $(notdir $^)
	rm -r $*

out/%.ipk: %.ipk
	@mkdir -p $(dir $@)
	mv $< $@

clean-%:
	rm -rf out/$*.ipk $*.ipk $*

clean: $(foreach x,$(PACKAGES),clean-$x)

distclean: clean
	rm -f package_list.mk
	rm -f setup.ini setup.shelf
