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


# Сбор всех журналов с указанной даты
echo "Сбор журналов с $user_date до $current_date..."

for service_dir in /opt/app-x/service-*; do
  service_name=$(basename "$service_dir")
  
  # Копируем файлы журналов по датам
  find "$service_dir" -type f -name "*$user_date*" -or -newermt "$user_date" ! -newermt "$current_date" -exec cp {} /tmp/extraction/common/ \;
  find /opt/app-x/ -type f -name "*.log" -newermt "$user_date" ! -newermt "$current_date + 1 day" -exec cp --parents {} /tmp/extraction/common/ \;
done




# Обработка файлов с уровнем SEVERE за один день
echo "Собираем данные уровня SEVERE за $user_date..."

for service_dir in /opt/app-x/service-*; do
  service_name=$(basename "$service_dir")
  persistent_log="$service_dir/persistent-debug.log"

  if [ -f "$persistent_log" ]; then
    grep "^$user_date.*\[LOG_LEVEL: SEVERE\]" "$persistent_log" > "/tmp/extraction/severe/${service_name}_severe_$user_date.log"
    
    # (*) Замена $FOO на ${FOO} в severe логах
    sed -i 's/\$\([A-Za-z_][A-Za-z0-9_]*\)/${\1}/g' "/tmp/extraction/severe/${service_name}_severe_$user_date.log"
  fi
done




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