# TBMQ PE Docker Compose

Scripts and Docker Compose configurations to run [TBMQ](https://tbmq.io) Professional Edition.

Two deployment options are available:

| Folder                 | Deployment                | Description                                                                                                                          |
|------------------------|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| [basic](basic)         | Single node               | One TBMQ node with the Integration Executor, PostgreSQL, Kafka and Valkey. Suitable for evaluation and small installations.             |
| [cluster](cluster)     | Cluster                   | Two TBMQ nodes and two Integration Executors behind HAProxy, with PostgreSQL, Kafka and a configurable Valkey (standalone/sentinel/cluster). |

## Prerequisites

- [Docker](https://docs.docker.com/install/) with the Docker Compose plugin (V2 is used when available, V1 is still supported by the scripts).
- A TBMQ PE license key. See [License](https://tbmq.io/docs/pe/license/) and set it before the installation:
    - basic: `TBMQ_LICENSE_SECRET` in [basic/docker-compose.yml](basic/docker-compose.yml);
    - cluster: `TBMQ_LICENSE_SECRET` in [cluster/tbmq.env](cluster/tbmq.env).

## Basic deployment

```bash
cd basic
./tbmq-install-and-run.sh
```

The script downloads `docker-compose.yml` if it is absent, creates the required Docker volumes, starts the services and
follows the logs. Windows users should run [basic/windows/tbmq-install-and-run.ps1](basic/windows/tbmq-install-and-run.ps1) instead.

Exposed ports: `8083` (web UI), `1883` (MQTT), `8084` (MQTT over WebSocket).

To upgrade to a newer version run `./tbmq-upgrade.sh` (or `windows/tbmq-upgrade.ps1`). The same script performs the
CE to PE upgrade, in which case a `.tbmq-upgrade.env` file with `JAVA_TOOL_OPTIONS=-Dinstall.upgrade.from_version=ce` must
be created in the `basic` folder beforehand.

Backup and restore instructions: [basic/README.md](basic/README.md).

## Cluster deployment

```bash
cd cluster
./scripts/docker-create-volumes.sh
./scripts/docker-install-tbmq.sh
./scripts/docker-start-services.sh
```

See [cluster/README.md](cluster/README.md) for the full list of scripts, config refresh and upgrade instructions, and
[cluster/backup-restore/README.md](cluster/backup-restore/README.md) for backup and restore.

Exposed ports (HAProxy): `80`/`443` (web UI), `1883`/`8883` (MQTT, MQTTS), `8084`/`8085` (MQTT over WS, WSS).

### Configuration

| File                                                                                 | Purpose                                                          |
|--------------------------------------------------------------------------------------|------------------------------------------------------------------|
| [cluster/.env](cluster/.env)                                                           | Image repository, `TBMQ_VERSION`, container names, `CACHE` type, `JAVA_OPTS` |
| [cluster/tbmq.env](cluster/tbmq.env)                                                   | TBMQ node configuration: datasource, Kafka, MQTT security, license |
| [cluster/tbmq-integration-executor.env](cluster/tbmq-integration-executor.env)         | Integration Executor configuration                                |
| [cluster/kafka.env](cluster/kafka.env)                                                 | Kafka configuration                                               |
| [cluster/cache-valkey*.env](cluster)                                                   | Cache connection settings per `CACHE` type                        |
| [cluster/haproxy/config/haproxy.cfg](cluster/haproxy/config/haproxy.cfg)                | Load balancer configuration                                       |
| [cluster/tbmq/conf](cluster/tbmq/conf), [cluster/tbmq-integration-executor/conf](cluster/tbmq-integration-executor/conf) | Logging and JVM configs applied with `./scripts/docker-refresh-config.sh` |

The `CACHE` variable in [cluster/.env](cluster/.env) selects the Valkey topology and the corresponding compose file from
[cluster/cache](cluster/cache):

- `valkey` (default) — standalone;
- `valkey-sentinel` — primary, replica and sentinel;
- `valkey-cluster` — six nodes, the cluster is formed automatically during the installation.

## Login

Once the services are up, open `http://{your-host-ip}:8083` (basic) or `http://{your-host-ip}` (cluster) in your browser
and sign in with the default system administrator credentials:

- login: `sysadmin@thingsboard.org`
- password: `sysadmin`

## Documentation

- [Docker installation](https://tbmq.io/docs/pe/installation/docker/)
- [Docker installation on Windows](https://tbmq.io/docs/pe/installation/docker-windows/)
- [Cluster setup with Docker Compose](https://tbmq.io/docs/pe/installation/cluster/docker-compose-setup/)
- [Configuration](https://tbmq.io/docs/pe/installation/config/)
- [Upgrade instructions](https://tbmq.io/docs/pe/installation/upgrade-instructions/)

## License

This project is licensed under the [Apache License, Version 2.0](LICENSE).
