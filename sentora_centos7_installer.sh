#!/usr/bin/env bash

# OS VERSION: CentOS 6.4+ Minimal
# ARCH: 32bit + 64bit

SEN_VERSION=master
Panelpath="/etc/zpanel"
paneldata="/var/zpanel"
dbserver="mariadb"
firewallservice="iptables"

# Official Sentora Automated Installation Script
# =============================================
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# First we check if the user is 'root' before allowing installation to commence
if [ $UID -ne 0 ]; then
    echo "Installed failed! To install you must be logged in as 'root', please try again"
  exit 1
fi

# Lets check for some common control panels that we know will affect the installation/operating of Sentora.
if [ -e /usr/local/cpanel ] || [ -e /usr/local/directadmin ] || [ -e /usr/local/solusvm/www ] || [ -e /usr/local/home/admispconfig ] || [ -e /usr/local/lxlabs/kloxo ] ; then
    echo "You appear to have a control panel already installed on your server; This installer"
    echo "is designed to install and configure Sentora on a clean OS installation only!"
    echo ""
    echo "Please re-install your OS before attempting to install using this script."
    exit
fi

if rpm -q php httpd $dbserver bind postfix dovecot; 
then
    echo "You appear to have a server with apache/mysql/bind/postfix already installed; "
    echo "This installer is designed to install and configure Sentora on a clean OS "
    echo "installation only!"
    echo ""
    echo "Please re-install your OS before attempting to install using this script."
    exit
exit 
fi

# Ensure the installer is launched and can only be launched on CentOs 6.x/ centos 7.x Supported
BITS=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
if [ -f /etc/centos-release ]; then
  OS="CentOs"
  VERFULL=$(cat /etc/centos-release | sed 's/^.*release //;s/ (Fin.*$//')
  VER=${VERFULL:0:1} # retunr 6 or 7
  VERMINOR=${VERFULL:0:3} # return 6.x or 7.x
else
  OS=$(uname -s)
  VER=$(uname -r);
fi
echo "Detected : $OS  $VER  $BITS"
if [ "$VER" = "7" ]; then
 dbserver="mariadb" &&  echo "DB server will be mariaDB"
 firewallservice="firewalld"
 wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-1.noarch.rpm
 yum -y install epel-release-7-1.noarch.rpm
 else 
 dbserver="mysql" && echo "DB server will be mySQL"
fi
#warning the last version of centos and 6.x
if [[ "$OS" = "CentOs" ]] && ( [[ "$VER" = "6" ]] || [[ "$VER" = "7" ]] ) ; then 
echo "Installing Sentora panel supported os"
else
  echo "Sorry, this installer only supports the installation of Sentora on CentOS 6.x./7.x" 
  exit 1;
fi

# Set custom logging methods so we create a log file in the current working directory.
logfile=$$.log
touch $$.log
exec > >(tee $logfile)
exec 2>&1

# ***************************************
# * Common installer functions          *
# ***************************************

# Generates random passwords
passwordgen() {
         l=$1
           [ "$l" == "" ] && l=16
          tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}

# Display the 'welcome' splash/user warning info..
echo -e "##############################################################"
echo -e "# Welcome to the Official Sentora Installer for CentOS 6     #"
echo -e "#                                                            #"
echo -e "# Please make sure your VPS provider hasn't pre-installed    #"
echo -e "# any packages required by Sentora.                          #"
echo -e "#                                                            #"
echo -e "# If you are installing on a physical machine where the OS   #"
echo -e "# has been installed by yourself please make sure you only   #"
echo -e "# installed CentOS with no extra packages.                   #"
echo -e "#                                                            #"
echo -e "# If you selected additional options during the CentOS       #"
echo -e "# install please consider reinstalling without them.         #"
echo -e "#                                                            #"
echo -e "##############################################################"

# Lets check that the user wants to continue first...
while true; do
read -e -p "Would you like to continue (y/n)? " yn
    case $yn in
    	[Yy]* ) break;;
		[Nn]* ) exit;
	esac
done

