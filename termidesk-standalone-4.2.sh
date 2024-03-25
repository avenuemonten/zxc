#!/bin/bash

# Остановить выполнение сценария при появлении первой ошибки.
#set -e

# Debug mode
#set -x

error_code(){    
    if [ "$err" != "0" ]; then
        echo "Установка не выполнена. Error code $err" 
        exit 1
    fi
}

start_message() {
    cat <<-'EOF'
==================================================================================
==============================   ВНИМАНИЕ!!!   ===================================
==================================================================================

==================================================================================
=====   ИСПОЛЬЗОВАНИЕ СКРИПТА TERMIDESK-STANDALONE-4.2.SH                 ========
=====   ДОПУСКАЕТСЯ ТОЛЬКО В ЦЕЛЯХ ОЗНАКОМЛЕНИЯ С ПРОДУКТОМ TERMIDESK.    ========
=====   ДАННЫЙ СКРИПТ НЕ РЕКОМЕНДУЕТСЯ ИСПОЛЬЗОВАТЬ В ПРОДУКТИВНОЙ СРЕДЕ. ========
==================================================================================

==================================================================================
==========================   Установка Termidesk 4.2   ===========================
==================================================================================

	EOF
}

update_system() {
    sudo bash -c 'cat <<- "EOF" > /etc/apt/sources.list
	#deb cdrom:[OS Astra Linux 1.7.4 1.7_x86-64 DVD ]/ 1.7_x86-64 contrib main non-free
	deb https://download.astralinux.ru/astra/stable/1.7_x86-64/repository-main/ 1.7_x86-64 main contrib non-free
	deb https://download.astralinux.ru/astra/stable/1.7_x86-64/repository-update/ 1.7_x86-64 main contrib non-free
	deb https://download.astralinux.ru/astra/stable/1.7_x86-64/repository-base/ 1.7_x86-64 main contrib non-free
	deb https://download.astralinux.ru/astra/stable/1.7_x86-64/repository-extended/ 1.7_x86-64 main contrib non-free
	EOF'
    printf "Репозитории добавлены. \n"

    printf "Обновляем список доступных пакетов используя команду apt update... \n"
    sudo apt update -qq
}

termidesk_digsig_keys () {

    # ищем пакет termidesk-digsig-keys.deb в системе,
    # если пакетов несколько и они лежат в разных местах, получим ответ > 0
    # при установке будет выбран первый найденный пакет

    _search=$(sudo find /home /tmp /mnt /media /var -name "termidesk-digsig*.deb" | wc -l)
    _app=$(sudo find /home /tmp /mnt /media /var -name "termidesk-digsig*.deb" | head -n 1)

    if [ "$_search" != "0" ]; then
        printf "Запущен процесс установки termidesk-digsig-keys(local) \n"
        sudo apt install -y "$_app" &>/dev/null
        err=$?
        if [ "$err" != "0" ] ; then
            error_code
        else
            printf "Установка termidesk-digsig-keys выполнена. \n"
        fi
    else
        printf "Пакет termidesk-digsig-keys не найден в системе. \n"
        exit 1
    fi
}

termidesk_vdi_remove() {

    printf "Запущен процесс удаления Termidesk \n"
    sudo apt remove -y termidesk-vdi &>/dev/null
    err=$?
    if [ "$err" != "0" ] ; then
        error_code
    else
        sudo aptitude -y purge ~c &>/dev/null
        printf "Termidesk удалён. \n"
    fi
}

termidesk_vdi_install() {
    _rabbitmq=$(sudo dpkg -l | grep -c rabbitmq-server)
    _postgres=$(sudo dpkg -l | grep -c "[[:space:]]postgresql[[:space:]]")
    _search=$(sudo find /home /tmp /mnt /media /var -name "termidesk-vdi_4.2*.deb" | wc -l)
    _app=$(sudo find /home /tmp /mnt /media /var -name "termidesk-vdi_4.2*.deb" | head -n 1)

    if [ "$_search" = "0" ]; then
        printf "Пакет termidesk-vdi_4.2 в системе не найден \n"
        exit 1
    elif [ "$_rabbitmq" = "0" ] || [ "$_postgres" = "0" ]; then
        printf "Для работы Termidesk необходимо установить пакеты RabbitMQ и Postgresql.\nДанные пакеты не установлены в системе. \n"
        exit 1
    else
        printf "Запущен процесс установки Termidesk \n"
        termidesk_pre_task
        printf "Начата установка программы \n"
        sudo apt install -y "$_app" &>/dev/null
        err=$?
            if [ "$err" != "0" ] ; then
                error_code
            else
                printf "Процесс установки программы Termidesk завершён. \n"
            fi
    fi
}

