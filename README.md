# HSH

## Overview
HSH (acronimo di Home Sweet Home) nasce per motivi personali, tuttavia è pubblicato qui sia per godere del versionamento (grazie GitHub ❤️) sia per condividerlo e avere opinioni in merito

Lo scopo del progetto è di avere uno stack applicativo in esecuzione su docker che aiuti con la gestione e monitoraggio della propria smart home, anzi dato che il progetto è personale, della mia smart home.

La domotica sarà interamente gestita con Home Assistant e le sue infinite integrazioni e funzionalità disponibili.

L'intero stack sarà eseguito su una rete dedicata di docker, pertanto è necessario che il router possa gestire il traffico da e verso una determinata VLAN (nel progetto viene usata una 10.10.80.0/24).

Nel caso in cui si voglia utilizzare questo progetto, è essenziale sapere che alcuni protocolli usati dai dispositivi Smart per il riconoscimento all'interno di una LAN (mDNS, SSDP), prevedono che tutti i dispositivi siano attestati sulla stessa vLAN

Tuttavia con un buon router, questo scoglio è superabile, ma l'argomento non sarà trattato qui

E no, i Fritzbox non sono ottimi router per questo scopo.

## Stack applicativo

Di seguito la lista dei container che vengono utilizzati

- [Home Assistant](https://www.home-assistant.io/) Per la gestione di tutti i dispositivi smart, assistente vocale, etc.
- [MQTT Broker](https://mqtt.org/) Message Broker per dispositivi IoT
- [Elastic Search](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html) Utilizzato con indici Data Stream per le metriche dei sensori (2 nodi, hot-data e cold-data)
- [Kibana](https://www.elastic.co/guide/en/kibana/8.10/index.html) Per la gestione dei nodi elasticsearch
- [Logstash](https://www.elastic.co/guide/en/logstash/current/index.html) Per ricevere eventi dai beat, filtrare e/o trasformare i dati, inviare gli eventi ad elastic search 
- [Beat](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-overview.html) ([FILE](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-input-filestream.html), [MQTT](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-input-mqtt.html)) MQTT per inviare gli eventi che passano sul broker ad elasticsearch, FILE per i file di log di apache
- [Grafana](https://grafana.com/docs/grafana/latest/?pg=oss-graf&plcmt=hero-btn-2) Per l'implementazione di dashboard di monitoraggio
- [Apache](https://httpd.apache.org/) Usato come reverse proxy per esporre Home Assistant su Internet
- [Acme.sh](https://github.com/acmesh-official/acme.sh) Per la generazione e auto rinnovo di certificati TLS con Let's Encrypt
- [MySQL](https://dev.mysql.com/doc/refman/8.0/en/) Attualmente in sostituzione di SQLite usato da Home Assistant

### Implementazioni future
- [Zigbee2mqtt](https://www.zigbee2mqtt.io/guide/getting-started/) per i dispositivi Smart basati su protocollo Wireless ZigBee


## Architettura di rete e dispositivi

- [Ubiquiti Dream Machine SE](https://eu.store.ui.com/eu/en/pro/category/all-unifi-cloud-gateways/products/udm-se) Cuore della gestione della rete, dispositivi PoE, distribuzione vLAN, reti Wireless
- [Switch 24 port PoE](https://eu.store.ui.com/eu/en/pro/category/all-switching/products/usw-24-poe) Switch PoE (ho 16 porte ethernet a casa)
- [2x U6+ Access point](https://eu.store.ui.com/eu/en/pro/category/all-wifi/products/u6-plus) Access point per distribuire il wifi in casa
- [Mini PC Intel 12a Gen. Alder 3,4 GHz 16 GB RAM/512 GB SSD M.2](https://www.amazon.it/gp/product/B0CJV3DDGT) Mini Pc con docker ed il progetto in esecuzione 
- [Shelly 1PM](https://shelly-api-docs.shelly.cloud/gen1/#shelly1-shelly1pm) Relè Smart per gestione di un singolo carico (luce, presa)
- [Shelly 2.5PM](https://shelly-api-docs.shelly.cloud/gen2/Devices/ShellyPlus2PM) Relè smart per gestione di due carichi (luci, prese) o per gestione tapparella
- [Google Nest Hub](https://store.google.com/it/product/nest_hub_2nd_gen?hl=it&pli=1) Per visualizzazione dashboard lovelace di Home Assistant, normale utilizzo, acquisizione comandi vocali per gestione domotica
- [Google Nest Mini](https://store.google.com/it/product/google_nest_mini?hl=it) Per notifiche, normale utilizzo, acquisizione comandi vocali per gestione domotica

### Dispositivi futuri
- Chromecast, Telecamere, Smart TV, sensori temperatura/umidità/luminosità, etc.

## Installazione
### Prerequisiti

- Docker
- Utenza di root

### Procedura
Eseguire il seguente comando, prerequisito importante per i container elastic
```
sysctl -w vm.max_map_count=262144
```
Clonare il repository
```
git clone https://github.com/esposimo/hsh-docker/
```
[Configurare le variabili nel file environment](https://github.com/esposimo/hsh-docker/edit/master/README.md#environment-file)

Eseguire lo script di installazione 
```
./run.sh
```

## environment file


```bash
# IP & Port Section
# Tutti gli ip dovranno rientrare nella subnet 10.10.80.0/24

# Ip del nodo master di elastic search
IP_ADDRESS_ELASTIC_DATA=<elastic-master-node-ip>

# Ip del nodo elastic che contiene i tier cold/warm
IP_ADDRESS_ELASTIC_COLD=<elastic-cold-node-ip>

# Ip del container kibana
IP_ADDRESS_KIBANA=<kibana-ip>

# Porta esposta dall'host docker per il nodo master di elastic
EXPOSE_PORT_ELASTIC_DATA=<elastic-master-expose-port>

# Porta esposta dall'host docker per il nodo cold/warm di elastic
EXPOSE_PORT_ELASTIC_COLD=<elastic-cold-espose-port>

# Porta esposta dall'host docker per l'istanza di kibana
EXPOSE_PORT_KIBANA=<kibana-port>






# CONTAINER Section

# Nome del container Elastic Master
CONTAINER_NAME_ELASTIC_DATA=<elastic-master-container-name>

# Nome del container Elastic cold/warm
CONTAINER_NAME_ELASTIC_COLD=<elastic-cold-container-name>

# Nome del container di kibana
CONTAINER_NAME_KIBANA=<kibana-container-name>
```
