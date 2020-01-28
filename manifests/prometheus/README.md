# Prep
## Create clients for firehose_exporter and cf_exporter
```
PCF_ENV=xxx
bosh -e $PCF_ENV -d cf-CHANGE_ME manifest > /tmp/"$PCF_ENV"-cf.yml
git -C ./pcf-tile-configurator pull && git -C ./pcf-swiss-army/ pull

bosh -e $PCF_ENV -d cf-CHANGE_ME deploy /tmp/"$PCF_ENV"-cf.yml -o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/cf/add-grafana-uaa-clients.yml  -o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/cf/add-prometheus-uaa-clients.yml -l ./pcf-swiss-army/master-params/$PCF_ENV-params.yml --no-redact
```

## Create MySQL user
```
credhub find -n mysql-admin-credentials
credhub get -n /p-bosh/cf-xxxx/mysql-admin-credentials

bosh -e sbx -d cf-........ ssh mysql/0
mysql -h 127.0.0.1 -u root -p

Enter password: (from above)
CREATE USER 'exporter' IDENTIFIED BY 'CHANGE_ME';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter' WITH MAX_USER_CONNECTIONS 3;
credhub set -t user -n /p-bosh/prometheus/mysql_exporter -z exporter -w CHANGE_ME
```

## Create client for bosh_exporter
```
credhub login --client-name=credhubadmin --client-secret=CHANGE_ME -s director.xyz.net:8844 --skip-tls-validation
credhub find -n uaa/admin_client_credentials
uaac target uaa.sys.xyz.net --skip-ssl-validation
uaac token client get admin -s CHANGE_ME
uaac client add bosh_exporter --authorized_grant_types client_credentials,refresh_token --authorities bosh.read --scope bosh.read --secret dXzfEuMQmKMmX5Pa
credhub set -n /uaa_bosh_exporter_client_secret -t password -w dXzfEuMQmKMmX5Pa
```

# Deploy
- If you want to deploy with blackbox exporter run

```
PCF_ENV=xxx
git -C ./pcf-tile-configurator pull && git -C ./pcf-swiss-army/ pull

bosh -e $PCF_ENV -d prometheus deploy ./pcf-tile-configurator/bosh-deployments/prometheus/prometheus.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/enable-cf-route-registrar.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/ldap.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/monitor-cf.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/monitor-bosh.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/monitor-concourse.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/monitor-http-probe.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/monitor-node.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/monitor-p-rabbitmq.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/monitor-mysql.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/alertmanager-smtp-receiver.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/alertmanager-blackhole-receiver.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/enable-anon.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/pcf-colocate-firehose_exporter.yml \
-o ./pcf-tile-configurator/bosh-deployments/prometheus/ops/pcf-local-cf_exporter.yml \
-l ./pcf-swiss-army/master-params/"$PCF_ENV"-params.yml --no-redact
```