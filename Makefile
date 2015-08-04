MIRROR_URL := http://mirrors.kernel.org/sourceware/cygwin
ARCH := x86_64
PACKAGES := 
SHELL := /bin/bash

test:
	@echo "Hello"

setup.ini:
	wget -O $@ "$(MIRROR_URL)/$(ARCH)/setup.ini"
	touch setup.ini

setup.shelf: setup.ini
	./extract_control.py --ini=$< --shelf=$@

package_list.mk: setup.shelf
	printf "PACKAGES := " > $@
	./extract_control.py --shelf=$< -r -e | tr '\n' ' ' >> $@
	printf "\n" >> $@

include package_list.mk
PACKAGES := $(wordlist 1,8,$(PACKAGES))

all: $(foreach x,$(PACKAGES),out/$(x).ipk)

out/%.ipk: setup.shelf
	@mkdir -p out
	make $*.ipk TARGET=$* --no-print-directory
	mv $*.ipk $@

_clean-%:
	make clean-$* TARGET=$* --no-print-directory

clean: $(foreach x,$(PACKAGES),_clean-$x)

distclean: clean
	rm -f package_list.mk
	rm -f setup.ini setup.shelf

#------------------------------------------#

TARGET :=
ifdef TARGET

INTERMEDIATES := /control/control /control/postinst
INTERMEDIATES += /control/prerm /install /data.tar.gz /control.tar.gz
INTERMEDIATES += .ipk /debian-binary
.INTERMEDIATE: $(foreach x,$(INTERMEDIATES),$(TARGET)$x)
.DELETE_ON_ERROR:

SERVER_FILE := $(strip $(shell \
	./extract_control.py --shelf=setup.shelf -r -i $(TARGET) | \
	grep 'File:' | \
	sed "s/^File[:] //g"))

CHECKSUM := $(strip $(shell \
	./extract_control.py --shelf=setup.shelf -r -i $(TARGET) | \
	grep 'Checksum:' | \
	sed "s/^Checksum[:] //g"))

LOCAL_FILE := $(TARGET)/$(notdir $(SERVER_FILE))
LIST_FILE := etc/setup/$(basename $(basename $(notdir $(SERVER_FILE)))).lst

extract = $(strip \
$(if $(subst .gz,,$(suffix $1)),\
$(if $(subst .bz2,,$(suffix $1)),\
$(if $(subst .xz,,$(suffix $1)),\
$(error unknown file-type $(suffix $1)),\
xz -d -f $1),\
bzip2 -d -f $1),\
gzip -d -f $1))

$(TARGET)/control/control: setup.shelf
	@mkdir -p $(dir $@)
	./extract_control.py --shelf=$< -r -c $(TARGET) > $@
	chmod 644 $@

$(TARGET)/control/postinst: postinst.template $(TARGET)/data.tar.gz
	@mkdir -p $(dir $@)
	cp $< $@
	sed -i "s/@PACKAGE@/$(TARGET)/g" $@
	sed -i "s/@INSTALLFILE@/$(notdir $(SERVER_FILE))/g" $@
	SCRIPTLIST=`tar -tzf $(TARGET)/data.tar.gz |\
	grep -E "^etc/postinstall/.+[.][a-z]*sh"` ;\
	SCRIPTLIST=$$SCRIPTLIST `tar -tzf $(TARGET)/data.tar.gz |\
	grep -E "^/?etc/postinstall/.+bat"` ;\
	sed -i "s%@SCRIPTLIST@%$$SCRIPTLIST%g" $@
	chmod 755 $@

$(TARGET)/control/prerm: prerm.template $(TARGET)/data.tar.gz
	@mkdir -p $(dir $@)
	cp $< $@
	sed -i "s/@PACKAGE@/$(TARGET)/g" $@
	sed -i "s/@INSTALLFILE@/$(notdir $(SERVER_FILE))/g" $@
	SCRIPTLIST=`tar -tzf $(TARGET)/data.tar.gz |\
	grep -E "^etc/preremove/.+[.][a-z]*sh"` ;\
	SCRIPTLIST=$$SCRIPTLIST `tar -tzf $(TARGET)/data.tar.gz |\
	grep -E "^/?etc/preremove/.+bat"` ;\
	sed -i "s%@SCRIPTLIST@%$$SCRIPTLIST%g" $@
	chmod 755 $@

$(TARGET)/control.tar.gz: $(TARGET)/control/postinst $(TARGET)/control/prerm
$(TARGET)/control.tar.gz: $(TARGET)/control/control
	@mkdir -p $(dir $@)
	cd $(dir $@)control && tar cf $(abspath $@) $(notdir $^)
	rm -r $(TARGET)/control
	chmod 644 $@

$(TARGET)/debian-binary:
	@mkdir -p $(dir $@)
	printf "2.0\n" > $@
	chmod 644 $@

$(TARGET)/data.tar.gz: setup.shelf
	@mkdir -p $(dir $@)
	wget "$(MIRROR_URL)/$(SERVER_FILE)" -O "$(LOCAL_FILE)" 
	echo "$(CHECKSUM) $(LOCAL_FILE)" | sha512sum -c -
	$(call extract,$(LOCAL_FILE))
	mv $(basename $(LOCAL_FILE)) $(TARGET)/data.tar
	mkdir -p $(TARGET)/etc/setup
	tar tf $(TARGET)/data.tar > $(TARGET)/$(LIST_FILE)
	gzip -f $(TARGET)/$(LIST_FILE)
	cd $(TARGET) && tar rf data.tar $(LIST_FILE).gz
	mkdir -p $(TARGET)/data.tar.temp
	cd $(TARGET)/data.tar.temp && tar xf $(abspath $(TARGET)/data.tar)
	cd $(TARGET)/data.tar.temp && \
	tar cf $(abspath $(TARGET)/data.tar) --numeric-owner --owner=0 --group=0 `ls -A`
	gzip -f $(TARGET)/data.tar
	chmod 644 $@
	ls $@ && touch -c $@

$(TARGET).ipk: $(TARGET)/data.tar.gz $(TARGET)/control.tar.gz
$(TARGET).ipk: $(TARGET)/debian-binary
	cd $(TARGET) && ar r $(abspath $@) $(notdir $^)
	ls $@ && touch -c $@
	rm -r $(TARGET)
	chmod 644 $@

clean-$(TARGET):
	rm -rf $(TARGET).ipk $(TARGET)

endif
