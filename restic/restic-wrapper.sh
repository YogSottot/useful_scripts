#!/usr/bin/env bash

SCRIPTNAME=$(basename $0)
LOCKDIR="/var/lock/${SCRIPTNAME}"
PIDFILE="${LOCKDIR}/pid"

if ! mkdir $LOCKDIR 2>/dev/null
then
    # lock failed, but check for stale one by checking if the PID is really existing
    PID=$(cat $PIDFILE)
    if ! kill -0 $PID 2>/dev/null
    then
       echo "Removing stale lock of nonexistent PID ${PID}" >&2
       rm -rf $LOCKDIR
       echo "Restarting myself (${SCRIPTNAME})" >&2
       exec "$0" "$@"
    fi
    echo "$SCRIPTNAME is already running, bailing out" >&2
    exit 1
else
    # lock successfully acquired, save PID
    echo $$ > $PIDFILE
fi

trap "rm -rf ${LOCKDIR}" QUIT INT TERM EXIT

# Do stuff
# rc files to work with
rc_dir="/opt/backup/restic/rc.files"
rc_file="$1"

mail="$2"
hostname=`/bin/hostname`

# if rc file does not exists exit with code 1
if [[ ! "$rc_file" ]] ; then
  echo "You have not indicated a repo to work with"
  exit 1
elif [[ ! -e "$rc_dir/$rc_file.rc" ]] ; then
  echo "There is no 'rc' file called $rc_file"
  exit 1
fi

# source rc files
source "$rc_dir/$rc_file.rc"
#export RESTIC_REPOSITORY=$var_inside_your_rc_file
#export RESTIC_PASSWORD=$var_inside_your_rc_file
cd ${BACKUP_ROOT}

/usr/local/bin/restic "${@:3}" > /tmp/restic_log_${@:3:1} 2>&1
exitcode="$?"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Restic "${@:3:1}" on ${hostname} repo ${rc_file} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/restic_log_${@:3:1}
else
    mailx -s "$(echo -e  "Restic "${@:3:1}" on ${hostname} repo ${rc_file} is succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/restic_log_${@:3:1}
fi

/usr/local/bin/restic cache --cleanup

exit 0
