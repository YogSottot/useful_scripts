#!/usr/bin/env bash
set -e

source_ssh_host="${1}"
source_dir="${2}"
target_dir="${3}"

source_version=`ssh ${source_ssh_host} "grep -m 1 SM_VERSION ${source_dir}/bitrix/modules/main/classes/general/version.php | tr -dc '0-9.'"`
target_version=`grep -m 1 SM_VERSION ${target_dir}/bitrix/modules/main/classes/general/version.php | tr -dc '0-9.'`

echo source_version: "${source_version}"
echo target_version: "${target_version}"


if [ "${source_version}" == "${target_version}" ]
then
    echo "Bitrix version identical"
else
    echo "Bitrix version different!"
    echo "Update your source!"
    echo "DB download is stopped!"
    exit 1
fi
