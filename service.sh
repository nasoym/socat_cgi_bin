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

: ${ROUTES_PATH:="$(dirname $0)/handlers"}
: ${DEFAULT_ROUTE_HANDLER:="${ROUTES_PATH}/default"}

function upper() { echo "$@" | tr '[:lower:]' '[:upper:]'; }
function lower() { echo "$@" | tr '[:upper:]' '[:lower:]'; }

function defaultHeaders() {
  echo -e "Date: $(date -u "+%a, %d %b %Y %T GMT")\r"
  echo -e "Expires: 0\r"
  echo -e "Connection: close\r"
  echo -e "Cache-Control: no-cache, no-store, must-revalidate\r"
  echo -e "Pragma: no-cache\r"
}

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
  echo -e "HTTP/1.0 200 OK\r"
  defaultHeaders
  if [[ -n "${request_content:-""}" ]];then
    echo "$request_content" | ${ROUTES_PATH}/${SCRIPT_NAME}
  else
    ${ROUTES_PATH}/${SCRIPT_NAME}
  fi
else
  echo -e "HTTP/1.0 404 Not Found\r"
  defaultHeaders
  echo -e "\r"
fi

