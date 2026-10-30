#!/bin/bash
# Ensure the log directory exists at runtime.
#
# The Containerfile creates $LOGDIR during the image build, but when a
# PersistentVolumeClaim (PVC) is mounted at the parent path
# /opt/puppetlabs/server/data/puppetdb/ (common in Kubernetes), the mount
# overlays the entire directory with an empty volume — erasing the logs/
# subdirectory that was created at build time.
#
# Without this, the JVM fails fatally on startup:
#   Error opening log file '$LOGDIR/puppetdb_gc.log': No such file or directory
#   Error: Could not create the Java Virtual Machine.

mkdir -p "${LOGDIR}"
chown puppetdb:puppetdb "${LOGDIR}"
