#!/bin/sh

getExtIP() {
  set -- $(ip r | grep default)
  router=$3
  ifs=$IFS
  IFS=.
  set -- $router
  IFS=$ifs
  prefixIP=$1
  shift
  while [ $# -gt 1 ]; do prefixIP+=".$1"; shift; done
  set -- $(ip a | grep $prefixIP | grep inet)
  IFS=/
  set -- $2
  IFS=$ifs
  extIP=$1
  echo $extIP
}


logger  "=============================================== KUBEADM ====================================="


# set -x
cmd=$1
shift

case $cmd in
  init)
    if [ "$#" -gt 0 ]
    then
      echo -ne "Лишние параметры $*\nФормат вызова: \n$0 init\n";
      exit
    fi
    ;;
  join)
    apiServer=$1
    if [ $# -eq 0 ]
    then
      echo -ne "Отсутствуют параметры\nФормат вызова: \n$0 init|join <параметры>\n";
      exit 1
    fi
  ;;
  *)
    echo -ne "Формат вызова: \n$0 init|join <параметры>\n";
    exit 1;
esac

pars=$*
uid=$(id -u)
echo "$0: uid=$uid"
export XDG_RUNTIME_DIR="/run/user/$uid/"

export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
if ! /sbin/systemctl --no-pager --user status rootlesskit.service >/dev/null 2>&1
then
  /sbin/systemctl --user -T start rootlesskit.service
fi

extIP=$(getExtIP)

until $U7S_BASE_DIR/boot/nsenter.sh /sbin/ip a add 10.96.0.1/12 dev tap0; do sleep 1; done
$U7S_BASE_DIR/boot/nsenter.sh /sbin/ip a del 10.96.0.100/12 dev tap0;

$U7S_BASE_DIR/boot/nsenter.sh /sbin/iptables -A PREROUTING -t nat -p tcp --dport 443 -j DNAT --to 10.96.0.1:6443

if [ $uid -eq 0 ]
then
  $U7S_BASE_DIR/bin/_kubeadm.sh $extIP $cmd $pars

else
  $(dirname $0)/nsenter.sh $U7S_BASE_DIR/bin/_kubeadm.sh $extIP $cmd $pars
fi

