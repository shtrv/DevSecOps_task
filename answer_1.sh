#!/usr/bin/env bash  

service_name="nginx"
tmp_service_dir="/tmp/${service_name}_tmp"  # необходимо заменить на актуальный путь

if systemctl is-active --quiet ${service_name}; then
    echo "${service_name} is running."
else
    echo "${service_name} is not running. Thus, we don't need temporary directory anymore. Let's delete it."
    rm -rf ${tmp_service_dir}
fi

exit 0