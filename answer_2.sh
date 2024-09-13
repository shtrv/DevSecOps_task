#!/bin/bash

# Функция для сбора технической информации о системе
custom_gather() {
  local output_file=$1

  echo "Собираю информацию о системе..."

  # Системная информация
  echo "Системная информация:" > "$output_file"
  uname -a >> "$output_file"
  echo "" >> "$output_file"

  # Информация о ЦПУ
  echo "Информация о ЦПУ:" >> "$output_file"
  lscpu >> "$output_file"
  echo "" >> "$output_file"

  # Информация о памяти
  echo "Информация о памяти:" >> "$output_file"
  free -h >> "$output_file"
  echo "" >> "$output_file"

  # Информация о файловой системе
  echo "Информация о файловой системе:" >> "$output_file"
  df -h >> "$output_file"
  echo "" >> "$output_file"

  # Список работающих процессов
  echo "Список процессов:" >> "$output_file"
  ps aux --sort=-%mem | head -n 20 >> "$output_file"
  echo "" >> "$output_file"

  # Информация о сети
  echo "Сетевые интерфейсы:" >> "$output_file"
  ip addr show >> "$output_file"
  echo "" >> "$output_file"

  echo "Техническая информация собрана в $output_file"
}

# Проверка формата даты
validate_date() {
    if ! date -d "$1" "+%Y-%m-%d" &>/dev/null; then
        echo "Ошибка: неверный формат даты. Используйте формат YYYY-MM-DD."
        exit 1
    fi
}

# Пользовательский ввод даты
echo "Введите дату в формате YYYY-MM-DD:"
read user_date
validate_date "$user_date"

# Получаем текущую дату
current_date=$(date +"%Y-%m-%d")

# Создаём директории для вывода
mkdir -p /tmp/extraction/common
mkdir -p /tmp/extraction/severe

# Сбор всех журналов с указанной даты
echo "Собираем журналы с $user_date до $current_date..."

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
