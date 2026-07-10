# OpenVox DB container

[![CI](https://github.com/openvoxproject/container-openvoxdb/actions/workflows/ci.yaml/badge.svg)](https://github.com/openvoxproject/container-openvoxdb/actions/workflows/ci.yaml)
[![License](https://img.shields.io/github/license/openvoxproject/container-openvoxdb.svg)](https://github.com/openvoxproject/container-openvoxdb/blob/main/LICENSE)
[![Sponsored by betadots GmbH](https://img.shields.io/badge/Sponsored%20by-betadots%20GmbH-blue.svg)](https://www.betadots.de)

---

- [OpenVox DB container](#openvox-db-container)
  - [Informations](#informations)
    - [End of Life for OpenVox DB 7](#end-of-life-for-openvox-db-7)
    - [Migration](#migration)
  - [Version schema](#version-schema)
  - [Configuration](#configuration)
    - [Cert File Locations](#cert-file-locations)
  - [Initialization Scripts](#initialization-scripts)
  - [How to Release the container](#how-to-release-the-container)
  - [How to contribute](#how-to-contribute)

---

This project hosts the Containerfile and the required scripts to build a OpenVoxDB container image.

For compose file see: [CRAFTY](https://github.com/voxpupuli/crafty/tree/main/openvox/oss/)

The OpenVoxDB container requires a working postgres container or other suitably
configured PostgreSQL database. For a Compose example see the [CRAFTY OSS Demo compose.yaml](https://github.com/voxpupuli/crafty/blob/main/openvox/oss/compose.yaml)

You can change configuration settings by mounting volumes containing
configuration files or by using this image as a base image. For the defaults,
see the [Containerfiles and supporting folders](https://github.com/openvoxproject/container-openvoxdb).

## Informations

### End of Life for OpenVox DB 7

⚠️ On February 28, 2025, OpenVox/Puppet 7 entered its end-of-life phase.
Consequently, no new OpenVox DB 7 releases will be build.
Existing versions will be retained for continued access.

### Migration

Before updating to a newer version of your container, you should check the [migration document](MIGRATION.md)

## Version schema

Images are published to `ghcr.io/openvoxproject/openvoxdb` and
`docker.io/voxpupuli/openvoxdb`. Ubuntu is the default image variant and
therefore has no operating system suffix. Alpine images use the `-alpine`
suffix.

| Tag | Example | Description |
| --- | --- | --- |
| `<openvoxdb.version>-v<container.version>` | `8.13.0-v1.2.3` | Immutable Ubuntu container release |
| `<openvoxdb.version>-v<container.version>-alpine` | `8.13.0-v1.2.3-alpine` | Immutable Alpine container release |
| `<openvoxdb.version>` | `8.13.0` | Latest build for an OpenVoxDB version, using Ubuntu |
| `<openvoxdb.version>-alpine` | `8.13.0-alpine` | Latest Alpine build for an OpenVoxDB version |
| `<openvoxdb.major>` | `8` | Latest build for an OpenVoxDB major version, using Ubuntu |
| `<openvoxdb.major>-alpine` | `8-alpine` | Latest Alpine build for an OpenVoxDB major version |
| `latest` | `latest` | Latest Ubuntu build from the `main` branch |
| `latest-alpine` | `latest-alpine` | Latest Alpine build from the `main` branch |

Builds from the `main` branch are additionally tagged as
`<openvoxdb.version>-main` and `<openvoxdb.version>-main-alpine`.

Example using an immutable container release:

```shell
podman pull ghcr.io/openvoxproject/openvoxdb:8.13.0-v1.2.3
```

The OpenVoxDB version describes the database version contained in the image.
The container version follows semantic versioning and describes changes to the
container image independently of the OpenVoxDB version.

## Configuration

<!-- markdownlint-disable table-column-style -->
<!-- markdownlint-disable line-length -->
| Name                                  | Usage / Default |
| ------------------------------------- | --------------- |
| **CERTNAME**                          | The DNS name used on this services SSL certificate<br><br>`openvoxdb` |
| **DNS_ALT_NAMES**                     | Additional DNS names to add to the services SSL certificate<br><br>Unset |
| **LOGDIR**                            | Path of the log directory<br><br>`/opt/puppetlabs/server/data/puppetdb/logs` |
| **OPENVOXDB_CERTIFICATE_ALLOWLIST**   | Set to a comma seaprated list of allowed certnames.<br><br>`""` |
| **OPENVOXDB_JAVA_ARGS**               | Arguments passed directly to the JVM when starting the service<br><br>`-Djava.net.preferIPv4Stack=true -Xms256m -Xmx256m -XX:+UseParallelGC -Xlog:gc*:file=$LOGDIR/openvoxdb_gc.log -Djdk.tls.ephemeralDHKeySize=2048` |
| **OPENVOXDB_NODE_PURGE_TTL**          | Automatically delete nodes that have been deactivated or expired for the specified amount of time<br><br>`14d` |
| **OPENVOXDB_NODE_TTL**                | Mark as ‘expired’ nodes that haven’t seen any activity (no new catalogs, facts, or reports) in the specified amount of time<br><br>`7d` |
| **OPENVOXDB_POSTGRES_DATABASE**       | The name of the openvoxdb database in postgres<br><br>`openvoxdb` |
| **OPENVOXDB_POSTGRES_HOSTNAME**       | The DNS hostname of the postgres service<br><br>`postgres` |
| **OPENVOXDB_POSTGRES_PASSWORD**       | The openvoxdb database password<br><br>`openvoxdb` |
| **OPENVOXDB_POSTGRES_PORT**           | The port for postgres<br><br>`5432` |
| **OPENVOXDB_POSTGRES_USER**           | The openvoxdb database user<br><br>`openvoxdb` |
| **OPENVOXDB_REPORT_TTL**              | Automatically delete reports that are older than the specified amount of time<br><br>`14d` |
| **OPENVOXDB_WAITFORHEALTH_SECONDS**   | Number of seconds to wait for OpenVoxDB to be healthy<br><br>`360` |
| **OPENVOXDB_WAITFORHOST_SECONDS**     | Number of seconds to wait for OpenVoxDB to be available<br><br>`30` |
| **OPENVOXDB_WAITFORPOSTGRES_SECONDS** | Number of seconds to wait for postgres to be available<br><br>`60` |
| **OPENVOXSERVER_HOSTNAME**            | The DNS hostname of the OpenVox server<br><br>`puppet` |
| **OPENVOXSERVER_PORT**                | The port of the OpenVox server<br><br>`8140` |
| **SSLDIR**                            | Path of the SSL directory<br><br>`/opt/puppetlabs/server/data/puppetdb/certs` |
| **USE_OPENVOXSERVER**                 | Set to `false` to skip acquiring SSL certificates from a OpenVox Server.<br><br>`true` |
| **WAITFORCERT**                       | Number of seconds to wait for certificate to be signed<br><br>`120` |
<!-- markdownlint-enable line-length -->
<!-- markdownlint-enable table-column-style -->

### Cert File Locations

The directory structure follows the following conventions. The full path is always available inside the container as the environment variable `$SSLDIR`

- 'ssl-ca-cert'
  `/opt/puppetlabs/server/data/puppetdb/certs/certs/ca.pem`

- 'ssl-cert'
  `/opt/puppetlabs/server/data/puppetdb/certs/certs/<certname>.pem`

- 'ssl-key'
  `/opt/puppetlabs/server/data/puppetdb/certs/private_keys/<certname>.pem`

## Initialization Scripts

If you would like to do additional initialization, add a directory called `/container-custom-entrypoint.d/` and fill it with `.sh` scripts.
These scripts will be executed at the end of the entrypoint script, before the service is run.

## How to Release the container

[see here](RELEASE.md)

## How to contribute

[see here](https://github.com/voxpupuli/crafty/blob/main/CONTRIBUTING.md)
