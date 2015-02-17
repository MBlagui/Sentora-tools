#!/usr/bin/env bash
cd /tmp
wget -nv -O suhosin.zip https://github.com/stefanesser/suhosin/archive/0.9.37.1.zip
unzip -q suhosin.zip
rm -f suhosin.zip
cd suhosin-0.9.37.1
phpize 
./configure 
make
make install 
cd ..
rm -rf suhosin-0.9.37.1
