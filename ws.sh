#!/bin/bash

# Stampa l'usage del comando web
function hsh::web ()
{
	printf "\nUsage hsh.sh web <command> <params>\n\n"
	printf "   create\tCrea un virtualhost\n";
	printf "   delete\tElimina un virtualhost\n";
	printf "   enable\tAbilita un virtualhost alla visibilità su internet\n";
	printf "   disable\tDisabilita un virtualhost dalla visibilità su internet\n";
	printf "   reload\tRigenera tutte le configurazioni\n";
	printf "   list\t\tElenca i virtualhost gestiti\n";
	printf "   details\tStampa i dettagli del virtualhost\n";
	printf "   restart\tRiavvia il webserver\n";
	printf "   stop\t\tStop del webserver\n";
	printf "   start\tStart del webserver\n";
	printf "   help\t\tStampa l'help per uno dei comandi di web, es. \"hsh web help create\"\n"
}


# gestisce l'help del ws
function hsh::web::help ()
{

	if [[ $1 == "create" ]] ; then
		hsh::web::create
	fi;

	if [[ $1 == "delete" ]] ; then
		hsh::web::delete
	fi;

	if [[ $1 == "details" ]] ; then
		hsh::web::details
	fi;

	if [[ $1 == "list" ]] ; then
		echo "list";
	fi;

	if [[ $1 == "reload" ]] ; then
		echo 'reload';
	fi;

}

# crea un virtualhost
hsh::web::create()
{

	if [[ -z $1 ]] ; then
		printf "Crea un virtualhost\n";
		printf "hsh web create <vhost> -s <http|https|both> -a \"alias1 alias2 aliasN\" -p <proxy-pass>\n\n";
		printf "   <vhost-name>\t\tNome del virtualhost\n"
		printf "   -s <socket>\t\tPossibili valori: http, https, both\n"
		printf "   -a <aliases>\t\tAlias da assegnare al virtualhost\n";
		printf "   -p <app-list>\tApp da proxare\n";
		exit 1;
	fi;

	VHOST_NAME=${COMMAND_ARGS[0]}
	GETOPTS_PARAMS="${COMMAND_ARGS[@]:1}"

	if [[ $(${BIN_JQ} --arg v "${VHOST_NAME}" '.ws.vhosts|map(.vhost_name == $v)| index(true)' ${CONFIG_FILE}) != "null" ]] ; then
		printf "Il dominio ${VHOST_NAME} è già configurato\n";
		${BIN_JQ} --arg v "${VHOST_NAME}" '.ws.vhosts[]|select(.vhost_name == $v)' ${CONFIG_FILE};
		exit;
	fi;

	while getopts "s:p:a:" flag ${GETOPTS_PARAMS[*]}; do
		case "${flag}" in
			s) 
				_socket=${OPTARG} 
				;;
			p)
				_app=${OPTARG}
				;;
			a)
				_aliases=${OPTARG}
				;;
			*) 
				hsh::web::help create 
				;;
		esac;
	done;

	_http="true"
	_tls="true"

	if [[ $_socket == "http" ]] ; then
		_tls="false"
		_http="true"
	fi;

	if [[ $_socket == "https" ]] ; then
		_tls="true"
		_http="false"
	fi;
	

	JSON_DATA="{ \
	\"vhost_name\" : \"${VHOST_NAME}\", \
	\"http\" : \"${_http}\", \
	\"tls\" : \"${_tls}\", \
	\"proxy\" : \"${_app}\", \
	\"aliases\" : \"${_aliases}\"
}"

   _tmpfile=$(mktemp)
   ${BIN_JQ} --argjson j "${JSON_DATA}" '.ws.vhosts += [$j]' ${CONFIG_FILE} > $_tmpfile;
   mv $_tmpfile ${CONFIG_FILE};

   # create single vhosts from config file

   hsh::web::reload ${VHOST_NAME}

}


