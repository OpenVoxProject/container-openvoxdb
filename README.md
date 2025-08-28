# OpenVox DB container

[![CI](https://github.com/openvoxproject/container-openvoxdb/actions/workflows/ci.yaml/badge.svg)](https://github.com/openvoxproject/container-openvoxdb/actions/workflows/ci.yaml)
[![License](https://img.shields.io/github/license/openvoxproject/container-openvoxdb.svg)](https://github.com/openvoxproject/container-openvoxdb/blob/main/LICENSE)
[![Sponsored by betadots GmbH](https://img.shields.io/badge/Sponsored%20by-betadots%20GmbH-blue.svg)](https://www.betadots.de)

---

- [OpenVox DB container](#openvox-db-container)
  - [Informations](#informations)
    - [End of Life for OpenVox DB 7](#end-of-life-for-openvox-db-7)
  - [Version schema](#version-schema)
  - [Configuration](#configuration)
    - [Cert File Locations](#cert-file-locations)
  - [Initialization Scripts](#initialization-scripts)
  - [How to Release the container](#how-to-release-the-container)
  - [How to contribute](#how-to-contribute)

---
This project hosts the Containerfile and the required scripts to build a OpenVoxDB container image.

For compose file see: [CRAFTY](https://github.com/voxpupuli/crafty/tree/main/puppet/oss)

The OpenVoxDB container requires a working postgres container or other suitably
configured PostgreSQL database. For a Compose example see the [CRAFTY OSS Demo compose.yaml](https://github.com/voxpupuli/crafty/blob/main/puppet/oss/compose.yaml)

You can change configuration settings by mounting volumes containing
configuration files or by using this image as a base image. For the defaults,
see the [Containerfile and supporting folders](https://github.com/openvoxproject/container-openvoxdb/tree/main/openvoxdb).

## Informations

### End of Life for OpenVox DB 7

⚠️ On February 28, 2025, OpenVox/Puppet 7 entered its end-of-life phase.
Consequently, no new OpenVox DB 7 releases will be build.
Existing versions will be retained for continued access.

## Version schema

The version schema has the following layout:

```text
<openvox.major>.<openvox.minor>.<openvox.patch>-v<container.major>.<container.minor>.<container.patch>
```

Example usage:

```shell
podman pull ghcr.io/openvoxproject/openvoxdb:8.9.0-v1.2.3
```

| Name | Description |
| --- | --- |
| openvox.major | Describes the contained major OpenVox version |
| openvox.minor | Describes the contained minor OpenVox version |
| openvox.patch | Describes the contained patchlevel OpenVox version |
| container.major | Describes the major version of the base container (Ubunutu 24.04) or incompatible changes |
| container.minor | Describes new features or refactoring with backward compatibility |
| container.patch | Describes if minor changes or bugfixes have been implemented |

## Configuration

| Name                                  | Usage / Default                                                       |
|---------------------------------------|-----------------------------------------------------------------------|
| **CERTNAME**                          | The DNS name used on this services SSL certificate<br><br>`openvoxdb` |
| **DNS_ALT_NAMES**                     | Additional DNS names to add to the services SSL certificate<br><br>Unset |
| **LOGDIR**                            | Path of the log directory<br><br>`/opt/puppetlabs/server/data/puppetdb/logs` |
| **OPENVOXDB_CERTIFICATE_ALLOWLIST**   | Set to a comma seaprated list of allowed certnames.<br><br>`""` |
| **OPENVOXDB_JAVA_ARGS**               | Arguments passed directly to the JVM when starting the service<br><br>`-Djava.net.preferIPv4Stack=true -Xms256m -Xmx256m -XX:+UseParallelGC -Xlog:gc*:file=$LOGDIR/openvoxdb_gc.log -Djdk.tls.ephemeralDHKeySize=2048` | <!-- markdownlint-disable-line -->
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

### Cert File Locations

The directory structure follows the following conventions.  The full path is always available inside the container as the environment variable `$SSLDIR`

- 'ssl-ca-cert'
  `/opt/puppetlabs/server/data/puppetdb/certs/certs/ca.pem`

- 'ssl-cert'
  `/opt/puppetlabs/server/data/puppetdb/certs/certs/<certname>.pem`

- 'ssl-key'
  `/opt/puppetlabs/server/data/puppetdb/certs/private_keys/<certname>.pem`

## Initialization Scripts

If you would like to do additional initialization, add a directory called `/container-custom-entrypoint.d/` and fill it with `.sh` scripts.
These scripts will be executed at the end of the entrypoint script, before the service is ran.

## How to Release the container

[see here](RELEASE.md)

## How to contribute

[see here](https://github.com/voxpupuli/crafty/blob/main/CONTRIBUTING.md)
