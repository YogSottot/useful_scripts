#!/bin/bash
set -eu
# Uses xtrabackup or innobackupex backup directories to restore an entire database.
# Author: Phil Buescher
# License: None - I release all rights to this ugly script to whoever wants to use it for any purpose.
# Requires: Valid xtrabackup/innobackupex restore point, logs applied/prepared.  Suggest having rsync installed.
#    'mysqlfrm' from mysql utilities
#    Testing extensively before trying on production (duh)
#    All tables must be InnoDB - this does NOT handle MyISAM tables and it won't work if any exist in the backup dir.
#    innodb_file_per_table=1 and innodb_import_table_from_xtrabackup=1
#
# Suggest you read up on mysqlfrm and its limitations. Suck to be missing foreign key constaints and all that fun stuff.
# Running <=5.6? See comments starting at 118 and add cfg files to the for loop if you like.
#
# Usage: inno_restore_database.sh <db_name_to_restore_to> <db_backup_directory>

# Change the datadir if needed to the mysql datadir.
datadir=/var/lib/mysql

# Change the ports if needed.  myport is what the current running mysql server listens on.
# mysqlfrmport is what the temporary server will listen on - just a port nothing else is listening on at the time.
#myport=/var/lib/mysqld/mysqld.sock
mysqlfrmport=3310

# Give username and password for a mysql user with global CREATE, DROP, ALTER - making variables so this can be scripted easier.
# If you want to be prompted, comment the username and password. Otherwise uncomment and specify them.
#username=root
#password=

#######################################################################################

if [ -f /root/.my.cnf ];then

echo "We have the credentials we need.."
username=`grep user /root/.my.cnf | cut -d = -f2`
password=`grep password /root/.my.cnf | cut -d = -f2`
myport=`grep socket /root/.my.cnf | cut -d = -f2`
else

echo "Mysql config with user credentials is not available. Kindly create .my.cnf file with valid mysql credentials.."
echo -e "Do you have the credentials to provide me now ?"
read answer

if [ ${answer} = 'y' ] ; then

read -p "Please enter a valid MySQL administrative login : " username
read -p "Please enter a valid MySQL administrative login : " password
read -p "Please enter a valid MySQL path to unix socket : " myport
cat<> /root/.my.cnf
[mysql]
user=${username}
password=${password}
socket=${myport}
EOF
echo -e "\n\n Have created .my.cnf config file for future runs…..!"

else
return 0

fi
fi

# Remove surrounding quotes only if there are surrounding quotes.
password="${password%\'}"
password="${password#\'}"

#######################################################################################
# Gotta be root.
if [ $UID -ne 0 ]; then echo "Run this as root" ; exit ; fi

# check for arguments
if [ ! $1 ] || [ ! $2 ] ; then
    echo;echo "This restores one whole database made using innobackupex or xtrabackup,"
    echo "    but ONLY if ALL tables are InnoDB/XtraDB - any MyISAM tables will break this!"
    echo "Requires innodb_file_per_table and innodb_import_table_from_xtrabackup set to 1."; echo
    echo "Syntax:  inno_restore_database.sh: <database> <restore_directory(backupdir)>"
    echo "Example: inno_restore_database.sh: newdatabase /mnt/backups/1970-01-01_00-00-00/backupdatabase";echo
    echo "Warning: THIS WILL OVERWRITE THE DATABASE YOU ARE RESTORING TO!"
    echo "Ensure you set the datadir and mysqluser in the script!"
    echo;exit
fi

database=$1
restoredir=$2

