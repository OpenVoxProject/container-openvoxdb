# OpenVox DB container

[![CI](https://github.com/openvoxproject/container-openvoxdb/actions/workflows/ci.yml/badge.svg)](https://github.com/openvoxproject/container-openvoxdb/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/openvoxproject/container-openvoxdb.svg)](https://github.com/openvoxproject/container-openvoxdb/blob/main/LICENSE)
[![Sponsored by betadots GmbH](https://img.shields.io/badge/Sponsored%20by-betadots%20GmbH-blue.svg)](https://www.betadots.de)

---

- [OpenVox DB container](#openvox-db-container)
  - [Informations](#informations)
    - [End of Life for OpenVox DB 7](#end-of-life-for-openvox-db-7)
    - [Migration](#migration)
  - [Version schema](#version-schema)
  - [Permissions](#permissions)
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
| `<openvoxdb.version>-<build>` | `8.18.1-0` | Immutable Ubuntu build |
| `<openvoxdb.version>-<build>-alpine` | `8.18.1-0-alpine` | Immutable Alpine build |
| `<openvoxdb.version>` | `8.18.1` | Latest build for an OpenVoxDB version, using Ubuntu |
| `<openvoxdb.version>-alpine` | `8.18.1-alpine` | Latest Alpine build for an OpenVoxDB version |
| `<openvoxdb.major>` | `8` | Latest build for an OpenVoxDB major version, using Ubuntu |
| `<openvoxdb.major>-alpine` | `8-alpine` | Latest Alpine build for an OpenVoxDB major version |
| `latest` | `latest` | Latest Ubuntu build from the `main` branch |
| `latest-alpine` | `latest-alpine` | Latest Alpine build from the `main` branch |

The OpenVoxDB version describes the database version contained in the image.
The build number identifies each image published for that OpenVoxDB version.
Every time the `main` branch publishes an image, it gets one more than the
highest build number already published, whether or not the OpenVoxDB version
changed: a newer base image or Java package, or a change to the container
scripts, all produce a new build number. A new OpenVoxDB version starts at `0`.
The Ubuntu and Alpine images of the same build share its number. Build numbers
only ever increase, but a publish that fails part-way and is run again from the
start can skip one.

Only the `main` branch publishes the tags above. Git tags and GitHub releases of
this repository do not create build-numbered or floating tags.

Example using an immutable build:

```shell
podman pull ghcr.io/openvoxproject/openvoxdb:8.18.1-0
```

Each build records the commit it was built from in the
`org.opencontainers.image.revision` annotation of its image index:

```shell
skopeo inspect --raw docker://ghcr.io/openvoxproject/openvoxdb:<openvoxdb.version>-<build> | jq -r '.annotations["org.opencontainers.image.revision"]'
```

The `<openvoxdb.version>-v<container.version>` and `<openvoxdb.version>-main`
tags used by earlier builds are no longer updated. See the
[migration document](MIGRATION.md) if you use them.

## Permissions

The image runs with GID 0 and supports any runtime UID.
GID 0 is what allows file access.

Volumes can be adjusted to it via:

```shell
chgrp -R 0 <dir> && chmod -R g+rwX <dir>
```

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

A release tags this repository and updates the changelog. It does not publish
an image: every build of the `main` branch does that, as described under
[Version schema](#version-schema).

## How to contribute

[see here](https://github.com/voxpupuli/crafty/blob/main/CONTRIBUTING.md)