zps() {
    _keys=$(sudo dpkg -l | grep -c termidesk-digsig-keys)
    _zps=$(sudo astra-digsig-control status)

    ### Проверяем включён ли режим ЗПС
    ### Проверяем наличие пакета termidesk-digsig-keys в системе

    printf "Проверка режима замкнутой программной среды. \n"
    printf "Статус режима замкнутой программной среды - %s. \n" "$_zps"
    if [ "$_keys" = "0" ] && [ "$_zps" = "АКТИВНО" ]; then
        printf "Пакет termidesk-digsig-keys не установлен в системе. \n"
        read -rp "Выполнить установку пакета termidesk-digsig-keys?(y/n): " answer
        if [ "$answer" = "y" ]; then
            termidesk_digsig_keys
            printf "Ключи установлены. Требуется перезагрузка системы. \n"
            exit 0
        elif [ "$answer" != "y" ]; then
            printf "Дальнейшая установка Termidesk в режиме ЗПС без установки пакета termidesk-digsig-keys невозможна. \n"
            exit 1
        fi
    elif [ "$_keys" = "1" ] && [ "$_zps" = "АКТИВНО" ]; then
        printf "Пакет termidesk-digsig-keys установлен в системе. \n"
    fi
    printf "Проверка закончена. \n"
}


termidesk() {

  _termidesk=$(dpkg -l | grep -c termidesk-vdi)
  
  if [ "$_termidesk" = "0" ]; then
    printf "Программа Termidesk не установлена в системе. \n"
    read -rp "Установить программу Termidesk 'Всё в одном'?(y/n): " answer
    if [ "$answer" = "y" ]; then
        all_in_one
    elif [ "$answer" = "n" ]; then
        read -rp "Установить только программу Termidesk?(y/n): " answer
        if [ "$answer" = "y" ]; then
            termidesk_vdi_install
       elif [ "$answer" = "n" ]; then
            printf "Выход из режима установки. \n"
       else
            printf "Получен неверный ответ. режим работы прекращён. \n"
            exit 0
        fi                
    else
        printf "Получен неверный ответ. режим работы прекращён. \n"
        exit 0
    fi

  elif [ "$_termidesk" = "1" ]; then
      printf "Программа Termidesk установлена в системе. \n"
      read -rp "Выполнить обновление программы Termidesk?(y/n): " answer

      if [ "$answer" = "y" ]; then
          termidesk_vdi_install
      elif [ "$answer" = "n" ]; then
        read -rp "Выполнить удаление программы Termidesk?(y/n): " answer
        if [ "$answer" = "y" ]; then
            termidesk_vdi_remove
        elif [ "$answer" = "n" ]; then
            printf "Выход из режима удаления. \n"
            exit 0
        else
            printf "Получен неверный ответ. Режим работы прекращён. \n"
            exit 1
        fi
      else
          printf "Получен неверный ответ. Режим работы прекращён. \n"
          exit 1
      fi
    fi
}

database_install() {

    _postgres=$(sudo dpkg -l | grep -c "[[:space:]]postgresql[[:space:]]")
    
    if [ "$_postgres" = "0" ]; then
        printf "Устанавливаем СУБД PostgreSQL... \n"
        sudo apt install postgresql -y &>/dev/null
        err=$?
        if [ "$err" != "0" ] ; then
            error_code
        else
            printf "СУБД PostgreSQL успешно установлена. \n"
        fi
    else
        printf "СУБД PostgreSQL уже установлена. \n"
    fi

    database_settings
}

