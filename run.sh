#!/bin/sh

LOCAL_IP=$(ip route get 1.2.3.4 | awk '{print $7}' | grep -v ^$)
cat environment > .env
echo "" >> .env
echo "LOCAL_IP=${LOCAL_IP}" >> .env


printf "Prepare certs for kibana ";
openssl req -x509 -newkey rsa:4096 -keyout ./kibana/kibana.key -out ./kibana/kibana.crt -sha256 -days 3650 -nodes -subj "/C=IT/ST=Italy/L=Naples/O=HSH/OU=HSH-IT/CN=${LOCAL_IP}" 2>/dev/null
printf "\n";

docker-compose -f search-compose.yaml down 
docker-compose -f search-compose.yaml up -d --build elastic_master kibana


OK_ELASTIC=2
printf "Provo a generare la password dell'utente elastic ";
while [ ${OK_ELASTIC} != 0 ] ; do
	ELASTIC_PASSWORD=$(docker exec -it elastic_master /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s 2>/dev/null)
	OK_ELASTIC=$?
	printf ".";
done;

printf " elastic / ${ELASTIC_PASSWORD}\n";

echo "ELASTIC_PASSWORD=${ELASTIC_PASSWORD}" >> .env

printf "Create enrollment token for kibana .. ";

KIBANA_ENROLLMENT=$(docker exec -it elastic_master /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana 2>/dev/null)

echo "KIBANA_ENROLLMENT=${KIBANA_ENROLLMENT}" >> .env

printf "${KIBANA_ENROLLMENT}\n";
printf "Auto setting enrollment token on kibana .. "
docker exec -it kibana /usr/share/kibana/bin/kibana-setup -t ${KIBANA_ENROLLMENT} 2>&1 >/dev/null;
printf "ok\n";
printf "Restart kibana\n";
docker restart kibana >/dev/null

printf "Create a enrollment token for new nodes to joins .. "

ELASTIC_NODE_ENROLL=$(docker exec -it elastic_master /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s node 2>/dev/null)

echo "ELASTIC_NODE_ENROLL=${ELASTIC_NODE_ENROLL}" >> .env

printf "${ELASTIC_NODE_ENROLL}\n";

printf "Starting elastic cold instance and join to cluster\n";
docker-compose -f search-compose.yaml up -d --build elastic_cold




. ./.env

printf "#################### INFO ####################\n";
printf "Elastic Master Node URL\t: https://${LOCAL_IP}:${EXPOSE_PORT_ELASTIC_DATA} or https://${IP_ADDRESS_ELASTIC_DATA}:9200\n";
printf "Elastic Cold Node URL\t: https://${LOCAL_IP}:${EXPOSE_PORT_ELASTIC_COLD} or https://${IP_ADDRESS_ELASTIC_COLD}:9200\n";
printf "Kibana and Elastic User\t: elastic\n";
printf "Kibana and Elastic PWD\t: ${ELASTIC_PASSWORD}\n";
printf "Kibana URL\t\t: http://${LOCAL_IP}:${EXPOSE_PORT_KIBANA} or http://${IP_ADDRESS_KIBANA}:5601\n";
printf "Enrollment token for kibana\t: ${KIBANA_ENROLLMENT}\n";
printf "Enrollment token for Cold node\t: ${ELASTIC_NODE_ENROLL}\n";





# docker exec -it elastic_master elasticsearch-create-enrollment-token -s node
# docker exec -it elastic_cold elasticsearch --enrollment-token eyJ2ZXIiOiI4LjEwLjIiLCJhZHIiOlsiMTAuMTAuODAuMjE2OjkyMDAiXSwiZmdyIjoiMGNmODUwYTFhYTBhY2EzNzUxYTNlMjI4OWZiMDZmZTAwY2I1OGYzYTliNWE5ZTdhNTc4ZjdmMjE0YjdhODFkNSIsImtleSI6ImxDWEdob3NCcnkzd1VPQW5RdFR4OmNWZ0FYMFJtUzBHVFN6U0N4UTBKX2cifQ==

# echo discovery.seed_hosts: >> elasticsearch.yml
# echo "   - 10.10.80.217:9201"
#   - 192.168.1.11 
#   - seeds.mydomain.com 
#   - [0:0:0:0:0:ffff:c0a8:10c]:9301
# discovery.zen.ping.unicast.hosts: ["10.10.80.216", "10.10.80.217"]











