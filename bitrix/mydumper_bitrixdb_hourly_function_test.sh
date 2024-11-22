#!/usr/bin/env bash
set -xeo pipefail

# Global Variables
doc_root="$1"
mail="$2"
name="$3"
cpu=$(nproc --ignore=2)
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
LOCKDIR=""
PIDFILE=""
backup_dir=""
exitcode=0

# Functions
log_error() {
    local msg="$1"
    printf "[%s] ERROR: %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$msg" >&2
}

log_info() {
    local msg="$1"
    printf "[%s] INFO: %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$msg"
}

check_prerequisites() {
    local commands=("mydumper" "timeout" "nice" "ionice" "mailx" "tar" "grep" "sed")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_error "Command '$cmd' not found. Please install it before running the script."
            exit 1
        fi
    done
}

initialize() {
    if [[ -z $doc_root || -z $mail ]]; then
        printf "Usage: %s /path/to/document/root mail [backup_name]\n" "$SCRIPT_NAME"
        exit 1
    fi

    if [[ -z $name ]]; then
        name=$(hostname)
    fi

    backup_dir="/opt/backup/backup_${name}"
    mkdir -p "${backup_dir}"
    LOCKDIR="/var/lock/bitrixdb_${name}"
    PIDFILE="${LOCKDIR}/pid"
}

grep_dbname() {
    settings=${doc_root}/bitrix/.settings.php
    dbconn=${doc_root}/bitrix/php_interface/dbconn.php

    readcfg() {
            grep -m 1 $1 ${settings} | sed "s/.*' => '\(.*\)',.*/\1/"
    }

    host=`readcfg host`
    username=`readcfg login`
    password=`readcfg password`
    database=`readcfg database`


    utf=`grep 'BX_UTF' ${dbconn} | grep true`

    if [ -z "$utf" ]; then
        charset=cp1251
    else
        charset=utf8
    fi
}

grep_config() {
    function getValueFromINI() {
        local sourceData="$1"; local paramName="$2";
        ## 1. Get value "platform=%OUR_VALUE%"
        ## 2. Remove illegal characters
        echo "$(echo "$sourceData" | sed -n '/^'"${paramName}"'\ =\(.*\)$/s//\1/p' | tr -d "\r" | tr -d "\n")"
    }

    function getValueFromINI2() {
        local sourceData="$1"; local paramName="$2";
        ## 1. Get value "platform=%OUR_VALUE%"
        ## 2. Remove illegal characters
        echo "$(echo "$sourceData" | sed -n '/^'"${paramName}"'\ =\(.*\)$/s//\1/p'  | tr -d "\r" | tr -d "\n" | tr -d "/")"
    }

    sectionContent=$(sed -n '/^\[cloud\]/,/^\[/p' /opt/backup/scripts/config.ini | sed -e '/^\[/d' | sed -e '/^$/d');
    project=$(getValueFromINI "$sectionContent" "project");
    login=$(getValueFromINI "$sectionContent" "login");
    password=$(getValueFromINI "$sectionContent" "password");
    url=$(getValueFromINI "$sectionContent" "auth-url");
    storage_dir=$(getValueFromINI2 "$sectionContent" "dir");
}

acquire_lock() {
    if ! mkdir "$LOCKDIR" 2>/dev/null; then
        local pid; pid=$(<"$PIDFILE")
        if ! kill -0 "$pid" 2>/dev/null; then
            log_info "Removing stale lock for PID $pid"
            rm -rf "$LOCKDIR"
            log_info "Restarting $SCRIPT_NAME"
            exec "$0" "$@"
        fi
        log_error "$SCRIPT_NAME is already running. Exiting."
        exit 1
    fi
    echo $$ >"$PIDFILE"
    trap "cleanup_lock" QUIT INT TERM EXIT
}

cleanup_lock() {
    rm -rf "$LOCKDIR"
}

backup_database() {
    local log_file="/tmp/${SCRIPT_NAME}_${name}_log"
    
    log_info "Starting database backup..."

    # Run main backup
    if ! timeout -k 15s 3600s nice -n 19 ionice -c2 -n7 \
        mydumper --defaults-file /root/.my.cnf --threads "${cpu}" --compress --less-locking --use-savepoints  --regex "^(?=(?:(${database}\.)))(?!(?:(${database}\.b_xml_tree_import_1c)))" --outputdir "${backup_dir}" &>"$log_file"; then
        exitcode=$?
        log_error "Mydumper backup failed. See log at $log_file"
        return
    fi
}

archive_and_upload() {
    local tar_file="/opt/backup/${name}_${database}.tar"
    local log_file="/tmp/${SCRIPT_NAME}_${name}_log"

    tar -C /opt/backup -cvf "$tar_file" "backup_${name}" &>>"$log_file"
    rm -rf "$backup_dir"

    if ! timeout -k 15s 3600s nice -n 19 ionice -c2 -n7 \
        /root/.local/bin/swift -v --os-auth-url "${url}" --os-region-name ru-1 --auth-version 3 \
        --os-project-id "${project}" --os-user-id "${login}" --os-password "${password}" \
        upload --object-name "$(date +%Y-%m-%d-%H:%M)_DB_hourly_${name}/" \
        "${storage_dir}" "$tar_file" &>>"$log_file"; then
        log_error "Swift upload failed. See log at $log_file"
        exitcode=$?
    fi
    rm -rf "$tar_file"
}

notify_on_failure() {
    local log_file="/tmp/${SCRIPT_NAME}_${name}_log"
    if [[ $exitcode -eq 124 ]]; then
        mailx -s "$(printf "Backup MYDUMPER hourly for %s is Timeout\nContent-Type: text/plain; charset=UTF-8" "$name")" \
            "$mail" <"$log_file"
    elif [[ $exitcode -ne 0 ]]; then
        mailx -s "$(printf "Backup MYDUMPER hourly for %s is Error\nContent-Type: text/plain; charset=UTF-8" "$name")" \
            "$mail" <"$log_file"
    else
        log_info "Backup and upload completed successfully."
    fi
}

main() {
    check_prerequisites
    initialize
    grep_dbname
    grep_config
    acquire_lock
    backup_database
    archive_and_upload
    notify_on_failure
    cleanup_lock
}

main "$@"
