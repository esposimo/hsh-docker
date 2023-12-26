#!/bin/bash

# idea https://github.com/denysdovhan/smart-home/blob/master/bin/smart-home


# check dei binary che servono
# es. docker, docker compose, curl, wget, env substitute, getopts etc
# getopts (apt install opt)
# jq
# perl 

# working directory 


WORKING_DIRECTORY=$HOME/.hsh-work
CONFIG_FILE=${WORKING_DIRECTORY}/config.json


WS_DIRECTORY="${WORKING_DIRECTORY}/ws"
WS_VHOST_FILE="${WS_DIRECTORY}/vhost_list";
WS_APP_LIST="${WS_DIRECTORY}/app_list";
WS_LOG_FORMAT="${WS_DIRECTORY}/log_list";

# per ogni

# vhost file format
# <vhost-name>;<http-flag>;<https-flag>;<document-root>;<log-format>;<error-log-format>;<alias list>;<app list>

# app list
# <app-name>;<app-value>


LOAD_SCRIPT="ws.sh"


for s in $LOAD_SCRIPT ; do
	source ${s};
done;


DIRECTORY_LIST="${WORKING_DIRECTORY} $WORKING_DIRECTORY/ws"

for d in ${DIRECTORY_LIST} ; do
	if [[ ! -d ${d} ]] ; then
		mkdir -p ${d};
	fi;
done;

COMMAND="$1"
shift 1
PARAMS="$1"
shift 1
COMMAND_ARGS=("${@}")


function usage()
{
	printf "Gestione della tua smart-home\n";
	printf "hsh <command> [PARAMS]\n\n";
	printf "   web\tGestione del webserver\n";
}


function main() {
  
  if [[ -z $COMMAND ]] ; then
  	usage;
  	exit 1;
  fi;

  if [[ -z $PARAMS ]] ; then
  	hsh::"$COMMAND";
  	exit 1;
  fi;


  if [[ $(type -t hsh::"$COMMAND"::"$PARAMS") == "function" ]] ; then
  	hsh::"$COMMAND"::"$PARAMS" "${COMMAND_ARGS[*]}";
  else
  	hsh::"$COMMAND";
  fi;

  return $?
}

main

