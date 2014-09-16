#!/bin/bash
# Backup all Zpanel accounts / replacing the php hook function
# Should be run in cron job daily when server not having a lot of 
# load and with lower priority
# will generate one file per data prefixed with db_+name + time stamp
# and a html_ file that contain all public_html folder
# will also clear ALL backup older than clearday var
panelroot="/var/zpanel/hostdata"
date=$(date +"%d-%b-%Y_%H_%M")
clearday=45 #delete backups older than XX days apply to all zip files
echo "Backup starting"
mysqlpassword=$(cat /etc/zpanel/panel/cnf/db.php | grep "pass =" | sed -s "s|.*pass \= '\(.*\)';.*|\1|")
#enable logging
logfile="backup_last.log"
oldlogfile="backup_old.log"
errorlogfile="backup_error.log"
touch $errorlogfile
exec > >(tee $logfile)
exec 2>&1
rm -rf old_$logfile
mv $logfile $oldlogfile
echo "Starting backup $(date +"%d-%b-%Y %H:%M")">> $logfile

# Function function_backupdb_execute
# Dump mysql DB and compress it into backups folder
# $1 = user $2 = password
# $3 = host ( could remove host but can work as remote backup too! )
# $4 = database name to backup $5 = path
function_backup_db_execute() {
	backupfolder="$5/backups"
	mkdir -p $backupfolder
	mysqldump --user=$1 --password=$2 --host=$3 $4 > $backupfolder/$4_db_$date.sql
	zip -r $backupfolder/$4_db_$date.zip $backupfolder/$4_db_$date.sql
	rm -f $backupfolder/$4_db_$date.sql
} 
# Function backup public_html folder zip
function_backup_html() {
	echo "html path backup now: $1/public_html"
	zip -r $panelroot/$1/backups/$1_html_$1_$date.zip $panelroot/$1/public_html/*
} 
function_backup_clear() {
	# Delete files older than 45 days
	find $1/$2_db_*.zip -mtime +$clearday -exec rm -f {} \;
	find $1/$2_html_*.zip -mtime +$clearday -exec rm -f {} \;
	echo "Removing old backups in $1 user $2" 
} 

# Function backup DB get list of DB then call DB dump
function_backup_db() {
	echo "user ID to backup : $1"
	mysql zpanel_core -u root -p$mysqlpassword -e "SELECT my_name_vc FROM x_mysql_databases WHERE my_acc_fk='$1' AND my_deleted_ts IS NULL;;"| while read my_name_vc; do 
	if [ ! "$my_name_vc" == "my_name_vc" ]; then
		echo "database to backup $my_name_vc"
		function_backup_db_execute root $mysqlpassword localhost $my_name_vc $2
	fi
done
} 

# Get all users from mySQL DB
mysql zpanel_core -u root -p$mysqlpassword -e "SELECT ac_id_pk, ac_user_vc, CONCAT('/var/zpanel/hostdata/' , ac_user_vc) as ac_user_path,  CONCAT( CONCAT('/var/zpanel/hostdata/' , ac_user_vc),'/public_html') as ac_user_path_tobackup FROM x_accounts WHERE ac_deleted_ts IS NULL and ac_enabled_in = 1 ;" | while read ac_id_pk ac_user_vc ac_user_path guid ac_user_path_tobackup; do
# Always skip first line returned by mysql...
if [ ! "$ac_user_path" == "ac_user_path" ]; then
	# if [  "$ac_user_vc" == "zadmin" ]; then # test working only for zadmin......
	echo "Path: $ac_user_path user to backup"
	function_backup_html $ac_user_vc >> $logfile
	function_backup_db $ac_id_pk $ac_user_path >> $logfile
	function_backup_clear "$ac_user_path/backups" $ac_user_vc >> $logfile
fi
done
echo "Finished backup $(date +"%d-%b-%Y %H:%M")">> $logfile
echo "All backup actions logged in $logfile and errors in $errorlogfile"
