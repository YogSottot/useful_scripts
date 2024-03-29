#!/usr/bin/env bash
set -eo pipefail
# use
# curl -sL https://raw.githubusercontent.com/YogSottot/useful_scripts/master/initial_server_setup/mysql_setup.sh | bash

# curl -sL https://raw.github.com/major/MySQLTuner-perl/master/mysqltuner.pl | perl

# curl -sL https://raw.githubusercontent.com/RootService/tuning-primer/master/tuning-primer.sh | bash

#  https://ruhighload.com/Как+ускорить+mysqldump%3f

cat <<EOT >> /etc/mysql/conf.d/z_bx_custom.cnf
[mysqld]
max_connections = 60
#thread_cache_size = 128
#
#tmpdir = /run/mysqld
#max_heap_table_size = 128M
#tmp_table_size = 128M
#
long_query_time = 0.002
log-queries-not-using-indexes
#slow-query-log = 1
#slow-query-log-file = /var/log/mysql/slow.log
low-priority-updates
log_timestamps = SYSTEM

sort_buffer_size = 256K
join_buffer_size = 1M

key_buffer_size = 8M

#query_cache_size = 0
#query_cache_type = 0
#query_cache_limit = 64M
#query_cache_min_res_unit = 1K
#
#innodb_log_file_size = 512M
#innodb_log_buffer_size = 16M
#innodb_buffer_pool_size = 4096M
#innodb_buffer_pool_instances = 4
#
# https://www.percona.com/doc/percona-server/5.7/performance/threadpool.html
# thread_handling=pool-of-threads
# https://www.percona.com/blog/2006/06/05/innodb-thread-concurrency/
#innodb_thread_concurrency = 2
#innodb_commit_concurrency = 2
#innodb_read_io_threads = 8
#innodb_write_io_threads = 8
#
table_open_cache = 240000
#table_definition_cache = 2000
#
#innodb_flush_log_at_trx_commit = 0
#innodb_flush_method = O_DSYNC

interactive_timeout = 600
wait_timeout = 600
max_connect_errors = 10000
#max_allowed_packet = 256M

# Database charset parameters
#character-set-server = utf8mb4
#collation-server = utf8mb4_unicode_ci
#init-connect = "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci"
#character-set-server = utf8
#collation-server = utf8_unicode_ci
#init-connect = "SET NAMES utf8 COLLATE utf8_unicode_ci"
#skip-character-set-client-handshake
skip-name-resolve
skip-networking
sync_binlog = 0
default_password_lifetime=0

skip_log_bin = 1
event_scheduler = 0

# if hdd
# innodb_flush_neighbors=1
# if ssd
# innodb_flush_neighbors=0

thread_stack=256K

# disagree with https://dev.1c-bitrix.ru/community/forums/messages/forum32/topic122887/message621578/#message621578
# innodb_strict_mode = ON

# https://stackoverflow.com/a/63490321
# innodb_lru_scan_depth=100  # from 1024 to conserve 90% CPU cycles used for function
# innodb_io_capacity=1900  # from 200 to allow more IOPSecond to your storage device
# innodb_flush_neighbors=2  # from 0 to expedite writing to current extent
# innodb_max_dirty_pages_pct_lwm=1  # from 10 percent to expedite writes
# innodb_max_dirty_pages_pct=1  # from 90 percent to reduce innodb_buffer_pool_pages_dirty count
# innodb_change_buffer_max_size=50  # from 25 percent to expedite your high volume activity

EOT

systemctl restart mysql
