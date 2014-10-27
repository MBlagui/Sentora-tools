#!/usr/bin/env bash

# pre-required packages: php-devel gcc gcc-c++ autoconf automake
yum install php-pear -y
pecl install Xdebug
cat > /etc/php.d/xdebug.ini
[xdebug]
zend_extension="/usr/lib64/php/modules/xdebug.so"
xdebug.remote_enable = 1
EOF
chmod +x /usr/lib64/php/modules/xdebug.so 
service httpd restart
php -i