# Install package to allow auto selection of php timezone and public ip
yum -y -q install tzdata wget &>/dev/null

# Set some installation defaults/auto assignments
fqdn=$(`/bin/hostname`)
publicip=$(`wget -qO- http://api.sentora.org/ip.txt`)

echo "echo \$TZ > /etc/timezone" >> /usr/bin/tzselect

# Installer options
while true; do
	echo -e "Find your timezone from : http://php.net/manual/en/timezones.php e.g Europe/London"
	tzselect
	tz=$(`cat /etc/timezone`)
	echo -e "Enter the FQDN you will use to access Sentora on your server."
	echo -e "- It MUST be a sub-domain of you main domain, it MUST NOT be your main domain only. Example: panel.yourdomain.com"
	echo -e "- Remember that the sub-domain ('panel' in the example) MUST be setup in your DNS nameserver."
	read -e -p "FQDN for zpanel: " -i "$fqdn" fqdn
	read -e -p "Enter the public (external) server IP: " -i "$publicip" publicip
	read -e -p "Sentora is now ready to install, do you wish to continue (y/n)" yn
	case $yn in
		[Yy]* ) break;;
		[Nn]* ) exit;
	esac
done

    #to remedy some problems of compatibility use of mirror centos.org to all users
    #CentOS-Base.repo

    #released Base
    sed -i 's|mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os|#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os|' "/etc/yum.repos.d/CentOS-Base.repo"
    sed -i 's|#baseurl=http://mirror.centos.org/centos/$releasever/os/$basearch/|baseurl=http://mirror.centos.org/centos/$releasever/os/$basearch/|' "/etc/yum.repos.d/CentOS-Base.repo"
    #released Updates
    sed -i 's|mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates|#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates|' "/etc/yum.repos.d/CentOS-Base.repo"
    sed -i 's|#baseurl=http://mirror.centos.org/centos/$releasever/updates/$basearch/|baseurl=http://mirror.centos.org/centos/$releasever/updates/$basearch/|' "/etc/yum.repos.d/CentOS-Base.repo"
    #additional packages that may be useful Centos Extra
    sed -i 's|mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras|#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras|' "/etc/yum.repos.d/CentOS-Base.repo"
    sed -i 's|#baseurl=http://mirror.centos.org/centos/$releasever/extras/$basearch/|baseurl=http://mirror.centos.org/centos/$releasever/extras/$basearch/|' "/etc/yum.repos.d/CentOS-Base.repo"
    #additional packages that extend functionality of existing packages Centos Plus
    sed -i 's|mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus|#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus|' "/etc/yum.repos.d/CentOS-Base.repo"
    sed -i 's|#baseurl=http://mirror.centos.org/centos/$releasever/centosplus/$basearch/|baseurl=http://mirror.centos.org/centos/$releasever/centosplus/$basearch/|' "/etc/yum.repos.d/CentOS-Base.repo"
    #contrib - packages by Centos Users
    sed -i 's|mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=contrib|#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=contrib|' "/etc/yum.repos.d/CentOS-Base.repo"
    sed -i 's|#baseurl=http://mirror.centos.org/centos/$releasever/contrib/$basearch/|baseurl=http://mirror.centos.org/centos/$releasever/contrib/$basearch/|' "/etc/yum.repos.d/CentOS-Base.repo"

    #check if the machine and on openvz
    if [ -f "/etc/yum.repos.d/vz.repo" ]; then
      #vz.repo
      sed -i 's|mirrorlist=http://vzdownload.swsoft.com/download/mirrors/centos-6|baseurl=http://vzdownload.swsoft.com/ez/packages/centos/6/$basearch/os/|' "/etc/yum.repos.d/vz.repo"
      sed -i 's|mirrorlist=http://vzdownload.swsoft.com/download/mirrors/updates-released-ce6|baseurl=http://vzdownload.swsoft.com/ez/packages/centos/6/$basearch/updates/|' "/etc/yum.repos.d/vz.repo"
    fi

    #disable deposits that could result in installation errors
    #repo ELRepo
    if [ -f "/etc/yum.repos.d/elrepo.repo" ]; then
      sed -i 's/enabled=1/enabled=0/g' "/etc/yum.repos.d/elrepo.repo"
    fi

    #repo Epel Testing
    if [ -f "/etc/yum.repos.d/epel-testing.repo" ]; then
      sed -i 's/enabled=1/enabled=0/g' "/etc/yum.repos.d/epel-testing.repo"
    fi

    #repo Remi
    if [ -f "/etc/yum.repos.d/remi.repo" ]; then
      sed -i 's/enabled=1/enabled=0/g' "/etc/yum.repos.d/remi.repo"
    fi

    #repo RPMForge
    if [ -f "/etc/yum.repos.d/rpmforge.repo" ]; then
      sed -i 's/enabled=1/enabled=0/g' "/etc/yum.repos.d/rpmforge.repo"
    fi

    #repo RPMFusion Free Updates
    if [ -f "/etc/yum.repos.d/rpmfusion-free-updates.repo" ]; then
      sed -i 's/enabled=1/enabled=0/g' "/etc/yum.repos.d/rpmfusion-free-updates.repo"
    fi

    #repo RPMFusion Free Updates Testing
    if [ -f "/etc/yum.repos.d/rpmfusion-free-updates-testing.repo" ]; then
      sed -i 's/enabled=1/enabled=0/g' "/etc/yum.repos.d/rpmfusion-free-updates-testing.repo"
    fi

