#!/usr/bin/env bash
set -eo pipefail

ssh_host="${1}"
source_dir="${2}"
target1_dir="${3}"
target2_dir="${4}"

source_version=`ssh ${ssh_host} "grep -m 1 SM_VERSION ${source_dir}/bitrix/modules/main/classes/general/version.php | tr -dc '0-9.'"`
target1_version=`grep -m 1 SM_VERSION ${target1_dir}/aliev.murad-semicvetic.com.s-webs.ru/bitrix/modules/main/classes/general/version.php | tr -dc '0-9.'`
target2_version=`grep -m 1 SM_VERSION ${target2_dir}/bitrix/modules/main/classes/general/version.php | tr -dc '0-9.'`

echo source_version: "${source_version}"
echo target1_version: "${target1_version}"
echo target2_version: "${target2_version}"


if [ "${source_version}" == "${target1_version}" -a "${source_version}" == "${target2_version}" ]
then
    echo "Bitrix version identical"
else
    echo "Bitrix version different"
    echo "Update your source!"
    echo "DB download is stopped!"
    exit 1
fi
