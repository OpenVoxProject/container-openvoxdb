# Migrations

## Image tags: build numbers replace `-main` and `-v<container.version>`

Images built from the `main` branch are now tagged `<openvoxdb.version>-<build>`
(for example `8.18.1-0` and `8.18.1-0-alpine`) instead of
`<openvoxdb.version>-main`. Git tags of this repository no longer publish
`<openvoxdb.version>-v<container.version>` images. See the
[version schema](README.md#version-schema) for how build numbers are assigned.

The old tags still exist, but they are no longer updated, so an image pinned to
one of them stops receiving fixes. Pulling them does not fail or warn. Switch to
one of the current tags:

| Old tag | Use instead |
| --- | --- |
| `<openvoxdb.version>-main` | `<openvoxdb.version>` to follow the latest build, or `<openvoxdb.version>-<build>` to pin one |
| `<openvoxdb.version>-main-alpine` | `<openvoxdb.version>-alpine`, or `<openvoxdb.version>-<build>-alpine` |
| `<openvoxdb.version>-v<container.version>` | `<openvoxdb.version>-<build>` |
| `<openvoxdb.version>-v<container.version>-alpine` | `<openvoxdb.version>-<build>-alpine` |

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