# We need to disable SELinux...
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Stop conflicting services and iptables to ensure all services will work
service sendmail stop
service "$firewallservice" save # replaced iptables with firewallD
service "$firewallservice" stop
chkconfig sendmail off
chkconfig "$firewallservice" off

# Start log creation.
echo -e ""
echo -e "# Generating installation log and debug info..."
uname -a
echo -e ""
rpm -qa

# Removal of conflicting packages prior to Sentora installation.
yum -y remove bind-chroot qpid-cpp-client

# Install some standard utility packages required by the installer and/or Sentora.
yum -y install sudo wget vim make zip unzip git chkconfig

# Cloning Sentora from GitHub
echo "Downloading Sentora, Please wait, this may take several minutes, the installer will continue after this is complete!"
# Get latest sentora
git clone https://github.com/sentora/sentora.git
# Should add latest stable release tag
cd sentora/
git checkout $SEN_VERSION
mkdir ../zp_install_cache/
git checkout-index -a -f --prefix=../zp_install_cache/
cd ../zp_install_cache/

# Installing epel repo for extra packages php-suhosin php-mcrypt bash-completion proftpd proftpd-mysql 

# disable fedora  here centos 6
# rpm --import https://fedoraproject.org/static/0608B895.txt
# cp etc/build/config_packs/centos_6/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo

# We now update the server software packages.
yum -y update && yum -y upgrade

# Install required software and dependencies required by Sentora.
# don't work as for php-suhosin
# yum -y install ld-linux.so.2 libbz2.so.1 libdb-4.7.so libgd.so.2 httpd php php-suhosin php-devel php-gd php-mbstring php-mcrypt php-intl php-imap php-mysql php-xml php-xmlrpc curl curl-devel perl-libwww-perl libxml2 libxml2-devel mysql-server zip webalizer gcc gcc-c++ httpd-devel at make mysql-devel bzip2-devel postfix postfix-perl-scripts bash-completion dovecot dovecot-mysql dovecot-pigeonhole mysql-server proftpd proftpd-mysql bind bind-utils bind-libs
yum -y install ld-linux.so.2 libbz2.so.1 libdb-4.7.so libgd.so.2 bash-completion
yum -y install curl curl-devel perl-libwww-perl libxml2 libxml2-devel zip bzip2-devel gcc gcc-c++ at make bash-completion
yum -y install httpd httpd-devel 
yum -y install php  php-devel php-gd php-mbstring php-intl  php-mysql php-xml php-xmlrpc
yum -y install php-mcrypt php-imap  #Epel packages
yum -y install postfix postfix-perl-scripts && yum -y install dovecot dovecot-mysql dovecot-pigeonhole 
yum -y install proftpd proftpd-mysql 
yum -y install bind bind-utils bind-libs
yum -y install "$dbserver" "$dbserver-devel"
yum -y install "$dbserver-server"
yum -y install webalizer