# elimina un virtualhost
hsh::web::delete()
{

	if [[ -z $1 ]] ; then
		printf "Elimina un virtualhost\n";
		printf "hsh web delete <vhost>\n\n"
		printf "   <vhost-name>\t\tNome del virtualhost\n"
		exit 1;
	fi;


	VHOST_NAME=${COMMAND_ARGS[0]}
	GETOPTS_PARAMS="${COMMAND_ARGS[@]:1}"

	if [[ $(jq --arg v "${VHOST_NAME}" '.ws.vhosts|map(.vhost_name == $v)| index(true)' ${CONFIG_FILE}) == "null" ]] ; then
		printf "Il dominio ${VHOST_NAME} non esiste\n";
		exit;
	fi;

	_tmpfile=$(mktemp)
	${BIN_JQ} --arg v ${VHOST_NAME} 'del(.ws.vhosts[]|select(.vhost_name == $v))' ${CONFIG_FILE} > $_tmpfile;
	mv $_tmpfile ${CONFIG_FILE};

	
	VS_PATH_DOCROOT=${WS_VHOST_PATH}/${VHOST_NAME}/docroot
	VS_PATH_CERTS=${WS_VHOST_PATH}/${VHOST_NAME}/certs
	HTTP_VHOST_FILE=${WS_VHOST_CONF_PATH}/${VHOST_NAME}.http.conf
	HTTPS_VHOST_FILE=${WS_VHOST_CONF_PATH}/${VHOST_NAME}.https.conf

	rm -f ${HTTP_VHOST_FILE} ${HTTPS_VHOST_FILE};
	hsh::web::list;

	# delete dei file del virtualhost
}


# elenca i virtualhost
hsh::web::list()
{
	printf "\nvhost\t\t\thttp https\tProxyPass\t\tAliases";
	printf "\n-----------------------------------------------------------------------\n";
	${BIN_JQ} -c '.ws.vhosts[]' ${CONFIG_FILE} | while read v ; do
		_vhost_name=$(echo $v | ${BIN_JQ} --raw-output '.vhost_name')
		_http=$(echo $v | ${BIN_JQ} --raw-output '.http')
		_tls=$(echo $v | ${BIN_JQ} --raw-output '.tls')
		_proxy=$(echo $v | ${BIN_JQ} --raw-output '.proxy')
		_aliases=$(echo $v | ${BIN_JQ} --raw-output '.aliases')
		printf "%23s\t" "${_vhost_name}";
		printf "${_http}";
		printf " ${_tls}\t";
		printf "%-23s\t" "${_proxy}";
		printf "${_aliases}\t\n";
	done;
	printf "\n";

}

# dettagli del virtualhost
hsh::web::details()
{

	if [[ -z $1 ]] ; then
		printf "Visualizza un virtualhost\n";
		printf "hsh web details <vhost>\n\n"
		printf "   <vhost-name>\t\tNome del virtualhost\n"
		exit 1;
	fi;

	VHOST_NAME=${COMMAND_ARGS[0]}
	GETOPTS_PARAMS="${COMMAND_ARGS[@]:1}"

	if [[ $(${BIN_JQ} --arg v "${VHOST_NAME}" '.ws.vhosts|map(.vhost_name == $v)| index(true)' ${CONFIG_FILE}) == "null" ]] ; then
		printf "Il dominio ${VHOST_NAME} non esiste\n";
		exit;
	fi;

	${BIN_JQ} --arg v "${VHOST_NAME}" '.ws.vhosts[]|select(.vhost_name == $v)' ${CONFIG_FILE};

}

# rebuild dei virtualhost
hsh::web::reload()
{

	if [[ ! -z $1 ]] ; then
		if [[ $(${BIN_JQ} --arg v "${1}" '.ws.vhosts|map(.vhost_name == $v)| index(true)' ${CONFIG_FILE}) == "null" ]] ; then
			printf "Il dominio ${1} non esiste\n";
			exit;
		fi;
		_single_vhost=$(${BIN_JQ} --arg v "${1}" '.ws.vhosts[]|select(.vhost_name == $v)' ${CONFIG_FILE})
		__make_single_vhost $_single_vhost
	fi;


	if [[ -z $1 ]] ; then
		${BIN_JQ} -c '.ws.vhosts[]' ${CONFIG_FILE} | while read v ; do
			__make_single_vhost $v
		done;
	fi;
}

