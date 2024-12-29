#!/usr/bin/env bash
set -eo pipefail

SCRIPTNAME=$(basename $0)
LOCKDIR="/var/lock/${SCRIPTNAME}_${rc_file}"
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
HC_UUID="$3"
# Generate Run IDs
RID=$(uuidgen)

source "$rc_dir/$rc_file.rc"
#export RESTIC_REPOSITORY=$var_inside_your_rc_file
#export RESTIC_PASSWORD=$var_inside_your_rc_file
# On start script
curl -fsS -m 30 --retry 5 "${HC_URL}/start?rid=$RID"

cd ${BACKUP_ROOT}
diff_id=$(echo `/usr/local/bin/restic snapshots --json | /usr/bin/jq -r '.[-2:][].id'`)


/usr/local/bin/restic diff ${diff_id} > /tmp/restic_log_diff_${rc_file} 2>&1
exitcode="$?"

# On end script with exit code and run ID
curl -fsS -m 30 --retry 5 --data-binary @/tmp/restic_log_diff_${rc_file} "${HC_URL}/${exitcode}?rid=$RID"

# output
if [ "${exitcode}" -ne "0" ]; then
    mailx -s "$(echo -e  "Restic diff on ${hostname} repo ${rc_file} is error\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/restic_log_diff_${rc_file}
else
    mailx -s "$(echo -e  "Restic diff on ${hostname} repo ${rc_file} is succesfull\nContent-Type: text/plain; charset=UTF-8")" ${mail} < /tmp/restic_log_diff_${rc_file}
fi

/usr/local/bin/restic cache --cleanup

exit 0
