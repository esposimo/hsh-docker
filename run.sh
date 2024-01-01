#!/bin/bash



# metto l'ip dell'interfaccia pubblica nel file delle variabili
# se il server ha più interfacce, modificare questa linea di codice
LOCAL_IP=$(ip route get 1.2.3.4 | awk '{print $7}' | grep -v ^$)
#LOCAL_IP=override
sed -i "s/LOCAL_IP=.*/LOCAL_IP=${LOCAL_IP}/g" variables 


#docker-compose -f hsh.yaml --env-file variables down

printf "Prepare certs for kibana ";
openssl req -x509 -newkey rsa:4096 -keyout kibana.key -out kibana.crt -sha256 -days 3650 -nodes -subj "/C=IT/ST=Italy/L=Naples/O=HSH/OU=HSH-IT/CN=${LOCAL_IP}" 2>/dev/null
printf "\n";

docker-compose -f hsh.yaml -p hsh --env-file variables down --rmi local
docker-compose -f hsh.yaml -p hsh --env-file variables up -d --build elastic_master kibana

OK_ELASTIC=2
printf "Provo a generare la password dell'utente elastic ";
while [ ${OK_ELASTIC} != 0 ] ; do
	ELASTIC_PASSWORD=$(docker exec -it elastic_master /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s 2>/dev/null)
	OK_ELASTIC=$?
	printf ".";
done;
sed -i "s/ELASTIC_PASSWORD=.*/ELASTIC_PASSWORD=${ELASTIC_PASSWORD}/g" variables 
printf "\n";

printf "Create enrollment token for kibana .. ";

KIBANA_ENROLLMENT=$(docker exec -it elastic_master /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana 2>/dev/null)

sed -i "s/KIBANA_ENROLLMENT=.*/KIBANA_ENROLLMENT=${KIBANA_ENROLLMENT}/g" variables 

printf "${KIBANA_ENROLLMENT}\n";
printf "Auto setting enrollment token on kibana .. "
docker exec -it kibana /usr/share/kibana/bin/kibana-setup -t ${KIBANA_ENROLLMENT} 2>&1 >/dev/null;
printf "ok\n";
printf "Restart kibana\n";
docker restart kibana >/dev/null


printf "Create a enrollment token for new nodes to joins .. "

ELASTIC_NODE_ENROLL=$(docker exec -it elastic_master /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s node 2>/dev/null)

sed -i "s/ELASTIC_NODE_ENROLL=.*/ELASTIC_NODE_ENROLL=${ELASTIC_NODE_ENROLL}/g" variables 
printf "Starting elastic cold instance and join to cluster\n";
docker-compose -f hsh.yaml -p hsh --env-file variables up -d --build elastic_cold



_IP=$(grep -oP 'IP_ADDRESS_ELASTIC_DATA=\K([0-9\.])+' variables)

printf "Create ILM policy\n";
#AUTH=$(echo -n "elastic:${ELASTIC_PASSWORD%%[[:cntrl:]]}" | base64)
#curl -k https://10.10.84.10:9200/_ilm/policy/hsh_policy -XPUT -H "Content-Type: application/json" \
#-H "Authorization: Basic ${AUTH}" --data-binary @hsh_policy.json

curl -k https://${_IP}:9200/_ilm/policy/hsh_policy -XPUT -H "Content-Type: application/json" \
-u elastic:${ELASTIC_PASSWORD%%[[:cntrl:]]} --data-binary @elastic/hsh_policy.json

curl -k https://${_IP}:9200/_component_template/hsh_component -XPUT -H "Content-Type: application/json" \
-u elastic:${ELASTIC_PASSWORD%%[[:cntrl:]]} --data-binary @elastic/hsh_component.json

curl -k https://${_IP}:9200/_index_template/power_consume -XPUT -H "Content-Type: application/json" \
-u elastic:${ELASTIC_PASSWORD%%[[:cntrl:]]} --data-binary @elastic/hsh_power.json

curl -k https://${_IP}:9200/_data_stream/hsh_metrics_power -XPUT -H "Content-Type: application/json" \
-u elastic:${ELASTIC_PASSWORD%%[[:cntrl:]]}

curl -k https://${_IP}:9200/_data_stream/hsh_metrics_log_fe -XPUT -H "Content-Type: application/json" \
-u elastic:${ELASTIC_PASSWORD%%[[:cntrl:]]}

docker-compose -f hsh.yaml -p hsh --env-file variables up -d --build npm homer bitwarden




printf "\nKibana console: https://${LOCAL_IP}:5601\n";
printf "username: elastic\n";
printf "password: ${ELASTIC_PASSWORD}\n";

