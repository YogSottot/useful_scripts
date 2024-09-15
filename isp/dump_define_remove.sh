#!/usr/bin/env bash
set -eo pipefail

db_name=$1
user=$2
host=$3

# Ensure user and host are sanitized to avoid potential command injection
if [[ -z "$db_name" || -z "$user" || -z "$host" ]]; then
  printf "Usage: %s <db_name> <mysql_user> <mysql_host>\n" "$0" >&2
  exit 1
fi

# sed -i -e 's|^/[*]!50001 CREATE ALGORITHM=UNDEFINED [*]/|/*!50001 CREATE */|' -e '/^[/][*]!50013 DEFINER=/d' ${db_name}
# sed -i -E 's/DEFINER=`[^`]*`@`[^`]*`/DEFINER=CURRENT_USER/g' ${db_name}
# sed -i -e '/^[/][*]!50013 DEFINER=/d' ${db_name}

# for php 7.3 and older
# ALTER USER ''@'localhost' IDENTIFIED WITH mysql_native_password BY '';
# SET PASSWORD FOR ''@'localhost' = OLD_PASSWORD('');

# for php 7.4+
# ALTER USER ''@'localhost' IDENTIFIED WITH caching_sha2_password BY '';


# Use sed to replace the DEFINER clause correctly
sed -i -E "s/DEFINER=\`[^@]+\`@\`[^\`]*\`/DEFINER=\`$user\`@\`$host\`/g" "$db_name"