__make_single_vhost()
{

	# vanno create le directory

	v=$*;
	_vhost_name=$(echo $v | ${BIN_JQ} --raw-output '.vhost_name')
	_http=$(echo $v | ${BIN_JQ} --raw-output '.http')
	_tls=$(echo $v | ${BIN_JQ} --raw-output '.tls')
	_proxy=$(echo $v | ${BIN_JQ} --raw-output '.proxy')
	_aliases=$(echo $v | ${BIN_JQ} --raw-output '.aliases')


	_ws_url=$(echo ${_proxy} | ${BIN_PERL} -pe 's/^http[s]/ws/g')


	VS_PATH_DOCROOT=${WS_VHOST_PATH}/${_vhost_name}/docroot
	VS_PATH_CERTS=${WS_VHOST_PATH}/${_vhost_name}/certs
	HTTP_VHOST_FILE=${WS_VHOST_CONF_PATH}/${_vhost_name}.http.conf
	HTTPS_VHOST_FILE=${WS_VHOST_CONF_PATH}/${_vhost_name}.https.conf

	INDEX_FILE=${WS_VHOST_PATH}/${_vhost_name}/docroot/index.html

	mkdir -p ${VS_PATH_DOCROOT};
	mkdir -p ${VS_PATH_CERTS};

	if [[ $_http == "true" ]] ; then
		printf "<VirtualHost *:80>\n" > ${HTTP_VHOST_FILE};
		printf "\tDocumentRoot \"/vhosts/${_vhost_name}/docroot\"\n" >> ${HTTP_VHOST_FILE};
		printf "\tServerName ${_vhost_name}\n" >> ${HTTP_VHOST_FILE};
		for a in $_aliases ; do
			printf "\tServerAlias ${a}\n" >> ${HTTP_VHOST_FILE};
		done;
		printf "\n" >> ${HTTP_VHOST_FILE};
		printf "\t<Directory \"/vhosts/${_vhost_name}/docroot/\">\n" >> ${HTTP_VHOST_FILE};
		printf "\t\tOptions Indexes FollowSymlinks\n" >> ${HTTP_VHOST_FILE};
		printf "\t\tAllowOverride None\n" >> ${HTTP_VHOST_FILE};
		printf "\t\tRequire all granted\n" >> ${HTTP_VHOST_FILE};
		printf "\t</Directory>\n" >> ${HTTP_VHOST_FILE};
		printf "\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteEngine on\n" >> ${HTTP_VHOST_FILE};
		printf "\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteCond %%{DOCUMENT_ROOT}/\$1 -f [OR]\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteCond %%{DOCUMENT_ROOT}/\$1 -d\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteCond %%{REQUEST_URI} !=/\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteRule (.*) - [L]\n" >> ${HTTP_VHOST_FILE};
		printf "\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteCond %%{HTTP:Upgrade} =websocket [NC]\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteRule /(.*) ${_ws_url}\$1 [P,L]\n" >> ${HTTP_VHOST_FILE};
		printf "\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteCond %%{HTTP:Upgrade} !=websocket [NC]\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteRule /(.*) ${_proxy}\$1 [P,L]\n" >> ${HTTP_VHOST_FILE};
		printf "\n" >> ${HTTP_VHOST_FILE};
		printf "\tRewriteRule ^/(.*)$ ${_proxy}\$1 [P,QSA]\n" >> ${HTTP_VHOST_FILE};
		printf "\n" >> ${HTTP_VHOST_FILE};
		printf "\tCustomLog \"|bin/rotatelogs -l /logs/${_vhost_name}.ok.http.%%Y-%%m-%%d.log 86400\" json_format\n" >> ${HTTP_VHOST_FILE};
		printf "\tErrorLog  \"|bin/rotatelogs -l /logs/${_vhost_name}.error.http.%%Y-%%m-%%d.log 86400\"\n" >> ${HTTP_VHOST_FILE};
		printf "\n" >> ${HTTP_VHOST_FILE};
		printf "</VirtualHost>\n" >> ${HTTP_VHOST_FILE};
	fi;

	if [[ $_tls == "true" ]] ; then
		printf "<VirtualHost *:443>\n" > ${HTTPS_VHOST_FILE};
		printf "\tDocumentRoot \"/vhosts/${_vhost_name}/docroot\"\n" >> ${HTTPS_VHOST_FILE};
		printf "\tServerName ${_vhost_name}\n" >> ${HTTPS_VHOST_FILE};
		for a in $_aliases ; do
			printf "\tServerAlias ${a}\n" >> ${HTTPS_VHOST_FILE};
		done;
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\t<Directory \"/vhosts/${_vhost_name}/docroot/\">\n" >> ${HTTPS_VHOST_FILE};
		printf "\t\tOptions Indexes FollowSymlinks\n" >> ${HTTPS_VHOST_FILE};
		printf "\t\tAllowOverride None\n" >> ${HTTPS_VHOST_FILE};
		printf "\t\tRequire all granted\n" >> ${HTTPS_VHOST_FILE};
		printf "\t</Directory>\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteEngine on\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteCond %%{DOCUMENT_ROOT}/\$1 -f [OR]\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteCond %%{DOCUMENT_ROOT}/\$1 -d\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteCond %%{REQUEST_URI} !=/\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteRule (.*) - [L]\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteCond %%{HTTP:Upgrade} =websocket [NC]\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteRule /(.*) ${_ws_url}\$1 [P,L]\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteCond %%{HTTP:Upgrade} !=websocket [NC]\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteRule /(.*) ${_proxy}\$1 [P,L]\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\tRewriteRule ^/(.*)$ ${_proxy}\$1 [P,QSA]\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\tSSLEngine on\n" >> ${HTTPS_VHOST_FILE};
		printf "\tSSLProtocol all -SSLv2\n" >> ${HTTPS_VHOST_FILE};
		printf "\tSSLCipherSuite HIGH:MEDIUM:!aNULL:!MD5\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\tSSLCertificateKeyFile    /vhosts/${_vhost_name}/certs/key.pem\n" >> ${HTTPS_VHOST_FILE};
		printf "\tSSLCertificateFile       /vhosts/${_vhost_name}/certs/cert.pem\n" >> ${HTTPS_VHOST_FILE};
		printf "\tSSLCertificateChainFile  /vhosts/${_vhost_name}/certs/chain.pem\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "\tCustomLog \"|bin/rotatelogs -l /logs/${_vhost_name}.ok.https.%%Y-%%m-%%d.log 86400\" json_format\n" >> ${HTTPS_VHOST_FILE};
		printf "\tErrorLog  \"|bin/rotatelogs -l /logs/${_vhost_name}.error.https.%%Y-%%m-%%d.log 86400\"\n" >> ${HTTPS_VHOST_FILE};
		printf "\n" >> ${HTTPS_VHOST_FILE};
		printf "</VirtualHost>\n" >> ${HTTPS_VHOST_FILE};
	fi;

	printf "<html><head></head><body><h1>${_vhost_name} site</h1></body></html>" >${INDEX_FILE}


	if [[ ! -f ${VS_PATH_CERTS}/key.pem ]] ; then
		cp ws/self_key.pem ${VS_PATH_CERTS}/key.pem;
		cp ws/self_cert.pem ${VS_PATH_CERTS}/cert.pem;
		cp ws/self_cert.pem ${VS_PATH_CERTS}/chain.pem;
	fi;

}




