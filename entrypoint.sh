#!/bin/bash
set -e

# allow arguments to be passed to squid
if [[ ${1:0:1} = '-' ]]; then 
  EXTRA_ARGS="$@"
  set --
  # Takes the first character from arguments, if it starts with "-", set all of them under EXTRA_ARGS
  # Clear the argument list (set --)
elif [[ ${1} == squid || ${1} == $(which squid) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
  # If argument starts with "squid" or full path of squid, ignore "squid" and set subsequent arguments under EXTRA_ARGS
  # Clear the argument list (set --)
fi

# default behaviour is to launch squid
if [[ -z ${1} ]]; then
  if [[ ! -d ${SQUID_CACHE_DIR}/00 ]]; then
    # When squid initialises cache directory, it creates a subfolder of 00.
    # The presence of 00 folder means the cache has been initialized before and shall therefore be skipped
    echo "Initializing cache..."
    $(which squid) -N -f /etc/squid/squid.conf -z
  fi
  echo "Starting squid..."
  exec $(which squid) -f /etc/squid/squid.conf -NYCd 1 ${EXTRA_ARGS}
else
  exec "$@"
fi
