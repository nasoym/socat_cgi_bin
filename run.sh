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

self="$(dirname $(realpath $0))"

while getopts "p:r:s:" options; do case $options in
  s) socat_options="$OPTARG" ;;
  p) port="$OPTARG" ;;
  r) ROUTES_PATH="$OPTARG" ;;
esac; done; shift $(( OPTIND - 1 ))

: ${port:="8080"}
: ${socat_options:="-T60"} #-vv

if [[ -z "${ROUTES_PATH:-""}" ]] && [[ -n "$@" ]] && [[ -d "$@" ]];then
  : ${ROUTES_PATH:="$@"}
elif [[ -z "${ROUTES_PATH:-""}" ]] && [[ -n "$@" ]] && [[ -d "$(pwd)/$@" ]];then
  : ${ROUTES_PATH:="$(pwd)/$@"}
elif [[ -z "${ROUTES_PATH:-""}" ]] && [[ -d "${self}/handlers" ]];then
  : ${ROUTES_PATH:="${self}/handlers"}
elif [[ -z "${ROUTES_PATH:-""}" ]] && [[ -d "$(pwd)/handlers" ]];then
  : ${ROUTES_PATH:="$(pwd)/handlers"}
fi
export ROUTES_PATH

socat ${socat_options} TCP-LISTEN:${port},reuseaddr,fork EXEC:"${self}/service.sh"

