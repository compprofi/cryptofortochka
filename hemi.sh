#!/bin/bash

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Нет цвета (сброс цвета)

# Отображаем логотип
curl -s https://raw.githubusercontent.com/noxuspace/cryptofortochka/main/logo_forto.sh | bash

# Проверка наличия curl и установка, если не установлен
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

# Меню
echo -e "${YELLOW}Выберите действие:${NC}"
echo -e "${CYAN}1) Установка ноды${NC}"
echo -e "${CYAN}2) Обновление ноды${NC}"
echo -e "${CYAN}3) Изменение комиссии${NC}"
echo -e "${CYAN}4) Удаление ноды${NC}"
echo -e "${CYAN}5) Полезные команды${NC}"

echo -e "${YELLOW}Введите номер:${NC} "
read choice

case $choice in
    1)
        echo -e "${BLUE}Устанавливаем ноду Hemi...${NC}"

        # Обновляем и устанавливаем необходимые пакеты
        sudo apt update && sudo apt upgrade -y

        # Проверка и установка tar, если его нет
        if ! command -v tar &> /dev/null; then
            echo -e "${BLUE}tar не установлен, выполняем установку...${NC}"
            sudo apt install tar -y
        else
            echo -e "${BLUE}tar уже установлен.${NC}"
        fi

        # Установка бинарника
        echo -e "${BLUE}Загружаем бинарник Hemi...${NC}"
        curl -L -O https://github.com/hemilabs/heminetwork/releases/download/v0.4.5/heminetwork_v0.4.5_linux_amd64.tar.gz

        # Создание директории и извлечение бинарника
        mkdir -p hemi
        tar --strip-components=1 -xzvf heminetwork_v0.4.5_linux_amd64.tar.gz -C hemi
        cd hemi

        # Создание tBTC кошелька
        ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json

        # Вывод содержимого файла popm-address.json
        echo -e "${RED}Сохраните эти данные в надежное место:${NC}"
        cat ~/popm-address.json
        echo -e "${PURPLE}Ваш pubkey_hash — это ваш tBTC адрес, на который нужно запросить тестовые токены в Discord проекта.${NC}"

        echo -e "${YELLOW}Введите ваш приватный ключ от кошелька:${NC} "
        read PRIV_KEY
        echo -e "${YELLOW}Укажите желаемый размер комиссии (минимум 50):${NC} "
        read FEE

        echo "POPM_BTC_PRIVKEY=$PRIV_KEY" > popmd.env
        echo "POPM_STATIC_FEE=$FEE" >> popmd.env
        echo "POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> popmd.env

        # Создание сервисного файла hemi.service
        sudo bash -c 'cat <<EOT > /etc/systemd/system/hemi.service
[Unit]
Description=PopMD Service
After=network.target

[Service]
EnvironmentFile=/root/hemi/popmd.env
ExecStart=/root/hemi/popmd
WorkingDirectory=/root/hemi/
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOT'

        # Обновление сервисов и включение hemi
        sudo systemctl daemon-reload
        sudo systemctl enable hemi

        # Запуск ноды
        sudo systemctl start hemi

        echo -e "${GREEN}Установка завершена и нода запущена!${NC}"
        ;;

    2)
        echo -e "${BLUE}Обновляем ноду Hemi...${NC}"

        # Находим все сессии screen, содержащие "hemi"
        SESSION_IDS=$(screen -ls | grep "hemi" | awk '{print $1}' | cut -d '.' -f 1)

        # Если сессии найдены, удаляем их
        if [ -n "$SESSION_IDS" ]; then
            echo -e "${BLUE}Завершение сессий screen с идентификаторами: $SESSION_IDS${NC}"
            for SESSION_ID in $SESSION_IDS; do
                screen -S "$SESSION_ID" -X quit
            done
        else
            echo -e "${BLUE}Сессии screen для ноды Hemi не найдены.${NC}"
        fi

        # Проверка существования сервиса
        if systemctl list-units --type=service | grep -q "hemi.service"; then
            sudo systemctl stop hemi.service
            sudo systemctl disable hemi.service
            sudo systemctl daemon-reload
        else
            echo -e "${BLUE}Сервис hemi.service не найден, начинаем обновление.${NC}"
        fi

        # Удаление папки с бинарниками, содержащей "hemi" в названии
        echo -e "${BLUE}Удаляем старые файлы ноды...${NC}"
        rm -rf *hemi*

        # Обновляем и устанавливаем необходимые пакеты
        sudo apt update && sudo apt upgrade -y

        # Установка бинарника
        echo -e "${BLUE}Загружаем бинарник Hemi...${NC}"
        curl -L -O https://github.com/hemilabs/heminetwork/releases/download/v0.4.5/heminetwork_v0.4.5_linux_amd64.tar.gz

        # Создание директории и извлечение бинарника
        mkdir -p hemi
        tar --strip-components=1 -xzvf heminetwork_v0.4.5_linux_amd64.tar.gz -C hemi

        # Запрос приватного ключа и комиссии
        echo -e "${YELLOW}Введите ваш приватный ключ от кошелька:${NC} "
        read PRIV_KEY
        echo -e "${YELLOW}Укажите желаемый размер комиссии (минимум 50):${NC} "
        read FEE

        # Создание файла popmd.env
        echo "POPM_BTC_PRIVKEY=$PRIV_KEY" > popmd.env
        echo "POPM_STATIC_FEE=$FEE" >> popmd.env
        echo "POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> popmd.env

        # Создание сервисного файла hemi.service
        sudo bash -c 'cat <<EOT > /etc/systemd/system/hemi.service
[Unit]
Description=PopMD Service
After=network.target

[Service]
EnvironmentFile=/root/hemi/popmd.env
ExecStart=/root/hemi/popmd
WorkingDirectory=/root/hemi/
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOT'

        # Обновление сервисов и включение hemi
        sudo systemctl daemon-reload
        sudo systemctl enable hemi

        # Запуск ноды
        sudo systemctl start hemi

        echo -e "${GREEN}Нода обновлена и запущена!${NC}"
        ;;
    
    *)
        echo -e "${RED}Неверный выбор, попробуйте снова.${NC}"
        ;;
esac
