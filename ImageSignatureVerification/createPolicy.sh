#!/bin/sh
# Скрипт создает

if [ $# -lt 1 ]
then
  echo -ne "Не указан IP-адрес регистратора и сервера подписей\n"
  echo -ne "Формат:\n\t$0 <ip-адрес_регистратора_и_сервера_подписей>\n"
  exit 1
fi
regIP=$1

case $regIP in
  '127.0.0.1')
    echo "IP-адрес регистратора и сервера подписей не должен быть локальным: $regIP"
    exit 1;;
esac

ifs=$IFS IFS=.
set -- $regIP
IFS=$ifs
if [ $# -ne 4 ]
then
  echo "Некорректный IP-адрес: $regIP"
  exit 2
fi

for ip
do
  if [[ "$a" =~ $re && "$a" -ge 0 && "$a" -lt 256 ]]
  then :;
  else
  echo "Некорректный IP-адрес: $regIP"
    exit 3
  fi
done


# Установка пакетов
apt-get update
apt-get install -y podman shadow-submap nginx docker-registry pinentry-common jq yq fuse-overlayfs

# Создание групп
groupadd -r podman
groupadd -r podman_dev

# Поддержка возможности работа в rootless режиме
echo kernel.unprivileged_userns_clone=1 > /etc/sysctl.d/99-podman.conf
sysctl -w kernel.unprivileged_userns_clone=1

localIP=
if ip a  | grep $regIP >/dev/null 2>&1
then
  localIP='yes'
fi

if grep $regIP /etc/hosts >/dev/null 2>&1
then :;
else
  echo "$regIP registry.local sigstore.local" >> /etc/hosts
fi

cd /etc/containers

suffix=$(date '+%Y-%m-%d_%H:%M:%S')

policyFile='policy.json'
yesterday=$(date '+%Y-%m-%d_%H:%M:%S' -d "yesterday")
now=$(date '+%Y-%m-%d_%H:%M:%S')

if [ ! -L $policyFile ]
then :;
  mv $policyFile ${policyFile}_${yesterday}
fi
linkedPolicyFile="policy_${now}"
echo '{
"default":[{"type":"reject"}],
  "transports":{"docker": {
    "registry.local":[
      {
        "type": "signedBy",
        "keyType": "GPGKeys",
        "keyPath": "/var/sigstore/keys/group1.pgp"
}]}}}' |
jq . > $linkedPolicyFile
ln -sf $linkedPolicyFile $policyFile

registriesConf="registries.conf"
if [ ! -L $registriesConf ]
then :;
  cp $registriesConf ${registriesConf}.${yesterday}
fi
linkedRegistriesConf="registries_${now}"
if grep '^location.*=.*registry.local' $registriesConf > /dev/nul 2>&1
then :;
else
  cp $registriesConf $linkedRegistriesConf
  echo -ne "\n[[registry]]\nlocation = \"registry.local\"\ninsecure = true\n" >> $linkedRegistriesConf
  ln -sf $linkedRegistriesConf  $registriesConf
fi

cd registries.d
defaultYaml='default.yaml'
if [ ! -L $defaultYaml ]
then :;
  mv $defaultYaml ${defaultYaml}.${yesterday}
fi
linkedDefaultYaml="default_${now}"
sigStoreURL="http://sigstore.local:81/sigstore/"
refs="\"lookaside\":\"$sigStoreURL\", \"sigstore\":\"$sigStoreURL\""
if [ -n "$localIP" ]
then
  refs+=",\"lookaside-staging\": \"file:///var/sigstore/sigstore/\""
fi
refs="{$refs}"
echo "{\"default-docker\":$refs}" | yq -y . > $linkedDefaultYaml
ln -sf $linkedDefaultYaml $defaultYaml

sigStoreYaml="sigstore_local.yaml"
linkedSigStoreYaml="sigstore_local_${now}"
echo "{\"docker\":{\"registry.local\": $refs }}" | yq -y . > $linkedSigStoreYaml
ln -sf $linkedSigStoreYaml $sigStoreYaml


