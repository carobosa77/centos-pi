#!/bin/bash

# Download the image from http://isoredirect.centos.org/altarch/8/isos/armhfp/CentOS-Userland-8-armv7hl-generic-Minimal-1911-sda.raw.xz, or search for an updated image at http://isoredirect.centos.org/altarch/8/isos/armhfp/

# Defines the TARGET device, the IMAGE file and the TEMPorary (working) directory
TARGET=/dev/mmcblk0
IMAGE=CentOS-Userland-8-armv7hl-generic-Minimal-1911-sda.raw.xz
TEMP=$( mktemp -d )
#FORCE=true

TARGET_PARTITIONS_PREFIX=${TARGET}
if [[ ${TARGET: -1} =~ ^[0-9]$ ]]; then
  TARGET_PARTITIONS_PREFIX=${TARGET}p
fi

# Shows partition information, in the format that sfdisk understands
do_sfdisk() {
  cat << EOD > /dev/null
${TARGET_PARTITIONS_PREFIX}1 : start=        2048, size=      155648, type=c
${TARGET_PARTITIONS_PREFIX}2 : start=      157696, size=     1368064, type=83, bootable
${TARGET_PARTITIONS_PREFIX}3 : start=     1525760, size=      999424, type=82
${TARGET_PARTITIONS_PREFIX}4 : start=     2525184, size=     3905536, type=83
EOD
  cat << EOD
${TARGET_PARTITIONS_PREFIX}1 : start=        2048, size=      262144, type=c
${TARGET_PARTITIONS_PREFIX}2 : start=      264192, size=     1835008, type=83, bootable
${TARGET_PARTITIONS_PREFIX}3 : start=     2099200, size=     4194304, type=83
${TARGET_PARTITIONS_PREFIX}4 : start=     6293504, size=    56040448, type=5
${TARGET_PARTITIONS_PREFIX}5 : start=     6295552, size=     1048576, type=82
${TARGET_PARTITIONS_PREFIX}6 : start=     7346176, size=     2097152, type=83
${TARGET_PARTITIONS_PREFIX}7 : start=     9445376, size=     4194304, type=83
${TARGET_PARTITIONS_PREFIX}8 : start=    13641728, size=     2097152, type=83
${TARGET_PARTITIONS_PREFIX}9 : start=    15740928, size=     4194304, type=83
${TARGET_PARTITIONS_PREFIX}10 : start=    19937280, size=     1048576, type=83
${TARGET_PARTITIONS_PREFIX}11 : start=    20987904, size=     1048576, type=83
EOD
}

# Shows the mount points information, in the format of the fstab file
do_fstab() {
  cat << EOD | tr -s ' ' > /dev/null
${TARGET_PARTITIONS_PREFIX}4  / ext4    defaults,noatime 0 0
${TARGET_PARTITIONS_PREFIX}2  /boot ext4    defaults,noatime 0 0
${TARGET_PARTITIONS_PREFIX}1  /boot/efi vfat    defaults,noatime 0 0
${TARGET_PARTITIONS_PREFIX}3  swap swap    defaults,noatime 0 0
EOD
  cat << EOD | tr -s ' '
${TARGET_PARTITIONS_PREFIX}1 /boot/efi vfat defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}2 /boot ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}3 / ext3 defaults,noatime 0 1
${TARGET_PARTITIONS_PREFIX}5 none swap defaults,noatime 0 0
${TARGET_PARTITIONS_PREFIX}6 /tmp ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}7 /var ext3 defaults,noatime,nosuid 0 2
${TARGET_PARTITIONS_PREFIX}8 /var/tmp ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}9 /var/log ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}10 /var/log/audit ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}11 /home ext3 defaults,noatime 0 2
EOD
}

# Mounts source image copy
do_mount_source() {
  local SOURCE=${1}
  local SOURCE_MOUNT=${2}
  local SOURCE_PARTITIONS_PREFIX=${SOURCE}
  if [[ ${SOURCE: -1} =~ ^[0-9]$ ]]; then
    SOURCE_PARTITIONS_PREFIX=${SOURCE}p
  fi

  mount ${SOURCE_PARTITIONS_PREFIX}4 ${SOURCE_MOUNT}
  mount ${SOURCE_PARTITIONS_PREFIX}2 ${SOURCE_MOUNT}/boot
  mount ${SOURCE_PARTITIONS_PREFIX}1 ${SOURCE_MOUNT}/boot/efi
  touch ${SOURCE_MOUNT}/.autorelabel
}

source dd_partitions.env

