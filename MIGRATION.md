# Migrations

## `latest` now follows OpenVoxDB 9

Images are built for both OpenVoxDB 8 and 9, and the floating `latest` and
`latest-alpine` tags now point at OpenVoxDB 9 instead of 8.

If you deploy `latest` or `latest-alpine`, your next pull is a major version
upgrade. OpenVoxDB applies its database schema migrations on startup, and
there is no way to roll the schema back, so back up the PostgreSQL database
before you upgrade.

To stay on OpenVoxDB 8, switch to the `8` or `8-alpine` tag, or pin a
specific version such as `8.15.0`.

OpenVoxDB 9 no longer ships `ezbake-functions.sh` or the `puppetdb start` and
`puppetdb stop` subcommands, so the OpenVoxDB 9 images leave them out. If you
build on top of this image, or run scripts from `/container-custom-entrypoint.d/`,
check that they don't rely on any of these.

## Coming from a fixed UID release

The container runs with **group 0** and works under **any UID**.
File access is granted exclusively through group 0, and the UID of files on mounted volumes does not matter.
There is no `puppet` service account in the image anymore.

For existing volumes, run once:

```bash
chgrp -R 0 [PATH TO THE VOLUME]
chmod -R g+rwX [PATH TO THE VOLUME]
```

On Kubernetes/OpenShift using `fsGroup: 0` in the pod securityContext can be used to achieve the same.
