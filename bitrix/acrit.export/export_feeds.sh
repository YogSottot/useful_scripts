#!/bin/bash
#
# Оркестратор параллельного запуска фидов acrit.exportpro.
# Заменяет единый cron_events.php с таймаутом 70 секунд на параллельный запуск
# отдельных профилей через export_run_profile.php.
#
# Использование:
#   Прямой запуск:
#     /home/bitrix/www/bitrix/php_interface/cron/export_feeds.sh
#
#   Через crontab (рекомендуется):
#     */5 * * * * /usr/bin/flock -xn /tmp/acrit_feeds_batch.lock /home/bitrix/www/bitrix/php_interface/cron/export_feeds.sh
#
# Конфигурация:
#   MAX_PARALLEL  — максимум одновременных процессов экспорта (по умолчанию 4)
#   FEED_TIMEOUT  — таймаут одного фида в секундах (по умолчанию 1800 = 30 минут)
#   LOG_FILE      — путь к лог-файлу
#

set -euo pipefail

# ========== Конфигурация ==========
PHP="/usr/bin/php"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOC_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

LIST_PROFILES="${SCRIPT_DIR}/export_list_profiles.php"
RUN_PROFILE="${SCRIPT_DIR}/export_run_profile.php"

LOCK_DIR="/tmp/acrit_feeds"
LOG_DIR="${DOC_ROOT}/bitrix/tools/acrit.exportpro/logs"
LOG_FILE="${LOG_DIR}/export_feeds_$(date +%Y%m%d).log"

MAX_PARALLEL=${MAX_PARALLEL:-4}
FEED_TIMEOUT=${FEED_TIMEOUT:-1800}
# ==================================

mkdir -p "${LOCK_DIR}"
mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Удаление логов старше 7 дней
find "${LOG_DIR}" -name "export_feeds_*.log" -mtime +7 -delete 2>/dev/null || true

log "=== Запуск оркестратора фидов (MAX_PARALLEL=${MAX_PARALLEL}, FEED_TIMEOUT=${FEED_TIMEOUT}s) ==="

# Получаем список активных профилей
PROFILES=$($PHP -f "${LIST_PROFILES}" 2>/dev/null)

if [ -z "${PROFILES}" ]; then
    log "Нет активных профилей для экспорта"
    exit 0
fi

PROFILE_COUNT=$(echo "${PROFILES}" | wc -l | tr -d ' ')
log "Найдено профилей: ${PROFILE_COUNT}"

RUNNING=0
PIDS=()
PROFILE_IDS=()

# Функция ожидания завершения одного из параллельных процессов
wait_for_slot() {
    while [ ${RUNNING} -ge ${MAX_PARALLEL} ]; do
        for i in "${!PIDS[@]}"; do
            if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
                wait "${PIDS[$i]}" 2>/dev/null || true
                log "Профиль ${PROFILE_IDS[$i]}: процесс завершён (PID ${PIDS[$i]})"
                unset 'PIDS[i]'
                unset 'PROFILE_IDS[i]'
                RUNNING=$((RUNNING - 1))
            fi
        done
        if [ ${RUNNING} -ge ${MAX_PARALLEL} ]; then
            sleep 2
        fi
    done
}

# Запускаем профили параллельно группами
while IFS= read -r PROFILE_ID; do
    # Пропускаем пустые строки
    [ -z "${PROFILE_ID}" ] && continue
    PROFILE_ID=$(echo "${PROFILE_ID}" | tr -d '[:space:]')

    # Проверяем, не запущен ли уже этот профиль (flock на уровне профиля)
    LOCK_FILE="${LOCK_DIR}/feed_${PROFILE_ID}.lock"

    # Ждём свободный слот
    wait_for_slot

    # Запускаем профиль в фоне с flock и timeout
    (
        flock -xn 200 || { echo "[$(date '+%Y-%m-%d %H:%M:%S')] Профиль ${PROFILE_ID}: уже запущен, пропускаем" >> "${LOG_FILE}"; exit 0; }
        timeout "${FEED_TIMEOUT}" ${PHP} -f "${RUN_PROFILE}" "profile_id=${PROFILE_ID}" >> "${LOG_FILE}" 2>&1
        EXIT_CODE=$?
        if [ ${EXIT_CODE} -eq 124 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Профиль ${PROFILE_ID}: TIMEOUT (превышен лимит ${FEED_TIMEOUT}s)" >> "${LOG_FILE}"
        elif [ ${EXIT_CODE} -ne 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Профиль ${PROFILE_ID}: ошибка (exit code ${EXIT_CODE})" >> "${LOG_FILE}"
        fi
    ) 200>"${LOCK_FILE}" &

    PIDS+=($!)
    PROFILE_IDS+=("${PROFILE_ID}")
    RUNNING=$((RUNNING + 1))

    log "Профиль ${PROFILE_ID}: запущен (PID $!, слот ${RUNNING}/${MAX_PARALLEL})"

done <<< "${PROFILES}"

# Ожидаем завершения всех запущенных процессов
log "Ожидание завершения всех процессов..."
for i in "${!PIDS[@]}"; do
    if kill -0 "${PIDS[$i]}" 2>/dev/null; then
        wait "${PIDS[$i]}" 2>/dev/null || true
        log "Профиль ${PROFILE_IDS[$i]}: процесс завершён (PID ${PIDS[$i]})"
    fi
done

log "=== Оркестратор завершён ==="
