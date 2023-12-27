#!/bin/bash

# idea https://github.com/denysdovhan/smart-home/blob/master/bin/smart-home


# check dei binary che servono
# es. docker, docker compose, curl, wget, env substitute, getopts etc
# getopts (apt install opt)
# jq
# perl 

# working directory 

# load 


if [[ $(which docker 2>&1 >/dev/null ; echo $?) -eq 1 ]] ; then
	printf "Docker non è installato\n";
	exit 1;
fi;

if [[ $(which curl 2>&1 >/dev/null ; echo $?) -eq 1 ]] ; then
	printf "cURL non è installato\n";
	exit 1;
fi;


if [[ $(which wget 2>&1 >/dev/null ; echo $?) -eq 1 ]] ; then
	printf "Wget non è installato\n";
	exit 1;
fi;

if [[ $(which jq 2>&1 >/dev/null ; echo $?) -eq 1 ]] ; then
	printf "jq non è installato\n";
	exit 1;
fi;

if [[ $(which perl 2>&1 >/dev/null ; echo $?) -eq 1 ]] ; then
	printf "perl non è installato\n";
	exit 1;
fi;


BIN_DOCKER=$(which docker)
BIN_CURL=$(which curl)
BIN_WGET=$(which wget)
BIN_JQ=$(which jq)
BIN_PERL=$(which perl)

if [[ $(which docker-compose 2>&1 1>/dev/null ; echo $?) -eq 1 ]] ; then
	if [[ $(docker compose 1>&2 2>/dev/null ; echo $?) -eq 1 ]] ; then
			printf "docker compose non è installato\n";
			exit 1;
	else
			BIN_DOCKER_COMPOSE="${BIN_DOCKER} compose"
	fi;
else
	BIN_DOCKER_COMPOSE=$(which docker-compose)
fi;


source ./env


PROJECT_DIRECTORY=$(${BIN_JQ} --raw-output '.base_path' ${CONFIG_FILE})

WS_DIRECTORY=${PROJECT_DIRECTORY}/ws
WS_VHOST_PATH="${WS_DIRECTORY}/vhosts";
WS_VHOST_CONF_PATH="${WS_DIRECTORY}/vhosts_conf"
WS_LOG_FORMAT="${WS_DIRECTORY}/logs";

# per ogni

# vhost file format
# <vhost-name>;<http-flag>;<https-flag>;<document-root>;<log-format>;<error-log-format>;<alias list>;<app list>

# app list
# <app-name>;<app-value>


LOAD_SCRIPT="ws.sh"


for s in $LOAD_SCRIPT ; do
	source ${s};
done;


DIRECTORY_LIST="${PROJECT_DIRECTORY} ${WS_DIRECTORY} ${WS_VHOST_PATH} ${WS_LOG_FORMAT} ${WS_VHOST_CONF_PATH}"

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

