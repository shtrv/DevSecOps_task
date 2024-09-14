#!/bin/bash

# Временные директории
EXTRACTION_DIR="/tmp/extraction"
COMMON_DIR="$EXTRACTION_DIR/common"
SEVERE_DIR="$EXTRACTION_DIR/severe"

custom_gather() {
    local host_info="$COMMON_DIR/host_info"
    mkdir -p "$host_info"

    echo "Сбор информации о системе..."

    uname -a > "$host_info/uname.txt"
    df -h > "$host_info/disk_usage.txt"
    free -h > "$host_info/memory.txt"
    ps aux > "$host_info/processes.txt"
    netstat -tuln > "$host_info/network_connections.txt"
    uptime > "$host_info/uptime.txt"
    ip addr show > "$host_info/ip_addr.txt"
    lscpu > "$host_info/lscpu.txt"

    echo "Информация о хосте собрана."
}

validate_date() {
    local input_date="$1"

    if ! parsed_date=$(date -d "$1" "+%Y-%m-%d" 2>/dev/null); then
        echo "Ошибка: неверный формат даты. Используйте формат YYYY-MM-DD."
        exit 1
    fi
    
    if [[ "$1" != "$parsed_date" ]]; then
        echo "Ошибка: неверная дата."
        exit 1
    fi
}

create_temp_dirs() {
    mkdir -p "$COMMON_DIR" "$SEVERE_DIR"
}

gather_logs() {
    local start_date="$1"
    local end_date="$2"

    echo "Сбор журналов с $start_date до $end_date..."

    for service_dir in /opt/app-x/service-*; do
        if [[ -d "$service_dir" ]]; then
            service_name=$(basename "$service_dir")
            
            # Копируем файлы журналов по датам
            find "$service_dir" -type f -name "*$start_date*" -or -newermt "$start_date" ! -newermt "$end_date" -exec cp --parents {} "$COMMON_DIR" \;
        else
            echo "Предупреждение: директория $service_dir не найдена."
        fi
    done
}

gather_severe_logs() {
    local log_date="$1"
    
    echo "Сбор данных уровня SEVERE за $log_date..."

    for service_dir in /opt/app-x/service-*; do
        if [[ -d "$service_dir" ]]; then
            service_name=$(basename "$service_dir")
            persistent_log="$service_dir/persistent-debug.log"

            if [[ -f "$persistent_log" ]]; then
                grep "^$log_date.*\[LOG_LEVEL: SEVERE\]" "$persistent_log" > "$SEVERE_DIR/${service_name}_severe_$log_date.log"
                
                # (*) Замена $FOO на ${FOO} в severe логах
                sed -i 's/\$\([A-Za-z_][A-Za-z0-9_]*\)/${\1}/g' "$SEVERE_DIR/${service_name}_severe_$log_date.log"
            else
                echo "Предупреждение: файл $persistent_log не найден."
            fi
        fi
    done
}

archive_data() {
    local password="$1"
    local archive_name="/tmp/extraction_$(date +"%Y%m%d_%H%M%S").tar.gz"
    
    echo "Создаём зашифрованный архив..."

    tar -czf - "$EXTRACTION_DIR" | openssl enc -aes-256-cbc -e -k "$password" -out "$archive_name"
    
    echo "Архив создан: $archive_name"
    echo "Пароль для расшифровки: $password"
}

cleanup() {
    echo "Очистка временных файлов..."
    rm -rf "$EXTRACTION_DIR"
}


# Пользовательский ввод даты
read -p "Введите дату в формате YYYY-MM-DD: " user_date
validate_date "$user_date"

# Получаем текущую дату
current_date=$(date +"%Y-%m-%d")

# Создание временных директорий
create_temp_dirs

# Сбор журналов
gather_logs "$user_date" "$current_date"

# Сбор severe логов
gather_severe_logs "$user_date"

# Сбор технической информации
custom_gather

# Генерация пароля для архивации
archive_password=$(openssl rand -base64 12)

# Архивация данных
archive_data "$archive_password"

# Очистка временных файлов
cleanup