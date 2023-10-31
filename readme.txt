docker compose -p log -f search-compose.yaml up elastic -d --build




docker compose -p log -f search-compose.yaml down filebeat-apache ; rm -rf /docker/data/filebeat-apache/registry ; docker compose -p log -f search-compose.yaml up filebeat-apache -d --build





README

Per come l'ho impostato, logstash copia il campo "index_name" che arriva dal beat e lo mette in metadata.target_index
metadata.target_index viene usato come campo dinamico nell'output di elasticsearch, per inserire i dati nell'indice che ha nome metadata.target_index





docker compose -p log -f search-compose.yaml down filebeat-apache ; rm -rf /docker/data/filebeat-apache/registry/filebeat ; chmod -R 777 /docker/data/filebeat-apache/registry/ ; docker compose -p log -f search-compose.yaml up filebeat-apache -d --build