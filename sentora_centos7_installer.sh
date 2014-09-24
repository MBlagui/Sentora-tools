#!/usr/bin/env bash
#
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
#    OS VERSION: CentOS 6.4+/7.x Minimal
#    ARCH: 32bit + 64bit

INSTALL_BRANCH="dev"
SEN_VERSION="master"
SEN_LATEST_RELEASE="1.0.0"
SEN_GIT="https://github.com/sentora/sentora.git"
PANEL_PATH="/etc/zpanel"
PANEL_DATA="/var/zpanel"
DB_SERVER="mariadb"
DB_DAEMON="mariadb"
HTTP_PATH="/etc/httpd"
HTTP_SERVER="httpd"
FIREWALL_SERVICE="iptables"
HTTP_USER="apache"
PHP_BIN_PATH="php"
PANEL_DAEMON_PATH="$PANEL_PATH/panel/bin/daemon.php"
PACKAGE_INSTALLER="yum"
PHP_INI_PATH="/etc"
PHP_EXT_PATH="/etc/php.d"
PUBLIC_IP="127.0.0.1"
FQDN=$(hostname)
ARCH=$(uname -m)
EPEL_BASE_URL="http://dl.fedoraproject.org/pub/epel/";

# First we check if the user is 'root' before allowing installation to commence
if [ $UID -ne 0 ]; then
    echo "Installed failed! To install you must be logged in as 'root', please try again"
  exit 1
fi

# ***************************************
# * Common installer functions          *
# ***************************************
if rpm -q php $HTTP_SERVER $DB_PACKAGE bind postfix dovecot; 
then
    echo "You appear to have a server with apache/mysql/bind/postfix already installed; "
    echo "This installer is designed to install and configure Sentora on a clean OS "
    echo "installation only!"
    echo ""
    echo "Please re-install your OS before attempting to install using this script."
    exit
exit 
fi

# Generates random passwords
passwordgen() {
         l=$1
           [ "$l" == "" ] && l=16
          tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}

disablerepo() {
if [ -f "/etc/yum.repos.d/$1.repo" ]; then
      sed -i 's/enabled=1/enabled=0/g' "/etc/yum.repos.d/$1.repo"
    fi
}

suhosininstall() {
  echo -e "\n# Building suhosin for php5.4"
  git clone https://github.com/stefanesser/suhosin
  cd suhosin; phpize
  ./configure
  make; make install
  cd ..; rm -rf suhosin
  echo 'extension=suhosin.so' > $PHP_EXT_PATH/suhosin.ini
}

#Check OS ver and set some custom Variables/paths
checkos() {
BITS=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
if [ -f /etc/centos-release ]; then
  OS="CentOS"
  VERFULL=$(cat /etc/centos-release | sed 's/^.*release //;s/ (Fin.*$//')
  VER=${VERFULL:0:1} # returns 6 or 7
  VERMINOR=${VERFULL:0:3} # return 6.x or 7.x
else
  OS=$(uname -s)
  VER=$(uname -r);
fi

echo "Detected : $OS  $VER  $BITS"

## Install required packages for installer to work
$PACKAGE_INSTALLER -y install sudo wget vim make zip unzip git chkconfig


## Setup service names and epel repos depending on version detected
if [ "$VER" = "7" ]; then

  FIREWALL_SERVICE="firewalld"
  DB_SERVER="mariadb"
  DB_DAEMON="mariadb"

  ## EPEL Repo Install ##
  EPEL_FILE=$(wget -q -O- "$EPEL_BASE_URL$VER/$ARCH/e/" | grep -oP '(?<=href=")epel.*(?=">)')
  wget "$EPEL_BASE_URL$VER/$ARCH/e/$EPEL_FILE"
  $PACKAGE_INSTALLER -y install epel-release*.rpm

 else
 
  FIREWALL_SERVICE="iptables"  
  DB_DAEMON="mysqld"
  DB_SERVER="mysql"

  ## EPEL Repo Install ##
  EPEL_FILE=$(wget -q -O- "$EPEL_BASE_URL$VER/$ARCH/" | grep -oP '(?<=href=")epel.*(?=">)')
  wget "$EPEL_BASE_URL$VER/$ARCH/$EPEL_FILE"
  $PACKAGE_INSTALLER -y install epel-release*.rpm

fi

#warning the last version of centos and 6.x
if [[ "$OS" = "CentOS" ]] && ( [[ "$VER" = "6" ]] || [[ "$VER" = "7" ]] ) ; then 
  echo "Congratulations your operating system is supported by our automated installer. Continuing the installation."
else
  echo "Unfortunatly this installer only supports the installation of Sentora on CentOS 6.x or 7.x." 
  exit 1;
fi
}

