#!/usr/bin/env bash
set -eo pipefail

pathToIniFile=/root/.my.cnf

## Parse data from passed content of ini section
function getValueFromINI() {
  local sourceData=$1; local paramName=$2;
  ## 1. Get value "platform=%OUR_VALUE%"
  ## 2. Remove illegal characters
  echo $(echo "$sourceData" | sed -n '/^'$paramName'=\(.*\)$/s//\1/p' | tr -d "\r" | tr -d "\n");
}

sectionContent=$(sed -n '/^\[client\]/,/^\[/p' $pathToIniFile | sed -e '/^\[/d' | sed -e '/^$/d');
username=$(getValueFromINI "$sectionContent" "user");
password=$(getValueFromINI "$sectionContent" "password");
socket=$(getValueFromINI "$sectionContent" "socket");

echo -e "\n[mydumper]\nuser=${username}\npassword=${password}\nsocket=${socket}\n\n[myloader]\nuser=${username}\npassword=${password}\nsocket=${socket}\n" >> $pathToIniFile
