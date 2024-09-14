#!/bin/bash

# Временные директории
EXTRACTION_DIR="/tmp/extraction"
COMMON_DIR="$EXTRACTION_DIR/common"
SEVERE_DIR="$EXTRACTION_DIR/severe"

# Функция для сбора технической информации о системе
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

# Проверка формата даты
validate_date() {
    if ! parsed_date=$(date -d "$1" "+%Y-%m-%d" 2>/dev/null); then
        echo "Ошибка: неверный формат даты. Используйте формат YYYY-MM-DD."
        exit 1
    fi
    
    if [[ "$1" != "$parsed_date" ]]; then
        echo "Ошибка: неверная дата."
        exit 1
    fi
}

# Пользовательский ввод даты
read -p "Введите дату в формате YYYY-MM-DD: " user_date
validate_date "$user_date"

# Получаем текущую дату
current_date=$(date +"%Y-%m-%d")

# Создание временных директорий
mkdir -p "$COMMON_DIR"
mkdir -p "$SEVERE_DIR"

# Сбор всех журналов с указанной даты
echo "Сбор журналов с $user_date до $current_date..."




for service_dir in /opt/app-x/service-*; do
  service_name=$(basename "$service_dir")
  
  # Копируем файлы журналов по датам
  find "$service_dir" -type f -name "*$user_date*" -or -newermt "$user_date" ! -newermt "$current_date" -exec cp {} /tmp/extraction/common/ \;
done

# Обработка файлов с уровнем SEVERE за один день
echo "Собираем данные уровня SEVERE за $user_date..."

for service_dir in /opt/app-x/service-*; do
  service_name=$(basename "$service_dir")
  persistent_log="$service_dir/persistent-debug.log"

  if [ -f "$persistent_log" ]; then
    grep "^$user_date.*\[LOG_LEVEL: SEVERE\]" "$persistent_log" > "/tmp/extraction/severe/${service_name}_severe_$user_date.log"
    
    # (*) Заменяем $FOO на ${FOO} в severe логах
    sed -i 's/\$\([A-Za-z_][A-Za-z0-9_]*\)/${\1}/g' "/tmp/extraction/severe/${service_name}_severe_$user_date.log"
  fi
done

# Сбор технических данных
echo "Собираем техническую информацию о хосте..."
custom_gather "/tmp/extraction/common/system_info.txt"

# Генерация пароля для архивации
archive_password=$(openssl rand -base64 12)

# Архивация данных с шифрованием
echo "Создаём зашифрованный архив..."

tar -czf - /tmp/extraction | openssl enc -aes-256-cbc -e -k "$archive_password" -out /tmp/extraction_$(date +"%Y%m%d_%H%M%S").tar.gz

# Выводим пароль для расшифровки архива
echo "Архив создан. Пароль для расшифровки: $archive_password"

# Очистка временных файлов (необязательно)
rm -rf /tmp/extraction
