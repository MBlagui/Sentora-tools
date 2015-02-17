#!/usr/bin/env bash
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