welcomescreen() {
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
}

# Cloning Sentora from GitHub
echo "Downloading Sentora, Please wait, this may take several minutes, the installer will continue after this is complete!"
getlatestsentora() {
# Get sentora DEV / TAG
if [ "$INSTALL_BRANCH" == "dev" ]; then
git clone $SEN_GIT
else
git clone --branch $SEN_LATEST_RELEASE  $SEN_GIT
fi
# Should add latest stable release tag
cd sentora/
git checkout $SEN_VERSION
mkdir ../zp_install_cache/
git checkout-index -a -f --prefix=../zp_install_cache/
cd ../zp_install_cache/
}

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

if rpm -q php $HTTP_SERVER $DB_SERVER bind postfix dovecot; 
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
checkos;

# Set custom logging methods so we create a log file in the current working directory.
logfile=$$.log; touch $$.log
exec > >(tee $logfile)
exec 2>&1

welcomescreen;

# Install package to allow auto selection of php timezone and public ip
$PACKAGE_INSTALLER -y -q install tzdata wget &>/dev/null

# Set some installation defaults/auto assignments
PUBLIC_IP=$(wget http://api.sentora.org/ip.txt -q -O -)
echo "echo \$TZ > /etc/timezone" >> /usr/bin/tzselect

# Installer options
while true; do
	echo -e "Find your timezone from : http://php.net/manual/en/timezones.php e.g Europe/London"
	tzselect
	tz=$(cat /etc/timezone)
	echo -e "Enter the FQDN you will use to access Sentora on your server."
	echo -e "- It MUST be a sub-domain of you main domain, it MUST NOT be your main domain only. Example: panel.yourdomain.com"
	echo -e "- Remember that the sub-domain ('panel' in the example) MUST be setup in your DNS nameserver."
	read -e -p "Full qualified domain name for Sentora: " -i "$FQDN" FQDN
	read -e -p "Enter the public (external) server IP: " -i "$PUBLIC_IP" PUBLIC_IP
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
	disablerepo "elrepo"
	disablerepo "epel-testing"
	disablerepo "remi"
	disablerepo "rpmforge"
	disablerepo "rpmfusion-free-updates"
	disablerepo "rpmfusion-free-updates-testing"

# We need to disable SELinux...
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Stop conflicting services and iptables to ensure all services will work
service sendmail stop; service "$FIREWALL_SERVICE" save; service "$FIREWALL_SERVICE" stop
chkconfig sendmail off; chkconfig "$FIREWALL_SERVICE" off

# Start log creation.
echo -e ""
echo -e "# Generating installation log and debug info..."
uname -a
echo -e ""
rpm -qa

## Remove known problematic packages
$PACKAGE_INSTALLER -y remove bind-chroot qpid-cpp-client

# Install some standard utility packages required by the installer and/or Sentora.
$PACKAGE_INSTALLER -y install sudo wget vim make zip unzip git chkconfig

getlatestsentora;

# We now update the server software packages.
$PACKAGE_INSTALLER -y update; $PACKAGE_INSTALLER -y upgrade

# Install required software and dependencies required by Sentora.
$PACKAGE_INSTALLER -y install ld-linux.so.2 libbz2.so.1 libdb-4.7.so libgd.so.2 bash-completion
$PACKAGE_INSTALLER -y install curl curl-devel perl-libwww-perl libxml2 libxml2-devel zip bzip2-devel gcc gcc-c++ at make bash-completion cronie
$PACKAGE_INSTALLER -y install $HTTP_SERVER $HTTP_SERVER-devel 
$PACKAGE_INSTALLER -y install php php-devel php-gd php-mbstring php-intl  php-mysql php-xml php-xmlrpc
$PACKAGE_INSTALLER -y install php-mcrypt php-imap  #Epel packages
$PACKAGE_INSTALLER -y install postfix postfix-perl-scripts && $PACKAGE_INSTALLER -y install dovecot dovecot-mysql dovecot-pigeonhole 
$PACKAGE_INSTALLER -y install proftpd proftpd-mysql 
$PACKAGE_INSTALLER -y install bind bind-utils bind-libs
$PACKAGE_INSTALLER -y install "$DB_SERVER " "$DB_SERVER-devel"
$PACKAGE_INSTALLER -y install "$DB_SERVER-server"
$PACKAGE_INSTALLER -y install webalizer

# Build suhosin for PHP 5.x which is required by Sentora. 
suhosininstall;

# Generation of random passwords
password=`passwordgen`;
proftppassword=`passwordgen`;
postfixpassword=`passwordgen`;
zadminNewPass=`passwordgen`;
phpmyadminsecret=`passwordgen`;
roundcube_des_key=`passwordgen 24`;

# Set-up Sentora directories and configure directory permissions as required.
mkdir -p $PANEL_PATH/configs
mkdir -p $PANEL_PATH/panel
mkdir -p $PANEL_PATH/docs
mkdir -p $PANEL_DATA/hostdata/zadmin/public_html
mkdir -p $PANEL_DATA/logs/proftpd
mkdir -p $PANEL_DATA/backups
mkdir -p $PANEL_DATA/temp
cp -R . $PANEL_PATH/panel/
chmod -R 777 $PANEL_PATH/ $PANEL_DATA/
chmod -R 770 $PANEL_DATA/hostdata/
chown -R $HTTP_USER:$HTTP_USER $PANEL_DATA/hostdata/
ln -s $PANEL_PATH/panel/bin/zppy /usr/bin/zppy
ln -s $PANEL_PATH/panel/bin/setso /usr/bin/setso
ln -s $PANEL_PATH/panel/bin/setzadmin /usr/bin/setzadmin
chmod +x $PANEL_PATH/panel/bin/zppy
chmod +x $PANEL_PATH/panel/bin/setso
cp -R $PANEL_PATH/panel/etc/build/config_packs/centos_$VER/. $PANEL_PATH/configs/
# set password after test connexion
cc -o $PANEL_PATH/panel/bin/zsudo $PANEL_PATH/configs/bin/zsudo.c
sudo chown root $PANEL_PATH/panel/bin/zsudo
chmod +s $PANEL_PATH/panel/bin/zsudo

# phpMyAdmin specific installation tasks...
chmod 644 $PANEL_PATH/configs/phpmyadmin/config.inc.php
sed -i "s|\$cfg\['blowfish_secret'\] \= 'SENTORA';|\$cfg\['blowfish_secret'\] \= '$phpmyadminsecret';|" $PANEL_PATH/configs/phpmyadmin/config.inc.php
ln -s $PANEL_PATH/configs/phpmyadmin/config.inc.php $PANEL_PATH/panel/etc/apps/phpmyadmin/config.inc.php
# Remove phpMyAdmin's setup folder in case it was left behind
rm -rf $PANEL_PATH/panel/etc/apps/phpmyadmin/setup

# MySQL specific installation tasks...
service $DB_DAEMON start 
mysqladmin -u root password "$password"
until mysql -u root -p$password -e ";" > /dev/null 2>&1 ; do
read -s -p "enter your root $DB_SERVER password : " password
done
sed -i "s|YOUR_ROOT_MYSQL_PASSWORD|$password|" $PANEL_PATH/panel/cnf/db.php
mysql -u root -p$password -e "DELETE FROM mysql.user WHERE User='root' AND Host != 'localhost'";
mysql -u root -p$password -e "DELETE FROM mysql.user WHERE User=''";
mysql -u root -p$password -e "DROP DATABASE test";
mysql -u root -p$password -e "CREATE SCHEMA zpanel_roundcube";
cat $PANEL_PATH/configs/sentora-install/sql/*.sql | mysql -u root -p$password
mysql -u root -p"$password" -e "UPDATE mysql.user SET Password=PASSWORD('$postfixpassword') WHERE User='postfix' AND Host='localhost';";
mysql -u root -p"$password" -e "FLUSH PRIVILEGES";
sed -i "/symbolic-links=/a \secure-file-priv=/var/tmp" /etc/my.cnf

# Set some Sentora custom configuration settings (using. setso and setzadmin)
$PANEL_PATH/panel/bin/setzadmin --set "$zadminNewPass";
$PANEL_PATH/panel/bin/setso --set zpanel_domain $FQDN
$PANEL_PATH/panel/bin/setso --set server_ip $PUBLIC_IP
$PANEL_PATH/panel/bin/setso --set apache_changed "true"

# We'll store the passwords so that users can review them later if required.
touch /root/passwords.txt;
echo "zadmin Password: $zadminNewPass" >> /root/passwords.txt;
echo "MySQL Root Password: $password" >> /root/passwords.txt
echo "MySQL Postfix Password: $postfixpassword" >> /root/passwords.txt
echo "MySQL ProFTPd Password: $proftppassword" >> /root/passwords.txt
echo "IP Address: $PUBLIC_IP" >> /root/passwords.txt
echo "Panel Domain: $FQDN" >> /root/passwords.txt

# Postfix specific installation tasks...
mkdir $PANEL_DATA/vmail && chmod -R 770 $PANEL_DATA/vmail
useradd -r -u 101 -g mail -d $PANEL_DATA/vmail -s /sbin/nologin -c "Virtual mailbox" vmail
chown -R vmail:mail $PANEL_DATA/vmail
mkdir -p /var/spool/vacation
useradd -r -d /var/spool/vacation -s /sbin/nologin -c "Virtual vacation" vacation
chmod -R 770 /var/spool/vacation
ln -s $PANEL_PATH/configs/postfix/vacation.pl /var/spool/vacation/vacation.pl
postmap /etc/postfix/transport
chown -R vacation:vacation /var/spool/vacation
if ! grep -q "127.0.0.1 autoreply.$FQDN" /etc/hosts; then echo "127.0.0.1 autoreply.$FQDN" >> /etc/hosts; fi
sed -i "s|control.yourdomain.com|$FQDN|" $PANEL_PATH/configs/postfix/main.cf
rm -rf /etc/postfix/main.cf /etc/postfix/master.cf
ln -s $PANEL_PATH/configs/postfix/master.cf /etc/postfix/master.cf
ln -s $PANEL_PATH/configs/postfix/main.cf /etc/postfix/main.cf
sed -i "s|password \= postfix|password \= $postfixpassword|" $PANEL_PATH/configs/postfix/*.cf

# Dovecot specific installation tasks (includes Sieve)
mkdir $PANEL_DATA/sieve
chown -R vmail:mail $PANEL_DATA/sieve
mkdir -p /var/lib/dovecot/sieve/
touch /var/lib/dovecot/sieve/default.sieve, /var/log/dovecot.log, /var/log/dovecot-info.log, /var/log/dovecot-debug.log
ln -s $PANEL_PATH/configs/dovecot2/globalfilter.sieve $PANEL_DATA/sieve/globalfilter.sieve
rm -rf /etc/dovecot/dovecot.conf
ln -s $PANEL_PATH/configs/dovecot2/dovecot.conf /etc/dovecot/dovecot.conf
sed -i "s|postmaster@your-domain.tld|postmaster@$FQDN|" /etc/dovecot/dovecot.conf
sed -i "s|password=postfix|password=$postfixpassword|" $PANEL_PATH/configs/dovecot2/*.conf
#sed -i "s|password=postfix|password=$postfixpassword|" $PANEL_PATH/configs/dovecot2/dovecot-mysql.conf
chown vmail:mail /var/log/dovecot*
chmod 660 /var/log/dovecot*

# ProFTPD specific installation tasks
groupadd -g 2001 ftpgroup
useradd -u 2001 -s /bin/false -d /bin/null -c "proftpd user" -g ftpgroup ftpuser
sed -i "s|zpanel_proftpd@localhost root z|zpanel_proftpd@localhost root $password|" $PANEL_PATH/configs/proftpd/proftpd-mysql.conf
rm -f /etc/proftpd.conf; touch /etc/proftpd.conf
if ! grep -q "include $PANEL_PATH/configs/proftpd/proftpd-mysql.conf" /etc/proftpd.conf; then echo "include $PANEL_PATH/configs/proftpd/proftpd-mysql.conf" >> /etc/proftpd.conf; fi
chmod -R 644 $PANEL_DATA/logs/proftpd
serverhost=`hostname`

# Apache $HTTP_SERVER specific installation tasks...
if ! grep -q "Include $PANEL_PATH/configs/apache/httpd.conf" $HTTP_PATH/conf/httpd.conf; then echo "Include $PANEL_PATH/configs/apache/httpd.conf" >> $HTTP_PATH/conf/httpd.conf; fi
if ! grep -q "127.0.0.1 "$FQDN /etc/hosts; then echo "127.0.0.1 "$FQDN >> /etc/hosts; fi
if ! grep -q "apache ALL=NOPASSWD: $PANEL_PATH/panel/bin/zsudo" /etc/sudoers; then echo "apache ALL=NOPASSWD: $PANEL_PATH/panel/bin/zsudo" >> /etc/sudoers; fi
# PANEL_PATH still not here
sed -i 's|DocumentRoot "/var/www/html"|DocumentRoot "/etc/zpanel/panel"|' $HTTP_PATH/conf/httpd.conf

#Centos 7 specific
if [ $VER = "7" ]; then
  echo "Centos 7 detected updating apache 2.4"
  sed -i 's/Allow from all/ /g' $PANEL_PATH/modules/apache_admin/hooks/OnDaemonRun.hook.php
  sed -i 's|Order allow,deny|Require all granted|I'  $PANEL_PATH/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php
  sed -i '/Allow from all/d' $PANEL_PATH/panel/modules/apache_admin/hooks/OnDaemonRun.hook.php
fi

chown -R $HTTP_USER:$HTTP_USER $PANEL_DATA/temp/
#Set keepalive on (default is off)
sed -i "s|KeepAlive Off|KeepAlive On|" $HTTP_PATH/conf/httpd.conf

# PHP specific installation tasks...
#Disable php signature in headers to hide it from hackers
sed -i "s|expose_php = On|expose_php = Off|" $PHP_INI_PATH/php.ini
sed -i "s|;date.timezone =|date.timezone = |" /etc/php.ini
sed -i "s|date.timezone =|date.timezone = $tz|" /etc/php.ini
sed -i "s|;upload_tmp_dir =|upload_tmp_dir = $PANEL_DATA/temp/|" /etc/php.ini
sed -i "s|expose_php = On|expose_php = Off|" /etc/php.ini

# Permissions fix for Apache and ProFTPD (to enable them to play nicely together!)
if ! grep -q "umask 002" /etc/sysconfig/httpd; then echo "umask 002" >> /etc/sysconfig/httpd; fi
if ! grep -q "127.0.0.1 $serverhost" /etc/hosts; then echo "127.0.0.1 $serverhost" >> /etc/hosts; fi
usermod -a -G $HTTP_USER ftpuser
usermod -a -G ftpgroup $HTTP_USER

# BIND specific installation tasks...
chmod -R 777 $PANEL_PATH/configs/bind/zones/
chmod 751 /var/named
chmod 771 /var/named/data
rm -rf /etc/named.conf /etc/rndc.conf /etc/rndc.key
rndc-confgen -a
ln -s $PANEL_PATH/configs/bind/named.conf /etc/named.conf
ln -s $PANEL_PATH/configs/bind/rndc.conf /etc/rndc.conf
cat /etc/rndc.key /etc/named.conf | tee named.conf > /dev/null
cat /etc/rndc.key /etc/rndc.conf | tee named.conf > /dev/null

# CRON specific installation tasks...
sudo crontab -l -u $HTTP_USER> /tmp/mycron; echo "*/5 * * * * nice -2 php -q $PANEL_DAEMON_PATH >> $PANEL_PATH/daemon_last_run.log 2>&1" >> /tmp/mycron; sudo crontab -u $HTTP_USER /tmp/mycron; sudo rm -f /tmp/mycron

# Webalizer specific installation tasks...
rm -rf /etc/webalizer.conf

# Roundcube specific installation tasks...
sed -i "s|YOUR_MYSQL_ROOT_PASSWORD|$password|" $PANEL_PATH/configs/roundcube/db.inc.php
sed -i "s|#||" $PANEL_PATH/configs/roundcube/db.inc.php
sed -i "s|rcmail-!24ByteDESkey\*Str|$roundcube_des_key|" $PANEL_PATH/configs/roundcube/main.inc.php
rm -rf $PANEL_PATH/panel/etc/apps/webmail/config/main.inc.php
ln -s $PANEL_PATH/configs/roundcube/main.inc.php $PANEL_PATH/panel/etc/apps/webmail/config/main.inc.php
ln -s $PANEL_PATH/configs/roundcube/config.inc.php $PANEL_PATH/panel/etc/apps/webmail/plugins/managesieve/config.inc.php
ln -s $PANEL_PATH/configs/roundcube/db.inc.php $PANEL_PATH/panel/etc/apps/webmail/config/db.inc.php

# Enable system services and start/restart them as required.
chkconfig $HTTP_SERVER on
chkconfig postfix on
chkconfig dovecot on
chkconfig crond on
chkconfig $DB_DAEMON on
chkconfig named on
chkconfig proftpd on
service $HTTP_SERVER start
service postfix restart
service dovecot start
service crond start
service $DB_DAEMON restart
service named start
service proftpd start
service atd start
php -q $PANEL_PATH/panel/bin/daemon.php
# restart all service
service $HTTP_SERVER restart
service postfix restart
service dovecot restart
service crond restart
service $DB_DAEMON restart
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