# Check for transition tables leftovers
if [  -f ${restoredir}/#sql-* ] ; then rm -rf ${restoredir}/#sql-* ; fi

# Check for the mysqlfrm command
which mysqlfrm > /dev/null 2>&1
if [ $? -ne 0 ] ; then echo "Could not find the mysqlfrm utility. Install mysql-utilities."; exit ; fi

# Check datadir for mysql install, figure mysql/user.frm should probably exist.
if [ ! -f ${datadir}/mysql/user.frm ] ; then echo "MySQL datadir not correct" ; exit ; fi

# Check the restore directory, looking for a cfg/exp/idb for each frm.
if [ ! -f ${restoredir}/db.opt ] ; then echo "Restore directory invalid, couldn't find db.opt in it"; exit ; fi
stoperror=0
rm -rf ${restoredir}/#sql-
for restorename in ${restoredir}/*.frm
do
    chkname=$(echo ${restorename}|sed s/.frm$//)
    for exten in cfg exp ibd
    do
        if [ ! -f ${chkname}.${exten} ] ; then stoperror=1 ; fi
    done
done
if [ ${stoperror} -eq 1 ] ; then
    echo "Could not file valid restore directory files (need a cfg, exp and ibd for each frm)"
    echo "Did you specify a valid database directory within a backup?"
    echo "Did you prepare or apply-log to the backup directory?"
    exit
fi

# Get username and password if the fields are blank.
#if [ -z $username ] ; then read -p "Username: " username ; fi
#if [ -z $password ] ; then read -s -p "Password: " password ; echo ; fi

# Check mysql permissions for the given user.
stoperror=0
grants=$(mysql -B -u ${username} -p${password} mysql -e "show grants for current_user"|grep 'ON *.* TO')
if [ $? -ne 0 ] ; then exit ; fi
if [[ ${grants} == *"ALL PRIVILEGES"* ]] ; then stoperror=1 ; fi
if [[ ${grants} == *CREATE* ]] && [[ ${grants} == *DROP* ]] && [[ ${grants} == *ALTER* ]] ; then stoperror=1 ; fi
if [ ${stoperror} != 1 ] ; then echo "User $username does not have global CREATE, DROP and ALTER" ; exit ; fi


################################################################################
# Okay, all the user-error logic I can think of is out of the way, finally time to script this.

# drop database if exists
mysql -B -u ${username} -p${password} -e "DROP DATABASE IF EXISTS $database"

# create database
mysql -B -u ${username} -p${password} -e "CREATE DATABASE $database"

# get directory for the original DB name
backupdb=$(find ${restoredir} -maxdepth 0 -type d -printf "%f\n" |cut -d '/' -f 1)

# Import the table structure, create them all. Gotta massage the data a bit from mysqlfrm.
echo "Importing create table statements from frm files..." ; echo
mysqlfrm -q --user=root --server=${username}:${password}@localhost:${myport} --port=${mysqlfrmport} ${restoredir} |
    grep -vE "^#|WARNING: Using a password on the command line interface can be insecure." |
    sed s/^$/';'/ | sed s/^'CREATE TABLE `'${backupdb}/'CREATE TABLE `'${database}/ | sed s/^') ENGINE=InnoDB'/') ENGINE=Memory ROW_FORMAT=compact'/ |
    mysql -B -u ${username} -p${password}
echo "Table structure imported."

# for each frm file...
for frmname in ${restoredir}/*.frm
do
    tablename=$(find ${frmname} -printf "%f\n"|sed s/.frm$//)

    # ALTER TABLE ... DISCARD TABLESPACE - junks those pesky datafiles we don't want.
    mysql -B -u ${username} -p${password} ${database} -e "ALTER TABLE $tablename FORCE, ALGORITHM=COPY; ALTER TABLE $tablename ENGINE=InnoDB; ALTER TABLE $tablename DISCARD TABLESPACE;"
 
    # Copy each table's cfg/exp/ibd files to datadir and chown them.
    # Note: I don't need cfg files, you might want to add them for 5.6.
    # Not including them because mysql won't delete them on drop database.
    for exten in exp ibd cfg
    do
        # If they have rsync, let's use that to give them progress. I'm sure some of those datafiles are large.
        #which rsync > /dev/null 2>&1
        #if [ $? -eq 0 ]
        #then
        #    rsync --progress $restoredir/$tablename.$exten $datadir/$database/$tablename.$exten
        #else
            # Damn, I wish I knew the backslash trick earlier in my life to unset an alias, that's handy!
            \mv -v ${restoredir}/${tablename}.${exten} ${datadir}/${database}/${tablename}.${exten}
        #fi
        chown $(find ${datadir}/${database}/${tablename}.frm -printf "%u.%g") ${datadir}/${database}/${tablename}.${exten}
    done
    # ALTER TABLE ... IMPORT TABLESPACE
    mysql -B -u ${username} -p${password} ${database} -e "ALTER TABLE $tablename IMPORT TABLESPACE"
done

mysql -u ${username} -p${password} -e "GRANT ALL PRIVILEGES ON $database.* TO 'bitrix0'@'localhost'"

echo
echo "All done.  Hopefully that worked, huh?  No promises."
echo "You're probably missing foreign keys and such. Better check. Read the mysqlfrm docs."
echo "Hopefully you imported into a test database first so you can check it, right?"
