#!/bin/bash

# Download the image from https://people.centos.org/pgreco/CentOS-Userland-8-stream-aarch64-RaspberryPI-Minimal-4/, until one official is provided

# Defines the TARGET device, the IMAGE file and the TEMPorary (working) directory
TARGET=/dev/sdc
IMAGE=CentOS-Userland-8-stream-aarch64-RaspberryPI-Minimal-4-sda.raw.xz
TEMP=$( mktemp -d )
#FORCE=true

TARGET_PARTITIONS_PREFIX=${TARGET}
if [[ ${TARGET: -1} =~ ^[0-9]$ ]]; then
  TARGET_PARTITIONS_PREFIX=${TARGET}p
fi

# Shows partition information, in the format that sfdisk understands
do_sfdisk() {
  cat << EOD > /dev/null
${TARGET_PARTITIONS_PREFIX}1 : start=        8192, size=      585728, type=c, bootable
${TARGET_PARTITIONS_PREFIX}2 : start=      593920, size=      999424, type=82
${TARGET_PARTITIONS_PREFIX}3 : start=     1593344, size=     4687872, type=83
EOD
  cat << EOD
${TARGET_PARTITIONS_PREFIX}1 : start=        8192, size=      585728, type=c, bootable
${TARGET_PARTITIONS_PREFIX}2 : start=      593920, size=      999424, type=82
${TARGET_PARTITIONS_PREFIX}3 : start=     1593344, size=     4687872, type=83
${TARGET_PARTITIONS_PREFIX}4 : start=     6281216, size=    20971520, type=5
${TARGET_PARTITIONS_PREFIX}5 : start=     6283264, size=     2097152, type=83
${TARGET_PARTITIONS_PREFIX}6 : start=     8382464, size=     4194304, type=83
${TARGET_PARTITIONS_PREFIX}7 : start=    12578816, size=     2097152, type=83
${TARGET_PARTITIONS_PREFIX}8 : start=    14678016, size=     4194304, type=83
${TARGET_PARTITIONS_PREFIX}9 : start=    18874368, size=     1048576, type=83
${TARGET_PARTITIONS_PREFIX}10 : start=    19924992, size=     1048576, type=83
EOD
}

# Shows the mount points information, in the format of the fstab file
do_fstab() {
  cat << EOD | tr -s ' ' > /dev/null
${TARGET_PARTITIONS_PREFIX}3 / ext4    defaults,noatime 0 0
${TARGET_PARTITIONS_PREFIX}1 /boot vfat    defaults,noatime 0 0
${TARGET_PARTITIONS_PREFIX}2 swap swap    defaults,noatime 0 0
EOD
  cat << EOD | tr -s ' '
${TARGET_PARTITIONS_PREFIX}1 /boot vfat defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}2 none swap defaults 0 0
${TARGET_PARTITIONS_PREFIX}3 / ext3 defaults,noatime 0 1
${TARGET_PARTITIONS_PREFIX}5 /tmp ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}6 /var ext3 defaults,noatime,nosuid 0 2
${TARGET_PARTITIONS_PREFIX}7 /var/tmp ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}8 /var/log ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}9 /var/log/audit ext3 defaults,noatime,nosuid,noexec,nodev 0 2
${TARGET_PARTITIONS_PREFIX}10 /home ext3 defaults,noatime 0 2
EOD
}

TEMP=${TEMP%/}
SOURCE_MOUNT=${TEMP}/source.mnt; [ -d ${SOURCE_MOUNT} ] || mkdir ${SOURCE_MOUNT}
TARGET_MOUNT=${TEMP}/target.mnt; [ -d ${TARGET_MOUNT} ] || mkdir ${TARGET_MOUNT}

source dd.env ""

################################################################################
# Umounts target filesystems

do_umount ${TARGET}

################################################################################
# Writes the source image to the device

do_dd ${IMAGE} ${TARGET}

################################################################################
# Creates target additional filesystems

do_sfdisk | sfdisk -q ${TARGET} || true
partprobe ${TARGET}

do_fstab | grep -v "${TARGET_PARTITIONS_PREFIX}[123] " | do_mkfs ""

################################################################################
# Mounts source partition

mount ${TARGET_PARTITIONS_PREFIX}3 ${SOURCE_MOUNT}
touch ${SOURCE_MOUNT}/.autorelabel

################################################################################
# Build fstab file

sed 's/swap swap    defaults,noatime/none swap    defaults/' ${SOURCE_MOUNT}/etc/fstab > ${TEMP}/fstab
do_fstab | grep -v "${TARGET_PARTITIONS_PREFIX}[123] " | \
  sort -k 2,2 | do_fstab_dev2uuid >> ${TEMP}/fstab
cp -fbv --no-preserve=all ${TEMP}/fstab ${SOURCE_MOUNT}/etc/fstab

################################################################################
# Move files from image to TARGET device
do_fstab | grep -v "${TARGET_PARTITIONS_PREFIX}[123] " | \
  do_mv2target ${SOURCE_MOUNT} ${TARGET_MOUNT}

################################################################################
# Finalize

umount ${TARGET_PARTITIONS_PREFIX}3
rm -rf ${TEMP}

