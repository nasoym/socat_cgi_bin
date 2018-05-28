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

function upper() { echo "$@" | tr '[:lower:]' '[:upper:]'; }
export -f upper
function lower() { echo "$@" | tr '[:upper:]' '[:lower:]'; }
export -f lower

function defaultHeaders() {
  echo "Date: $(date -u "+%a, %d %b %Y %T GMT")"
  echo "Expires: 0"
  echo "Connection: close"
  echo "Cache-Control: no-cache, no-store, must-revalidate"
  echo "Pragma: no-cache"
}
export -f defaultHeaders

function handle() {
  read -r REQUEST_METHOD REQUEST_URI SERVER_PROTOCOL
  export REQUEST_METHOD REQUEST_URI SERVER_PROTOCOL

  while read -r line; do 
    line="$(echo "$line" | tr -d '\r')"
    [[ "$line" =~ ^$ ]] && { break; } 
    header_key="${line/%: */}"
    header_key="$(upper ${header_key//-/_} )"
    header_value="${line/#*: /}"
    export HTTP_${header_key}="${header_value}"
  done
  if [[ -n "${HTTP_CONTENT_LENGTH:-""}" ]] && [[ "${HTTP_CONTENT_LENGTH:-0}" -gt "0" ]];then
    read -r -d '' -n "${HTTP_CONTENT_LENGTH}" request_content
  fi
  export SCRIPT_NAME="${REQUEST_URI/%\?*/}"
  if [[ "${REQUEST_URI}" =~ \? ]]; then
    export QUERY_STRING="${REQUEST_URI#*\?}"
  fi

  echo "request: ${SOCAT_PEERADDR}:${SOCAT_PEERPORT} ${REQUEST_METHOD} ${REQUEST_URI} ${SCRIPT_NAME}" >&2
  if [[ -x "${ROUTES_PATH}/${SCRIPT_NAME}" ]];then
    echo "HTTP/1.0 200 OK"
    defaultHeaders
    if [[ -n "${request_content:-""}" ]];then
      echo "$request_content" | ${ROUTES_PATH}/${SCRIPT_NAME}
    else
      ${ROUTES_PATH}/${SCRIPT_NAME}
    fi
  else
    echo "HTTP/1.0 404 Not Found"
    defaultHeaders
    echo ""
  fi
}
export -f handle

socat ${socat_options} TCP-LISTEN:${port},reuseaddr,fork SYSTEM:handle

