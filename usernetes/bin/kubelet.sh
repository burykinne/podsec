#!/bin/bash
export U7S_BASE_DIR=$(realpath $(dirname $0)/..)
source $U7S_BASE_DIR/common/common.inc.sh

set -x
TMPFILE=$(mktemp "/tmp/kubeconf.XXXXXX")
kubelet_config="/var/lib/kubelet/config.yaml"
if yq -y ".+{volumePluginDir: \"$XDG_DATA_HOME/usernetes/kubelet-plugins-exec\"}"  $kubelet_config >$TMPFILE
then
  mv $TMPFILE $kubelet_config
fi

kubelet \
	--cert-dir $XDG_CONFIG_HOME/usernetes/pki \
	--root-dir $XDG_DATA_HOME/usernetes/kubelet \
	--kubeconfig "/etc/kubernetes/kubelet.conf" \
	--config $kubelet_config \
	$@