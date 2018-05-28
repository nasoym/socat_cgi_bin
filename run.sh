#!/usr/bin/env bash

set -o errexit  # abort when any commands exits with error
set -o pipefail # abort when any command in a pipe exits with error
set -o nounset  # abort when any unset variable is used
set -o errtrace # inherits trap on ERR in function and subshell
set -f # prevent bash from expanding glob
trap 'echo status:$? line:$LINENO line:$BASH_LINENO command:"$BASH_COMMAND" functions:$(printf " %s" ${FUNCNAME[@]:-})' ERR

if [[ "${trace:=0}" -eq 1 ]];then
  PS4='${LINENO}: '
  set -x
  export trace
fi

while getopts "p:" options; do case $options in
  p) port="$OPTARG" ;;
esac; done; shift $(( OPTIND - 1 ))

: ${port:="8080"}
: ${socat_timeout:="60"}
: ${socat_options:=""} #-vv
: ${service:="$(dirname $0)/service.sh"}
: ${socat_listen_command:="TCP-LISTEN:${port},reuseaddr,fork"}

socat \
  -T ${socat_timeout} \
  ${socat_options} \
  ${socat_listen_command} \
  EXEC:"${service}"

