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
#	printf "   log-list\tElenca i log format gestiti\n";
#	printf "   app-create\tCrea un app da utilizzare per le proxy pass\n";
#	printf "   app-delete\tElimina un'app da utilizzare per le proxy pass\n"
#	printf "   app-list\tElenca le app gestite\n";
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

	if [[ $(jq --arg v "${VHOST_NAME}" '.ws.vhosts|map(.vhost_name == $v)| index(true)' ${CONFIG_FILE}) != "null" ]] ; then
		printf "Il dominio ${VHOST_NAME} è già configurato\n";
		jq --arg v "${VHOST_NAME}" '.ws.vhosts[]|select(.vhost_name == $v)' ${CONFIG_FILE};
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
   jq --argjson j "${JSON_DATA}" '.ws.vhosts += [$j]' ${CONFIG_FILE} > $_tmpfile;
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
		#jq --arg v "${VHOST_NAME}" '.ws.vhosts[]|select(.vhost_name == $v)' ${CONFIG_FILE};
		exit;
	fi;

	_tmpfile=$(mktemp)
	jq --arg v ${VHOST_NAME} 'del(.ws.vhosts[]|select(.vhost_name == $v))' ${CONFIG_FILE} > $_tmpfile;
	mv $_tmpfile ${CONFIG_FILE};
	hsh::web::list;

	# delete dei file del virtualhost
}


# elenca i virtualhost
hsh::web::list()
{
	printf "\nvhost\t\t\thttp https\tProxyPass\t\tAliases";
	printf "\n-----------------------------------------------------------------------\n";
	jq -c '.ws.vhosts[]' ${CONFIG_FILE} | while read v ; do
		_vhost_name=$(echo $v | jq --raw-output '.vhost_name')
		_http=$(echo $v | jq --raw-output '.http')
		_tls=$(echo $v | jq --raw-output '.tls')
		_proxy=$(echo $v | jq --raw-output '.proxy')
		_aliases=$(echo $v | jq --raw-output '.aliases')
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

	if [[ $(jq --arg v "${VHOST_NAME}" '.ws.vhosts|map(.vhost_name == $v)| index(true)' ${CONFIG_FILE}) == "null" ]] ; then
		printf "Il dominio ${VHOST_NAME} non esiste\n";
		exit;
	fi;

	jq --arg v "${VHOST_NAME}" '.ws.vhosts[]|select(.vhost_name == $v)' ${CONFIG_FILE};

}



# rebuild dei virtualhost
hsh::web::reload()
{

	if [[ ! -z $1 ]] ; then
		if [[ $(jq --arg v "${1}" '.ws.vhosts|map(.vhost_name == $v)| index(true)' ${CONFIG_FILE}) == "null" ]] ; then
			printf "Il dominio ${1} non esiste\n";
			exit;
		fi;
		_single_vhost=$(jq --arg v "${1}" '.ws.vhosts[]|select(.vhost_name == $v)' ${CONFIG_FILE})
		__make_single_vhost $_single_vhost
	fi;


	if [[ -z $1 ]] ; then
		jq -c '.ws.vhosts[]' ${CONFIG_FILE} | while read v ; do
			__make_single_vhost $v
		done;
	fi;
}





