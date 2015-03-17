#!/usr/bin/env bash
if [ -f /etc/centos-release ]; then
OS="CentOS"
OS="CentOS"
VERFULL=$(cat /etc/centos-release | sed 's/^.*release //;s/ (Fin.*$//')
VER=${VERFULL:0:1} # returns 6 or 7
VERMINOR=${VERFULL:0:3} # return 6.x or 7.x
BITS=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
else
OS="Ubuntu"
fi

if [ "$OS" = "CentOS" ]; then
yum -y install http://rpms.famillecollet.com/enterprise/remi-release-$VER.rpm
yum --enablerepo=remi,remi-php56 -y update
if [ "$BITS" = "64" ]; then
rm -f /usr/lib64/php/modules/suhosin.so
else
rm -f /usr/lib/php/modules/suhosin.so
fi
rm -rf /etc/php.d/suhosin.ini
yum --enablerepo=remi,remi-php56 -y install php-suhosin
else


SUHOSIN="0.9.37.1"
cd /tmp
wget -nv -O suhosin.zip https://github.com/stefanesser/suhosin/archive/$SUHOSIN.zip
unzip -q suhosin.zip
rm -f suhosin.zip
cd suhosin-$SUHOSIN
phpize 
./configure 
make
make install 
cd ..
rm -rf suhosin-$SUHOSIN
fi
