#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh
set -x

cmd=$(yq '.spec.containers[0].command | join(" ")' /etc/kubernetes/manifests/etcd.yaml)
cmd+=" --enable-v2=true "

$cmd $@
