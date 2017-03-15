#!/usr/bin/env bash

export USER="builder"

# Create user and group that the packages will be built as
groupadd --gid "${GROUP_ID}" "${USER}" && \
useradd -M -N -u "${USER_ID}" -g "${GROUP_ID}" "${USER}" && \
chown "${USER}" .


# Build libvte
/usr/local/bin/libvte.build.sh || exit 1

# Install built dependencies
dpkg -i /usr/local/src/*libvte*.deb

# Build termite
/usr/local/bin/termite.build.sh