__make_single_vhost()
{

	# vanno create le directory

	v=$*;
	_vhost_name=$(echo $v | jq --raw-output '.vhost_name')
	_http=$(echo $v | jq --raw-output '.http')
	_tls=$(echo $v | jq --raw-output '.tls')
	_proxy=$(echo $v | jq --raw-output '.proxy')
	_aliases=$(echo $v | jq --raw-output '.aliases')

	_base_docroot=$(jq --raw-output '.ws.base_docroot' ${CONFIG_FILE})

	_ws_url=$(echo ${_proxy} | perl -pe 's/^http[s]/ws/g')

	if [[ $_http == "true" ]] ; then
		printf "<VirtualHost *:80>\n";
		printf "\tDocumentRoot \"${_base_docroot}/${_vhost_name}/docroot\"\n";
		printf "\tServerName ${_vhost_name}\n";
		for a in $_aliases ; do
			printf "\tServerAlias ${a}\n";
		done;
		printf "\n";
		printf "\t<Directory \"${_base_docroot}/${_vhost_name}/docroot/\">\n";
		printf "\t\tOptions Indexes FollowSymlinks\n";
		printf "\t\tAllowOverride None\n";
		printf "\t\tRequire all granted\n";
		printf "\t</Directory>\n";
		printf "\n";
		printf "\tRewriteEngine on\n";
		printf "\n";
		printf "\tRewriteCond %%{DOCUMENT_ROOT}/\$1 -f [OR]\n";
		printf "\tRewriteCond %%{DOCUMENT_ROOT}/\$1 -d\n";
		printf "\tRewriteCond %%{REQUEST_URI} !=/\n";
		printf "\tRewriteRule (.*) - [L]\n";
		printf "\n";
		printf "\tRewriteCond %%{HTTP:Upgrade} =websocket [NC]\n";
		printf "\tRewriteRule /(.*) ${_ws_url}\$1 [P,L]\n";
		printf "\n";
		printf "\tRewriteCond %%{HTTP:Upgrade} !=websocket [NC]\n";
		printf "\tRewriteRule /(.*) ${_proxy}\$1 [P,L]\n";
		printf "\n";
		printf "\tRewriteRule ^/(.*)$ ${_proxy}\$1 [P,QSA]\n";
		printf "\n";
		printf "\tCustomLog \"|bin/rotatelogs -l /logs/${_vhost_name}.ok.http.%%Y-%%m-%%d.log 86400\" json_format\n";
		printf "\tErrorLog  \"|bin/rotatelogs -l /logs/${_vhost_name}.error.http.%%Y-%%m-%%d.log 86400\"\n";
		printf "\n";
		printf "</VirtualHost>\n";
	fi;

	if [[ $_tls == "true" ]] ; then
		printf "<VirtualHost *:443>\n";
		printf "\tDocumentRoot \"${_base_docroot}/${_vhost_name}/docroot\"\n";
		printf "\tServerName ${_vhost_name}\n";
		for a in $_aliases ; do
			printf "\tServerAlias ${a}\n";
		done;
		printf "\n";
		printf "\t<Directory \"${_base_docroot}/${_vhost_name}/docroot/\">\n";
		printf "\t\tOptions Indexes FollowSymlinks\n";
		printf "\t\tAllowOverride None\n";
		printf "\t\tRequire all granted\n";
		printf "\t</Directory>\n";
		printf "\n";
		printf "\tRewriteEngine on\n";
		printf "\n";
		printf "\tRewriteCond %%{DOCUMENT_ROOT}/\$1 -f [OR]\n";
		printf "\tRewriteCond %%{DOCUMENT_ROOT}/\$1 -d\n";
		printf "\tRewriteCond %%{REQUEST_URI} !=/\n";
		printf "\tRewriteRule (.*) - [L]\n";
		printf "\n";
		printf "\tRewriteCond %%{HTTP:Upgrade} =websocket [NC]\n";
		printf "\tRewriteRule /(.*) ${_ws_url}\$1 [P,L]\n";
		printf "\n";
		printf "\tRewriteCond %%{HTTP:Upgrade} !=websocket [NC]\n";
		printf "\tRewriteRule /(.*) ${_proxy}\$1 [P,L]\n";
		printf "\n";
		printf "\tRewriteRule ^/(.*)$ ${_proxy}\$1 [P,QSA]\n";
		printf "\n";
		printf "\tSSLEngine on\n";
		printf "\tSSLProtocol all -SSLv2\n";
		printf "\tSSLCipherSuite HIGH:MEDIUM:!aNULL:!MD5\n";
		printf "\n";
		printf "\tSSLCertificateKeyFile    /vhosts/${_vhost_name}/certs/key.pem\n";
		printf "\tSSLCertificateFile       /vhosts/${_vhost_name}/certs/cert.pem\n";
		printf "\tSSLCertificateChainFile  /vhosts/${_vhost_name}/certs/chain.pem\n";
		printf "\n";
		printf "\tCustomLog \"|bin/rotatelogs -l /logs/${_vhost_name}.ok.https.%%Y-%%m-%%d.log 86400\" json_format\n";
		printf "\tErrorLog  \"|bin/rotatelogs -l /logs/${_vhost_name}.error.https.%%Y-%%m-%%d.log 86400\"\n";
		printf "\n";
		printf "</VirtualHost>\n";
	fi;

}