# Build suhosin for PHP 5.4 which is required by Sentora. // to be replaced with function
echo -e "\n# Building suhosin for php5.4"
git clone https://github.com/stefanesser/suhosin
cd suhosin
phpize
./configure
make
make install
cd ..
rm -rf suhosin
echo 'extension=suhosin.so' > /etc/php.d/suhosin.ini


# Generation of random passwords
password=`passwordgen`;
postfixpassword=`passwordgen`;
zadminNewPass=`passwordgen`;
phpmyadminsecret=`passwordgen`;
roundcube_des_key=`passwordgen 24`;

# Set-up Sentora directories and configure directory permissions as required.
mkdir $Panelpath
mkdir $Panelpath/configs
mkdir $Panelpath/panel
mkdir $Panelpath/docs
mkdir $paneldata
mkdir $paneldata/hostdata
mkdir $paneldata/hostdata/zadmin
mkdir $paneldata/hostdata/zadmin/public_html
mkdir $paneldata/logs
mkdir $paneldata/logs/proftpd
mkdir $paneldata/backups
mkdir $paneldata/temp
cp -R . $Panelpath/panel/
chmod -R 777 $Panelpath/
chmod -R 777 $paneldata/
chmod -R 770 $paneldata/hostdata/
chown -R apache:apache $paneldata/hostdata/
ln -s $Panelpath/panel/bin/zppy /usr/bin/zppy
ln -s $Panelpath/panel/bin/setso /usr/bin/setso
ln -s $Panelpath/panel/bin/setzadmin /usr/bin/setzadmin
chmod +x $Panelpath/panel/bin/zppy
chmod +x $Panelpath/panel/bin/setso
cp -R $Panelpath/panel/etc/build/config_packs/centos_6/. $Panelpath/configs/
# set password after test connexion
cc -o $Panelpath/panel/bin/zsudo $Panelpath/configs/bin/zsudo.c
sudo chown root $Panelpath/panel/bin/zsudo
chmod +s $Panelpath/panel/bin/zsudo

# phpMyAdmin specific installation tasks...
chmod 644 $Panelpath/configs/phpmyadmin/config.inc.php
sed -i "s|\$cfg\['blowfish_secret'\] \= 'SENTORA';|\$cfg\['blowfish_secret'\] \= '$phpmyadminsecret';|" $Panelpath/configs/phpmyadmin/config.inc.php
ln -s $Panelpath/configs/phpmyadmin/config.inc.php $Panelpath/panel/etc/apps/phpmyadmin/config.inc.php
# Remove phpMyAdmin's setup folder in case it was left behind
rm -rf $Panelpath/panel/etc/apps/phpmyadmin/setup

