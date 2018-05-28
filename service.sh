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

source $(dirname $0)/lib/logger
source $(dirname $0)/lib/http_helpers
source $(dirname $0)/lib/parse_request
source $(dirname $0)/lib/find_handler_file
source $(dirname $0)/lib/jwt_verify

: ${ROUTES_PATH:="$(dirname $0)/handlers"}
: ${DEFAULT_ROUTE_HANDLER:="${ROUTES_PATH}/default"}
: ${AUTHENTICATE:="1"}
: ${VERBOSE_LOGGING:="0"}
export VERBOSE_LOGGING="$VERBOSE_LOGGING"

parse_request
log "request: ${SOCAT_PEERADDR}:${SOCAT_PEERPORT} ${request_method} ${request_uri}"

if [[ "$AUTHENTICATE" = 1 ]];then
  if [[ -z "$request_header_authorization" ]];then
    authorization_token="$( echo "$request_header_cookie" \
      | sed -e 's/; */\n/g' \
      | awk -F '=' '{if ($1=="authentication") {print $2}}' )"
  else
    authorization_token="${request_header_authorization#* }"
  fi
  public_key_file="public_keys/public_key"
  if ! jwt_verify "$authorization_token" $public_key_file; then
    log "jwt signature failed"
    echo_response_status_line 401 "Unauthorized"
    echo_response_default_headers
    echo -e "\r"
    exit 0
  fi
fi

find_handler_file $request_path

if [[ -n "$request_matching_route_file" ]];then
  RESPONSE_CONTENT="$(echo "$request_content" | $request_matching_route_file $(urldecode ${request_subpath//\// }))"
  if [[ $? -eq 1 ]];then
    echo_response_status_line 500 "Internal Server Error"
    echo_response_default_headers
    echo -e "\r"
  else
    if [[ "$RESPONSE_CONTENT" =~ ^HTTP\/[0-9]+\.[0-9]+\ [0-9]+ ]];then
      echo "${RESPONSE_CONTENT}"
    else
      echo "${RESPONSE_CONTENT}" | echo_content_response
    fi
  fi
else
  echo_response_status_line 404 "Not Found"
  echo_response_default_headers
  echo -e "\r"
fi

