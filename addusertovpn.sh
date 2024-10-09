#!/bin/bash

source /etc/wireguard/params

function newClient() {
  ENDPOINT="${SERVER_PUB_IP}:${SERVER_PORT}"
  CLIENT_NAME="$1"

  # Добавляем цикл по подсетям 10.66.0.0, 10.66.1.0, 10.66.2.0
  for SUBNET in {0..2}; do
    for DOT_IP in {2..254}; do
      FULL_IP="10.66.${SUBNET}.${DOT_IP}"
      DOT_EXISTS=$(grep -c "${FULL_IP}" "/etc/wireguard/${SERVER_WG_NIC}.conf")
      if [[ ${DOT_EXISTS} == '0' ]]; then
        break 2  # Выходим из обоих циклов, если найден свободный IP
      fi
    done
  done

  if [[ ${DOT_EXISTS} == '1' ]]; then
    echo ""
    echo "The subnet configured supports only 253 clients."
    exit 1
  fi

  BASE_IPV4="10.66.${SUBNET}"  # Здесь мы уже знаем номер подсети
  until [[ ${IPV4_EXISTS} == '0' ]]; do
    CLIENT_WG_IPV4="${BASE_IPV4}.${DOT_IP}"
    IPV4_EXISTS=$(grep -c "$CLIENT_WG_IPV4/24" "/etc/wireguard/${SERVER_WG_NIC}.conf")

    if [[ ${IPV4_EXISTS} == '1' ]]; then
      echo ""
      echo "A client with the specified IPv4 was already created, please choose another IPv4."
      echo ""
    fi
  done

  BASE_IPv6=$(echo "$SERVER_WG_IPV6" | awk -F '::' '{ print $1 }')
  until [[ ${IPV6_EXISTS} == '0' ]]; do
    CLIENT_WG_IPV6="${BASE_IPv6}::${DOT_IP}"
    IPV6_EXISTS=$(grep -c "${CLIENT_WG_IPV6}/64" "/etc/wireguard/${SERVER_WG_NIC}.conf")

    if [[ ${IPV6_EXISTS} == '1' ]]; then
      echo ""
      echo "A client with the specified IPv6 was already created, please choose another IPv6."
      echo ""
    fi
  done

  # Генерируем ключи для клиента
  CLIENT_PRIV_KEY=$(wg genkey)
  CLIENT_PUB_KEY=$(echo "${CLIENT_PRIV_KEY}" | wg pubkey)
  CLIENT_PRE_SHARED_KEY=$(wg genpsk)

  # Домашняя директория пользователя, куда будет записана конфигурация клиента
  if [ -e "/home/${CLIENT_NAME}" ]; then
    # если $1 - имя пользователя
    HOME_DIR="/home/${CLIENT_NAME}"
  elif [ "${SUDO_USER}" ]; then
    # если нет, используем SUDO_USER
    if [ "${SUDO_USER}" == "root" ]; then
      HOME_DIR="/root"
    else
      HOME_DIR="/home/${SUDO_USER}"
    fi
  else
    # если нет SUDO_USER, используем /root
    HOME_DIR="/root"
  fi

  # Создаем файл клиента и добавляем сервер как peer
  echo "[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128
DNS = ${CLIENT_DNS_1},${CLIENT_DNS_2}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
Endpoint = ${ENDPOINT}
AllowedIPs = ::/0, 1.0.0.0/8, 2.0.0.0/8, 3.0.0.0/8, 4.0.0.0/6, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/6, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, 94.140.14.14/32, 94.140.15.15/32" >>"${HOME_DIR}/${SERVER_WG_NIC}-client-${CLIENT_NAME}.conf"

  # Добавляем клиента как peer на сервере
  echo -e "\n### Client ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
AllowedIPs = ${CLIENT_WG_IPV4}/32,${CLIENT_WG_IPV6}/128" >>"/etc/wireguard/${SERVER_WG_NIC}.conf"

  wg syncconf "${SERVER_WG_NIC}" <(wg-quick strip "${SERVER_WG_NIC}")

  echo "Client ${CLIENT_NAME} добавлен."
}

newClient "$1"