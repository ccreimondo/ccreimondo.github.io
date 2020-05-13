#!/bin/bash

set -x

# Test on Ubuntu server only
OS_RELEASE_NAME=$(source /etc/os-release && echo $NAME)
[[ ! "${OS_RELEASE_NAME}" == "Ubuntu" ]] && exit 1

KERNEL_VERSION=$(make --no-print-directory -C /usr/src/linux-headers-$(uname -r)/ kernelversion)

# e.g. https://mirrors.ustc.edu.cn/kernel.org/linux/kernel/v4.x/linux-4.4.13.tar.gz
KERNEL_ORG_DIR_IDX=$(echo ${KERNEL_VERSION} | awk -F'.' '{ print $1 }')
wget https://mirrors.ustc.edu.cn/kernel.org/linux/kernel/v${KERNEL_ORG_DIR_IDX}.x/linux-${KERNEL_VERSION}.tar.gz