database_settings() {
    # меняем рабочую директорию, во избежания следующей ошибки:
    # could not change directory to "/home/user/Desktops/Desktop1": Отказано в доступе
    # так как у пользователя postgres нет прав на директорию пользователя user под которым выполняется скрипт
    cd /tmp || exit


    _user=$(sudo -u postgres psql postgres -tXAc "SELECT 1 FROM pg_roles WHERE rolname='termidesk'")
    _database=$(sudo -u postgres psql postgres -tXAc "SELECT 1 FROM pg_database WHERE datname='termidesk'")
    
    if [ "$_user" = "1" ] && [ "$_database" = "1" ]; then
        printf "Пользователь и база данных уже существуют. \n"

    else
        printf "Создаем БД: termidesk... \n"
        sudo -u postgres psql -c "CREATE DATABASE termidesk LC_COLLATE 'ru_RU.utf8' LC_CTYPE 'ru_RU.utf8' TEMPLATE template0;" &>/dev/null
        printf "База данных: termidesk успешно создана. \n"

        printf "Coздаем пользователя: termidesk... \n"
        sudo -u postgres psql -c "CREATE USER termidesk WITH PASSWORD 'ksedimret';" &>/dev/null
        printf "Пользователь termidesk создан. \n"

        printf "Выдаем права пользователю termidesk на базу данных termidesk... \n"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE termidesk TO termidesk;" &>/dev/null
        printf "Права пользователю termidesk на БД termidesk выданы. \n"

        printf "Выключаем определение отсутствия мандатных атрибутов пользователя в базах данных... \n"
        sudo sed -i "s/zero_if_notfound: no/zero_if_notfound: yes/" /etc/parsec/mswitch.conf
        sudo systemctl restart postgresql.service
        printf "Сервис postgres перезагружен. \n"

    fi
    
}

rabbitmq_settings() {

    printf "Настройка RabbitMQ-server... \n"
    sudo mkdir -p /etc/rabbitmq

    sudo touch /etc/rabbitmq/rabbitmq.conf
    sudo touch /etc/rabbitmq/definitions.json

    sudo chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq.conf
    sudo chown rabbitmq:rabbitmq /etc/rabbitmq/definitions.json

    sudo chmod 0646 /etc/rabbitmq/rabbitmq.conf
    sudo chmod 0646 /etc/rabbitmq/definitions.json

	sudo bash -c 'cat <<- "EOF" > /etc/rabbitmq/rabbitmq.conf
	management.load_definitions = /etc/rabbitmq/definitions.json
	EOF'

    sudo bash -c 'cat <<- "EOF" > /etc/rabbitmq/definitions.json
    {
        "rabbit_version": "3.7.8",
        "users": [
            {
                "name": "termidesk",
                "password_hash": "pnXiDJtUdk7ZceL9iOqx44PeDgRa+X1+eIq+7wf/PTONLb1h",
                "hashing_algorithm": "rabbit_password_hashing_sha256",
                "tags": ""
            },
            {
                "name": "admin",
                "password_hash": "FXQ9WFNSrsGwRki9BT2dCITnsDwYu2lsy7BEN7+UncsPzCDZ",
                "hashing_algorithm": "rabbit_password_hashing_sha256",
                "tags": "administrator"
            }
        ],
        "vhosts": [
            {
                "name": "/"
            },
            {
                "name": "termidesk"
            }
        ],
        "permissions": [
            {
                "user": "termidesk",
                "vhost": "termidesk",
                "configure": ".*",
                "write": ".*",
                "read": ".*"
            },
            {
                "user": "admin",
                "vhost": "termidesk",
                "configure": ".*",
                "write": ".*",
                "read": ".*"
            }
        ],
        "topic_permissions": [
            {
                "user": "termidesk",
                "vhost": "termidesk",
                "exchange": "",
                "write": ".*",
                "read": ".*"
            }
        ],
        "parameters": [],
        "global_parameters": [
            {
                "name": "cluster_name",
                "value": "rabbit@rabbitmq"
            }
        ],
        "policies": [],
        "queues": [],
        "exchanges": [],
        "bindings": []
    }
	EOF'

    sudo chmod 0644 /etc/rabbitmq/rabbitmq.conf
    sudo chmod 0644 /etc/rabbitmq/definitions.json

    sudo rabbitmq-plugins enable rabbitmq_management
    sudo systemctl restart rabbitmq-server
    printf "Настройка RabbitMQ-server выполнена успешно. \n"
}

