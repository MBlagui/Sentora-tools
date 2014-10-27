#!/usr/bin/env bash
mkdir /tmp/webmin
cd /tmp/webmin
wget http://www.webmin.com/jcameron-key.asc
rpm --import jcameron-key.asc
cat > /etc/yum.repos.d/webmin.repo << EOF
[Webmin]
name=Webmin Distribution Neutral
baseurl=http://download.webmin.com/download/yum
mirrorlist=http://download.webmin.com/download/yum/mirrorlist
enabled=1
EOF
yum install webmin -y
# Enable webmin autostart & start it
chkconfig on
service webmin start
# Webmin now on http://ip:10000
