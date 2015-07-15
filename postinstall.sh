#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

function finish {
  rm -f /temp/installed.db1 /temp/installed.db2
  rm -f /temp/$PACKAGE.lst.gz
}
trap finish EXIT


cp /etc/setup/installed.db /temp/installed.db.1
sed -i "/^zip /d" /temp/installed.db.1
echo "$PACKAGE $INSTALLFILE $0" >> /temp/installed.db.1
cat /temp/installed.db.1 | sort | uniq | /temp/installed.db.2

cp /temp/installed.db.2 /etc/setup/installed.db

#----------------------------#

tar ztf screen-4.2.1.tar.gz > /temp/$PACKAGE.lst
gzip /temp/$PACKAGE.lst
cp /temp/$PACKAGE.lst.gz /etc/setup/$PACKAGE.lst.gz
