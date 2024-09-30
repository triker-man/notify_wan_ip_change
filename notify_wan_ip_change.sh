#!/bin/bash

# Configuración de variables
GROUP_ID="XXXXXXXXXX"                                                                                         
BOT_TOKEN="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" 
LOG_FILE="/var/log/notify_ip.log"
CURRENT_IP_FILE="/overlay/currentip"
TEMP_DIR="/tmp"
INTERFACE="wan"

# Función para enviar mensaje a Telegram
send_telegram_message() {
    local message="$1"
    wget -qO- --post-data="chat_id=$GROUP_ID&text=$message" \
    "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" > /dev/null
}

while true; do
    # Verificar si el directorio temporal existe, si no, crearlo
    [[ -d $TEMP_DIR ]] || mkdir -p "$TEMP_DIR"

    # Obtener la IP WAN del interfaz wan
    current_ip=$(ip -4 addr show dev "$INTERFACE" | awk '/inet / {print $2}' | cut -d '/' -f 1)

    # Manejo de errores en la obtención de la IP
    if [ -z "$current_ip" ]; then
        echo "$(date +'%F %T') Error: No se pudo obtener la IP actual del interfaz $INTERFACE." >> "$LOG_FILE"
        exit 1
    fi

    # Verificar si el archivo de IP actual existe, si no, crearlo
    if [ ! -f "$CURRENT_IP_FILE" ]; then
        touch "$CURRENT_IP_FILE"
    fi

    # Obtener la IP almacenada en el archivo
    old_ip=$(cat "$CURRENT_IP_FILE")

    # Comparar IPs y notificar si ha cambiado
    if [ "$current_ip" != "$old_ip" ]; then
        # Mensaje de notificacion
        message="$(date +'%F %T')%0ACambio de IP WAN:%0A$old_ip -> $current_ip"

        # Enviar mensaje a Telegram
        send_telegram_message "$message"

        # Actualizar archivo con la nueva IP
        echo "$current_ip" > "$CURRENT_IP_FILE"

        # Registrar en el archivo de log
        echo "$(date +'%F %T') Cambio de IP detectado. Nueva IP: $current_ip" >> "$LOG_FILE"
    else
        # Registrar en el archivo de log
        echo "$(date +'%F %T') No hay cambio en la IP. IP actual: $current_ip" >> "$LOG_FILE"
    fi

    # Esperar 60 segundos antes de la próxima comprobación
    sleep 60
done