# MySQL specific installation tasks...
service $dbserver start 
mysqladmin -u root password "$password"
until mysql -u root -p$password -e ";" > /dev/null 2>&1 ; do
read -s -p "enter your root $dbserver password : " password
done
sed -i "s|YOUR_ROOT_MYSQL_PASSWORD|$password|" $Panelpath/panel/cnf/db.php
mysql -u root -p$password -e "DELETE FROM mysql.user WHERE User='root' AND Host != 'localhost'";
mysql -u root -p$password -e "DELETE FROM mysql.user WHERE User=''";
mysql -u root -p$password -e "DROP DATABASE test";
mysql -u root -p$password -e "CREATE SCHEMA zpanel_roundcube";
cat $Panelpath/configs/sentora-install/sql/*.sql | mysql -u root -p$password
mysql -u root -p$password -e "UPDATE mysql.user SET Password=PASSWORD('$postfixpassword') WHERE User='postfix' AND Host='localhost';";
mysql -u root -p$password -e "FLUSH PRIVILEGES";
sed -i "/symbolic-links=/a \secure-file-priv=/var/tmp" /etc/my.cnf

# Set some Sentora custom configuration settings (using. setso and setzadmin)
$Panelpath/panel/bin/setzadmin --set "$zadminNewPass";
$Panelpath/panel/bin/setso --set zpanel_domain $fqdn
$Panelpath/panel/bin/setso --set server_ip $publicip
$Panelpath/panel/bin/setso --set apache_changed "true"

# We'll store the passwords so that users can review them later if required.
touch /root/passwords.txt;
echo "zadmin Password: $zadminNewPass" >> /root/passwords.txt;
echo "MySQL Root Password: $password" >> /root/passwords.txt
echo "MySQL Postfix Password: $postfixpassword" >> /root/passwords.txt
echo "IP Address: $publicip" >> /root/passwords.txt
echo "Panel Domain: $fqdn" >> /root/passwords.txt

# Postfix specific installation tasks...
sed -i "s|;date.timezone =|date.timezone = $tz|" /etc/php.ini
sed -i "s|;upload_tmp_dir =|upload_tmp_dir = $paneldata/temp/|" /etc/php.ini
mkdir $paneldata/vmail
chmod -R 770 $paneldata/vmail
useradd -r -u 101 -g mail -d $paneldata/vmail -s /sbin/nologin -c "Virtual mailbox" vmail
chown -R vmail:mail $paneldata/vmail
mkdir -p /var/spool/vacation
useradd -r -d /var/spool/vacation -s /sbin/nologin -c "Virtual vacation" vacation
chmod -R 770 /var/spool/vacation
ln -s $Panelpath/configs/postfix/vacation.pl /var/spool/vacation/vacation.pl
postmap /etc/postfix/transport
chown -R vacation:vacation /var/spool/vacation
if ! grep -q "127.0.0.1 autoreply.$fqdn" /etc/hosts; then echo "127.0.0.1 autoreply.$fqdn" >> /etc/hosts; fi
sed -i "s|myhostname = control.yourdomain.com|myhostname = $fqdn|" $Panelpath/configs/postfix/main.cf
sed -i "s|mydomain = control.yourdomain.com|mydomain = $fqdn|" $Panelpath/configs/postfix/main.cf
rm -rf /etc/postfix/main.cf /etc/postfix/master.cf
ln -s $Panelpath/configs/postfix/master.cf /etc/postfix/master.cf
ln -s $Panelpath/configs/postfix/main.cf /etc/postfix/main.cf
sed -i "s|password \= postfix|password \= $postfixpassword|" $Panelpath/configs/postfix/mysql-relay_domains_maps.cf
sed -i "s|password \= postfix|password \= $postfixpassword|" $Panelpath/configs/postfix/mysql-virtual_alias_maps.cf
sed -i "s|password \= postfix|password \= $postfixpassword|" $Panelpath/configs/postfix/mysql-virtual_domains_maps.cf
sed -i "s|password \= postfix|password \= $postfixpassword|" $Panelpath/configs/postfix/mysql-virtual_mailbox_limit_maps.cf
sed -i "s|password \= postfix|password \= $postfixpassword|" $Panelpath/configs/postfix/mysql-virtual_mailbox_maps.cf
sed -i "s|\$db_password \= 'postfix';|\$db_password \= '$postfixpassword';|" $Panelpath/configs/postfix/vacation.conf

# Dovecot specific installation tasks (includes Sieve)
mkdir $paneldata/sieve
chown -R vmail:mail $paneldata/sieve
mkdir /var/lib/dovecot/sieve/
touch /var/lib/dovecot/sieve/default.sieve
ln -s $Panelpath/configs/dovecot2/globalfilter.sieve $paneldata/sieve/globalfilter.sieve
rm -rf /etc/dovecot/dovecot.conf
ln -s $Panelpath/configs/dovecot2/dovecot.conf /etc/dovecot/dovecot.conf
sed -i "s|postmaster_address = postmaster@your-domain.tld|postmaster_address = postmaster@$fqdn|" /etc/dovecot/dovecot.conf
sed -i "s|password=postfix|password=$postfixpassword|" $Panelpath/configs/dovecot2/dovecot-dict-quota.conf
sed -i "s|password=postfix|password=$postfixpassword|" $Panelpath/configs/dovecot2/dovecot-mysql.conf
touch /var/log/dovecot.log
touch /var/log/dovecot-info.log
touch /var/log/dovecot-debug.log
chown vmail:mail /var/log/dovecot*
chmod 660 /var/log/dovecot*

# ProFTPD specific installation tasks
groupadd -g 2001 ftpgroup
useradd -u 2001 -s /bin/false -d /bin/null -c "proftpd user" -g ftpgroup ftpuser
sed -i "s|zpanel_proftpd@localhost root z|zpanel_proftpd@localhost root $password|" $Panelpath/configs/proftpd/proftpd-mysql.conf
rm -rf /etc/proftpd.conf
touch /etc/proftpd.conf
if ! grep -q "include $Panelpath/configs/proftpd/proftpd-mysql.conf" /etc/proftpd.conf; then echo "include $Panelpath/configs/proftpd/proftpd-mysql.conf" >> /etc/proftpd.conf; fi
chmod -R 644 $paneldata/logs/proftpd
serverhost=`hostname`

# Apache HTTPD specific installation tasks...
if ! grep -q "Include $Panelpath/configs/apache/httpd.conf" /etc/httpd/conf/httpd.conf; then echo "Include $Panelpath/configs/apache/httpd.conf" >> /etc/httpd/conf/httpd.conf; fi
if ! grep -q "127.0.0.1 "$fqdn /etc/hosts; then echo "127.0.0.1 "$fqdn >> /etc/hosts; fi
if ! grep -q "apache ALL=NOPASSWD: $Panelpath/panel/bin/zsudo" /etc/sudoers; then echo "apache ALL=NOPASSWD: $Panelpath/panel/bin/zsudo" >> /etc/sudoers; fi
# Panelpath still not here
sed -i 's|DocumentRoot "/var/www/html"|DocumentRoot "/etc/zpanel/panel"|' /etc/httpd/conf/httpd.conf
#Centos 7 specific
if [ $VER = "7" ]; then
echo "Centos 7 detected updating apache 2.4"
sed -i 's|Ornder allow,deny|Require all granted|I'  /etc/zpanel/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php
sed -i 's/Allow from all/ /g' /etc/zpanel/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php
sed -i 's/Order allow,deny/ /g' /etc/zpanel/configs/apache/*.conf
sed -i 's/Allow from all/Require all granted/g' /etc/zpanel/configs/apache/*.conf
sed -i 's|Order allow,deny|Require all granted|I'  /etc/zpanel/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php
sed -i '/Allow from all/d' /etc/zpanel/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php
fi
chown -R apache:apache $paneldata/temp/
#Set keepalive on (default is off)
sed -i "s|KeepAlive Off|KeepAlive On|" /etc/httpd/conf/httpd.conf

# PHP specific installation tasks...
sed -i "s|;date.timezone =|date.timezone = $tz|" /etc/php.ini
sed -i "s|;upload_tmp_dir =|upload_tmp_dir = $paneldata/temp/|" /etc/php.ini
#Disable php signature in headers to hide it from hackers
sed -i "s|expose_php = On|expose_php = Off|" /etc/php.ini

# Permissions fix for Apache and ProFTPD (to enable them to play nicely together!)
if ! grep -q "umask 002" /etc/sysconfig/httpd; then echo "umask 002" >> /etc/sysconfig/httpd; fi
if ! grep -q "127.0.0.1 $serverhost" /etc/hosts; then echo "127.0.0.1 $serverhost" >> /etc/hosts; fi
usermod -a -G apache ftpuser
usermod -a -G ftpgroup apache

# BIND specific installation tasks...
chmod -R 777 $Panelpath/configs/bind/zones/
chmod 751 /var/named
chmod 771 /var/named/data
rm -rf /etc/named.conf /etc/rndc.conf /etc/rndc.key
rndc-confgen -a
ln -s $Panelpath/configs/bind/named.conf /etc/named.conf
ln -s $Panelpath/configs/bind/rndc.conf /etc/rndc.conf
cat /etc/rndc.key /etc/named.conf | tee named.conf > /dev/null
cat /etc/rndc.key /etc/rndc.conf | tee named.conf > /dev/null

# CRON specific installation tasks...
mkdir -p /var/spool/cron/
mkdir -p /etc/cron.d/
touch /var/spool/cron/apache
touch /etc/cron.d/apache
crontab -u apache /var/spool/cron/apache

#  ISSUE WITH cron temp fix
sed -i "s|/opt/rh/php55/root/usr/bin/php|php|" $Panelpath/configs/cron/zdaemon /etc/cron.d/zdaemon
cp $Panelpath/configs/cron/zdaemon /etc/cron.d/zdaemon
chmod 744 /var/spool/cron
chmod 644 /var/spool/cron/apache
chmod -R 644 /etc/cron.d/
chown -R apache:apache /var/spool/cron/

# Webalizer specific installation tasks...
rm -rf /etc/webalizer.conf



# Roundcube specific installation tasks...
sed -i "s|YOUR_MYSQL_ROOT_PASSWORD|$password|" $Panelpath/configs/roundcube/db.inc.php
sed -i "s|#||" $panelpath/configs/roundcube/db.inc.php
sed -i "s|rcmail-!24ByteDESkey\*Str|$roundcube_des_key|" $panelpath/configs/roundcube/main.inc.php
rm -rf $panelpath/panel/etc/apps/webmail/config/main.inc.php
ln -s $panelpath/configs/roundcube/main.inc.php $panelpath/panel/etc/apps/webmail/config/main.inc.php
ln -s $panelpath/configs/roundcube/config.inc.php $panelpath/panel/etc/apps/webmail/plugins/managesieve/config.inc.php
ln -s $panelpath/configs/roundcube/db.inc.php $panelpath/panel/etc/apps/webmail/config/db.inc.php

# Enable system services and start/restart them as required.
chkconfig httpd on
chkconfig postfix on
chkconfig dovecot on
chkconfig crond on
chkconfig $dbserver on
chkconfig named on
chkconfig proftpd on
service httpd start
service postfix restart
service dovecot start
service crond start
service $dbserver restart
service named start
service proftpd start
service atd start
php -q $panelpath/panel/bin/daemon.php
# restart all service
service httpd restart
service postfix restart
service dovecot restart
service crond restart
service $dbserver restart
service named restart
service proftpd restart
service atd restart

# We'll now remove the temporary install cache.
cd ../
rm -rf zp_install_cache/ sentora/

# Advise the user that Sentora is now installed and accessible.
echo -e "##############################################################" &>/dev/tty
echo -e "# Congratulations Sentora has now been installed on your     #" &>/dev/tty
echo -e "# server. Please review the log file left in /root/ for      #" &>/dev/tty
echo -e "# any errors encountered during installation.                #" &>/dev/tty
echo -e "#                                                            #" &>/dev/tty
echo -e "# Save the following information somewhere safe:             #" &>/dev/tty
echo -e "# MySQL Root Password    : $password" &>/dev/tty
echo -e "# MySQL Postfix Password : $postfixpassword" &>/dev/tty
echo -e "# Sentora Username       : zadmin                            #" &>/dev/tty
echo -e "# Sentora Password       : $zadminNewPass" &>/dev/tty
echo -e "#                                                            #" &>/dev/tty
echo -e "# Sentora Web login can be accessed using your server IP     #" &>/dev/tty
echo -e "# inside your web browser.                                   #" &>/dev/tty
echo -e "#                                                            #" &>/dev/tty
echo -e "##############################################################" &>/dev/tty
echo -e "" &>/dev/tty

# We now request that the user restarts their server...
while true; do
read -e -p "Restart your server now to complete the install (y/n)? " rsn
	case $rsn in
		[Yy]* ) break;;
		[Nn]* ) exit;
	esac
done
shutdown -r now