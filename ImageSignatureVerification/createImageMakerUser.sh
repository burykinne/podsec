#!/bin/sh

# Установка пакетов
apt-get update
apt-get -y install nginx docker-registry pinentry-common jq yq

# Поддержка возможности работа в rootless режиме
echo kernel.unprivileged_userns_clone=1 > /etc/sysctl.d/99-podman.conf
sysctl -w kernel.unprivileged_userns_clone=1

# Создание пользователя imagemaker
user='imagemaker'
groupadd -r podman
groupadd -r podman_dev
adduser $user -g podman -G podman_dev,wheel
echo "Введите пароль разработчика образов контейнеров"
passwd $user

cd /home/$user
mkdir -p .config/containers/
echo '{
"default":[{"type":"insecureAcceptAnything"}],
  "transports":{"docker": {
    "registry.local":[
      {
        "type": "signedBy",
        "keyType": "GPGKeys",
        "keyPath": "/var/sigstore/keys/group1.pgp"
}]}}}' |
jq . > .config/containers/policy.json

mkdir -p .config/containers/registries.d
sigStoreURL="http://sigstore.local:81/sigstore/"
refs="{\"lookaside\":\"$sigStoreURL\""
refs+=", \"lookaside-staging\": \"file:///var/sigstore/sigstore/\""
refs+=", \"sigstore-staging\": \"file:///var/sigstore/sigstore/\"}"
echo "{\"default-docker\":$refs}" | yq -y . > .config/containers/registries.d/default.yaml
echo "{\"docker\":{\"registry.local\":$refs}}" | yq -y . > .config/containers/registries.d/sigstore_local.yaml
chown -R imagemaker:podman .

mkdir -p -m 0775 /var/sigstore/keys/
chown root:podman_dev /var/sigstore/keys/
mkdir -m 0775 /var/sigstore/sigstore/
chown root:podman_dev /var/sigstore/sigstore/
echo '<html><body><h1>SigStore works!</h1></body></html>' > /var/sigstore/index.html
su - -c 'gpg2 --full-generate-key'  imagemaker
set -- $(su - -c 'gpg2 --list-keys'  imagemaker)
if [ $# -lt 1 ]
then
  echo "Не найден открытый ключ"
  exit 1
fi
while [ $# -gt 1 ]; do shift; if [ ${1:0:1} == '<' ]; then break; fi  done
uid=$1
su - -c "gpg2 --output /var/sigstore/keys/group1.pgp  --armor --export '$uid'" imagemaker

sysctl -w kernel.unprivileged_userns_clone=1
# Это надо будет заменить на control
chown root:podman /usr/bin/newuidmap /usr/bin/newgidmap
chmod 6750 /usr/bin/newuidmap /usr/bin/newgidmap

# Настройка sigStore
cd /etc/nginx/sites-enabled.d
sed -i  -e 's/server_name .*;/server_name sigstore.local;/' -e 's|root .*|root /var/sigstore;|' -e 's/listen .*;/listen 0.0.0.0:81;/' ../sites-available.d/default.conf
ln -sf ../sites-available.d/default.conf .
systemctl enable --now nginx

# Настройка registry
podman volume create registry
sed -i -e 's|rootdirectory:.*|rootdirectory: /var/lib/containers/storage/volumes/registry/_data/|' -e 's/addr:.*/addr: :80/' /etc/docker-registry/config.yml
if systemctl | grep httpd2 | grep running >/dev/null 2>&1
then
  echo "Сервис httpd2 запущен и конфликтует с docker-registry"
  echo "Сервис httpd2 остановлен"
  systemctl stop httpd2
fi

systemctl enable --now docker-registry
