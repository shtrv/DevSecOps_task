Bash: описать логику скрипта, исправить ошибки

```
!/usr/bin/env bash  

service_name=nginx

if systemctl is-active --quiet ${service}_name;  
    echo '$service_name is running.'
else
    echo "${service_name} is not running. Thus, we don't need temporary directory anymore. Let's delete it."
    rm -rf /${tmp_service_dir}
end

exit 1
```

