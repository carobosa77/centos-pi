#!/bin/bash

source dd.env ""

################################################################################
# Check environment & print usage information

# prints usage information
do_usage() {
  cat << EOD
${1} - Writes the image to the device indicated.
Usage: ${1} IMAGE DEVICE
EOD
  exit 1
}

# Check environment
do_check_parameters() {
  test -z "${1}" && echo "Error: Missing image file name." >&2 && \
    return 1
  test ! -e ${1} && echo "Error: Image file '${1}' does not exists." >&2 && \
    return 1
  test -z "${2}" && echo "Error: Missing target device name." >&2 && \
    return 1
  test ! -b ${2} && echo "Error: Device '${2}' does not exists." 1>&2 && \
    return 1

  return 0
}

do_check_parameters ${*} || do_usage $( basename ${0} )

IMAGE=${1}
TARGET=${2}

################################################################################
# Umounts target filesystems

do_umount ${TARGET}

################################################################################
# Writes the source image to the device

do_dd ${IMAGE} ${TARGET}

