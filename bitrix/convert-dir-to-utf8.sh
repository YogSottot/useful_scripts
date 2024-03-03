#!/usr/bin/env bash

# wget https://raw.githubusercontent.com/YogSottot/useful_scripts/master/bitrix/convert-dir-to-utf8.sh
# https://stackoverflow.com/a/52823709
# apt-get -y install recode uchardet > /dev/null
# yum -y install recode uchardet
find "$1" -name '*.php' -type f -exec grep -Iq . {} \; -print0 |
while IFS= read -r -d $'\0' LINE_FILE; do
  CHARSET=$(uchardet $LINE_FILE)
  REENCSED=`echo $CHARSET | sed 's#^x-mac-#mac#'`
  echo "\"$CHARSET\" \"$LINE_FILE\""

  # NOTE: Convert/reconvert to utf8. By Questor
  recode $REENCSED..UTF-8 "$LINE_FILE" 2> STDERR_OP 1> STDOUT_OP

  STDERR_OP=$(cat STDERR_OP)
  rm -f STDERR_OP
  if [ -n "$STDERR_OP" ] ; then

    # NOTE: Convert/reconvert to utf8. By Questor
    bash -c "</dev/tty vim -u NONE +\"set binary | set noeol | set nobomb | set encoding=utf-8 | set fileencoding=utf-8 | wq\" \"$LINE_FILE\""

  else

    # NOTE: Remove "BOM" if exists as it is unnecessary. By Questor
    # [Refs.: https://stackoverflow.com/a/2223926/3223785 ,
    # https://stackoverflow.com/a/45240995/3223785 ]
    sed -i '1s/^\xEF\xBB\xBF//' "$LINE_FILE"

  fi
done