rabbitmq_install() {
    _rabbitmq=$(dpkg -l | grep -c rabbitmq-server)
    
    if [ "$_rabbitmq" = "1" ]; then
        printf "Программа RabbitMQ уже установлена. \n"
    else
        printf "Установка RabbitMQ-server... \n"
        sudo apt install -y rabbitmq-server &>/dev/null
        err=$?
        if [ "$err" != "0" ] ; then
            error_code
        else
            printf "Установка RabbitMQ-server выполнена успешно. \n"
        fi
    fi

    rabbitmq_settings

}


termidesk_pre_task() {
    
    printf "Создаем файл ответов для тихой установки Termidesk... \n"
    cat <<- 'EOF' > answer
    #
    termidesk-vdi        termidesk-vdi/yes     boolean false
    # Пользовательская лицензияx
    termidesk-vdi       termidesk-vdi/text-eula note
    # Вы принимаете условия пользовательской лицензии?
    termidesk-vdi       termidesk-vdi/yesno-eula        boolean true
    # true -  интерактивный режим. false - пакетный (тихий) режим:
    termidesk-vdi       termidesk-vdi/interactive       boolean false
    # ПАРАМЕТРЫ ПОДКЛЮЧЕНИЯ К СУБД
    # Адрес сервера СУБД Termidesk:
    termidesk-vdi       termidesk-vdi/dbhost    string 127.0.0.1
    # Имя базы данных Termidesk:
    termidesk-vdi       termidesk-vdi/dbname    string termidesk
    # Пользователь базы данных Termidesk:
    termidesk-vdi       termidesk-vdi/dbuser    string termidesk
    # Пароль базы данных Termidesk:
    termidesk-vdi       termidesk-vdi/dbpass    string ksedimret
    # ПАРАМЕТРЫ ПОДКЛЮЧЕНИЯ К СЕРВЕРАМ RABBITMQ
    # RabbitMQ URL #1
    termidesk-vdi   termidesk-vdi/rabbitmq_url1     password amqp://termidesk:ksedimret@127.0.0.1:5672/termidesk
    # RabbitMQ URL #3
    termidesk-vdi   termidesk-vdi/rabbitmq_url3     password
    # RabbitMQ URL #2
    termidesk-vdi   termidesk-vdi/rabbitmq_url2     password
    # Choices: 1 amqp://termidesk:ksedimret@127.0.0.1:5672/termidesk, 2 Empty, 3 Empty, Save
    termidesk-vdi   termidesk-vdi/rabbitmq_select   select Save
    # Choose Termidesk roles to start:
    termidesk-vdi   termidesk-vdi/roles     multiselect     Broker, Gateway, Task manager
    # Choose port termidesk database
    termidesk-vdi termidesk-vdi/dbport string 5432
	EOF

    printf "Считываем файл ответов... \n"
    sudo debconf-set-selections answer &>/dev/null

}

termidesk_post_tasks() {
    printf "Устанавливаем уровень логирования в DEBUG... \n"
    sudo sed -i 's/LOG_LEVEL="INFO"/LOG_LEVEL="DEBUG"/' /etc/opt/termidesk-vdi/termidesk.conf

    printf "Вносим изменения в apache2.conf... \n"
    sudo sed -i "s@.*AstraMode.*on.*@AstraMode off@g" /etc/apache2/apache2.conf
    sudo systemctl restart apache2 
}

termidesk_service() {

    _service=( "termidesk-vdi.service" "termidesk-taskman.service" "termidesk-wsproxy.service" "termidesk-celery-beat.service" "termidesk-celery-worker.service" )

    for s in "${_service[@]}"
    do
        systemctl status "$s" | grep -e '.service -' -e 'Active:'
    done
    printf "Службы Termidesk запущены. \n"
}


all_in_one() {
    update_system
    database_install
    rabbitmq_install
    termidesk_vdi_install
    termidesk_post_tasks
    termidesk_service
    finaly_message
}

finaly_message() {
	cat <<-'EOF'
==================================================================================
==========    Установка  Termidesk стандартной редакции завершена       ==========
==========    Для доступа требуется перейти в web браузере по адресу:   ==========
==========    https://<FQDN сервера termidesk> && https://<ipaddress>   ==========
==================================================================================
	EOF
}

start_message
zps
termidesk
