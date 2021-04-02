#!/bin/bash
#
# Simple and generic shell script aiming to be a reference/template to
# create custom scripts to use with imunify-notifier.
#
# https://docs.imunify360.com/features/#notifications
#
# Builtin features:
# - Once an event is triggered:
#		1- it can be sent a mail to a list of RCPT
# 		2- it can save a formated message into a file.
#
# Users can use this script as reference to append customizations, look at
# "append your stuff here" in payload_handler function.
#
# do not forget to set +x bits to this script file, also since imunity-notifier daemon
# drops privileges to _imunify user, make sure of setting group's permission accordingly
# chown root:_imunify hook_script.sh
#
# This script depends on `jq' tool for handling json input
# For CloudLinux/AlmaLinux/CentOS:
# 	sudo yum install jq oniguruma
#
# For Debian based OS:
# 	sudo apt install jq
#mail=$1

#if [ -z ${mail} ]; then
#	echo Usage: $0 your_mail
#	exit
#fi

hostname=`/bin/hostname`

MAIL_ENABLE=yes				# default no, change to "yes" for enabling
MAIL_TO="your_mail"	# for multiple email addresses, use commas

FILE_ENABLE=yes				# default yes, change to "no" for disabling
DIR_NAME="imunify-script-files"		# /tmp subdirectory

# bring up our variables
init_data()
{
	data=$(cat) 	# data within payload coming from imunify-notifier.

	# debug stdin, it creates a json file with payload within.
	# uncomment the following line.
	# echo $data > /tmp/imunify-script-dump.json

	# parse JSON data with jq for getting event_id
	event_id=$(jq -r '.event_id' <<< ${data})
}

# parser_* helper functions to assign vars from json data

parser_realtime_malware_found()
{
	period_started=$(jq -r '.period_started' <<< ${data})
	period_finished=$(jq -r '.period_finished' <<< ${data})
	malicious_total=$(jq -r '.malicious_total' <<< ${data})
	malicious_files=$(jq -r '.malicious_files[]' <<< ${data})
}

parser_malware_found()
{
	period_started=$(jq -r '.started' <<< ${data})
	period_finished=$(jq -r '.completed' <<< ${data})
	malicious_total=$(jq -r '.total_malicious' <<< ${data})
	malicious_files=$(jq -r '.malicious_files[]' <<< ${data})
}

parser_scan_started()
{
	period_started=$(jq -r '.started' <<< ${data})
	scan_id=$(jq -r '.scan_id' <<< ${data})
}

parser_scan_finished()
{
	period_started=$(jq -r '.started' <<< ${data})
	period_finished=$(jq -r '.completed' <<< ${data})
	scan_id=$(jq -r '.scan_id' <<< ${data})
	malicious_total=$(jq -r '.total_malicious' <<< ${data})
	malicious_files=$(jq -r '.malicious_files[]' <<< ${data})
}

parser_script_blocked()
{
	period_started=$(jq -r '.period_started' <<< ${data})
	period_finished=$(jq -r '.period_finished' <<< ${data})
	malicious_total=$(jq -r '.events_total' <<< ${data})
	malicious_files=$(jq -r '.blocked_scripts[].path' <<< ${data})
}

# human-readable message
format_msg()
{
	if [ "${event_id}" = "USER_SCAN_STARTED" ] ||
	    [ "${event_id}" = "CUSTOM_SCAN_STARTED" ]; then
		echo "Scan ID: $scan_id, ${event_msg} \
			$(date -ud "@"${period_started}) \
			on $(hostname)"
	elif [ "${event_id}" = "USER_SCAN_FINISHED" ] ||
	    [ "${event_id}" = "CUSTOM_SCAN_FINISHED" ]; then
		echo "Scan ID: $scan_id. \
			During the period from $(date -ud "@"${period_started}) to \
			$(date -ud "@"${period_finished}) on $(hostname) \
			${event_msg} a total of ${malicious_total} malware file(s): \
			${malicious_files}."
	else
		echo "During the period from $(date -ud "@"${period_started}) to \
			$(date -ud "@"${period_finished}) on $(hostname) \
			${event_msg} a total of ${malicious_total} malware file(s): \
			${malicious_files}."
	fi
}

# handles the script-builtin features
builtin_features_handler()
{
	if [ "$MAIL_ENABLE" = "yes" ]; then
		send_mail
	fi
	if [ "$FILE_ENABLE" = "yes" ]; then
		file_save
	fi
}

# prepare and send mail, requires set $MAIL_ENABLE to yes
send_mail()
{
msg=$(format_msg)
cat <<EOF | mailx -s "imunifyav on ${hostname}: ${event_id}" $MAIL_TO
$msg
EOF
}

# push a formated text into a file located by default in $DIR_NAME
# it is enabled by default by setting $FILE_ENABLE.
file_save()
{
	msg=$(format_msg)
	test -d "$DIR_NAME" || mkdir "/tmp/${DIR_NAME}"
	savefile=$(mktemp --tmpdir ${DIR_NAME}/imunify-script-${event_id}.XXXXXXXXXXXXXXXXXXXXXXX)
	echo $msg > $savefile
}

# digest the payload gave by imunity-notifier handling the supported events
payload_handler()
{
	case ${event_id} in
		REALTIME_MALWARE_FOUND)
			event_msg="realtime malware scan has detected"
			parser_realtime_malware_found
			builtin_features_handler
			# append your stuff here
			;;
		USER_SCAN_MALWARE_FOUND)
			event_msg="user malware scan has detected"
			parser_malware_found
			builtin_features_handler
			# append your stuff here
			;;
		SCRIPT_BLOCKED)
			event_msg="proactive defense has blocked"
			parser_script_blocked
			builtin_features_handler
			# append your stuff here
			;;
		USER_SCAN_STARTED)
			event_msg="user scan started at"
			parser_scan_started
			builtin_features_handler
			# append your stuff here
			;;
		CUSTOM_SCAN_STARTED)
			event_msg="custom scan started at"
			parser_scan_started
			builtin_features_handler
			# append your stuff here
			;;
		USER_SCAN_FINISHED)
			event_msg="user scan finished with"
			parser_scan_finished
			builtin_features_handler
			# append your stuff here
			;;
		CUSTOM_SCAN_FINISHED)
			event_msg="custom scan finished with"
			parser_scan_finished
			builtin_features_handler
			# append your stuff here
			;;
		CUSTOM_SCAN_MALWARE_FOUND)
			event_msg="custom malware scan has detected"
			parser_malware_found
			builtin_features_handler
			# append your stuff here
			;;
	*)
		echo "unhandled" 1>&2
		exit 1
	esac
}

# starting up
init_data
payload_handler
