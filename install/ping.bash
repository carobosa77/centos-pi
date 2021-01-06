#!/bin/bash

source ../centos/do_actions.env ""

PORT="22"
NETMASK="32"
IPS=""

# Check parameters
do_check_parameters() {
  local OPT
  local IP

  while getopts ":hp:n:" OPT; do
    case "${OPT}" in
      h) return 1;;
      p) PORT=${OPTARG};;
      n) NETMASK=${OPTARG};;
      ?) echo "Error: Invalid option." 1>&2; return 1;;
    esac
  done
  shift $(( ${OPTIND}-1 ))

  for IP in "$@"; do
    if ! do_check_valid_ip ${IP}; then
      echo "Error: Invalid IP." 1>&2; return 1
    fi
  done

  if [ -z "${*}" ]; then
    echo "Error: No IP indicated." 1>&2; return 1
  fi

  IPS=${*}
}

# prints usage information
do_usage() {
  cat << EOD
${1} - Checks ping to targets indicated
Usage: ${1} [-p PORT] [-n NETMASK] IP [...]
EOD
  exit 1
}

do_check_parameters ${*} || do_usage $( basename ${0} )

# Transforms an IP to an integer
do_ip2int() {
  local OIFS=${IFS}
  IFS='.'
  local IP=(${1})
  IFS=${OIFS}
  local INT=0
  for i in "${IP[@]}"; do
    INT=$(( ${INT} * 256 + ${i} ))
  done
  echo ${INT}
}

# Transforms an integer to an IP
do_int2ip() {
  local IP=""  
  local INT=${1}
  local i
  for i in {1..3}; do
    IP=".$(( ${INT} % 256 ))${IP}"
    INT=$(( ${INT} / 256 ))
  done
  echo "${INT}${IP}"
}

# Checks if the IP indicated has ping and connection to the port
do_check_ip() {
  local IP=${1}

  if echo -n "${IP}: ping? " && ! ping -c1 ${IP} 1> /dev/null; then
    echo "No."
  elif [ -z ${PORT} ]; then
    echo "Yes."
  elif echo -n "Yes. Port ${PORT}? " && ! nc -z ${IP} ${PORT}; then
    echo "No."
  else
    echo "Yes."
  fi
}

# Checks if the IP indicated has ping and connection to the port
do_check_subnet() {
  local INT=$( do_ip2int ${1} )
  local DIVISOR=$((2 ** (32 - ${NETMASK}) ))
  local FIRST=$(( ( ${INT} / ${DIVISOR} ) * ${DIVISOR} ))
  local LAST=$(( ( ${INT} / ${DIVISOR} + 1) * ${DIVISOR} ))
  local i
  for ((i=${FIRST}; i<${LAST}; i++)); do
    do_check_ip $( do_int2ip ${i} )
  done
}

for IP in ${IPS}; do
  do_check_subnet ${IP}
done

