#!/bin/bash
PACKAGE="libvte"
DEBEMAIL="github@mgor.se"
DEBFULLNAME="docker-ubuntu-${PACKAGE}-builder"
DEBCOPYRIGHT="debian/copyright"
URL="https://github.com/thestinger/vte-ng"
DISTRO="$(lsb_release -sc)"

export DISTRO URL USER DEBCOPYRIGHT DEBFULLNAME DEBEMAIL PACKAGE

run() {
    sudo -Eu "${USER}" -H "${@}"
}

run git clone "${URL}.git" "${PACKAGE}" && \
cd "${PACKAGE}" || exit

VERSION="$(git branch | awk '{print $NF}')-$(git rev-parse --short HEAD)"
export VERSION

run ./autogen.sh

PACKAGE="${PACKAGE}-$(awk '/^VTE_API_VERSION/ {print $NF; exit}' Makefile)-0"

run dh_make -p "${PACKAGE}_${VERSION}" -s -y --createorig

rm -rf debian/patches &>/dev/null && mv /tmp/patches debian/ && chown -R "${USER}:${USER}" debian/patches

for patch in debian/patches/*.patch; do
    basename "${patch}" | sudo -Eu "${USER}" -H tee -a debian/patches/series
done

# Create overrides for lintian
sudo -Eu "${USER}" -H tee "debian/${PACKAGE}.lintian-overrides" >/dev/null <<EOF
${PACKAGE} binary: binary-without-manpage *
${PACKAGE} binary: non-dev-pkg-with-shlib-symlink *
EOF

# Fix debian/copyright
COPYRIGHT_YEAR="$(date +%Y)"
COPYRIGHT_OWNER="$(head -1 AUTHORS)"
export COPYRIGHT_YEAR COPYRIGHT_OWNER

{ echo ""; awk '/Files: debian/,/^$/' "${DEBCOPYRIGHT}"; } | sudo -Eu "${USER}" -H tee "${DEBCOPYRIGHT}.template" >/dev/null
sudo -Eu "${USER}" -H tee "${DEBCOPYRIGHT}" >/dev/null <<EOF

Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ${PACKAGE}
Source: $(git config remote.origin.url)

Files: *
Copyright: ${COPYRIGHT_YEAR} ${COPYRIGHT_OWNER}
License: LGPL-2.1
EOF

#shellcheck disable=SC2002
cat "${DEBCOPYRIGHT}.template" | sudo -Eu "${USER}" -H tee -a "${DEBCOPYRIGHT}" >/dev/null && rm -rf "${DEBCOPYRIGHT}.template"

# Fix debian/changelog
run rm -rf debian/changelog
run dch -D "${DISTRO}" --create --package "${PACKAGE}" --newversion "${VERSION}" "Automagically built in docker"

# Fix debian/control
DESCRIPTION="$(echo "Vte is mainly used in gnome-terminal, but can also be used to embed a console/terminal in games, editors, IDEs, etc." | fold -s -w 60 | sed -r 's|^[\ \t]*||g; s|^(.)| \1|')"
SHORT_DESCRIPTION="$(awk '/^VTE/ {gsub(/,$/, ".", $0); print $0; exit}' README)"
export DESCRIPTION SHORT_DESCRIPTION

run sed -i '/^#/d' debian/control
run sed -r -i "s|^(Section:).*|\1 x11|" debian/control
run sed -r -i "s|^(Homepage:).*|\1 ${URL}|" debian/control
run sed -r -i "s|^(Architecture:).*|\1 $(dpkg --print-architecture)|" debian/control
run sed -r -i "s|^(Description:).*|\1 ${SHORT_DESCRIPTION}|" debian/control
run sed -i '$ d' debian/control
echo -e "${DESCRIPTION}\n" | sudo -u "${USER}" tee -a debian/control >/dev/null

sudo -Eu "${USER}" tee -a debian/control >/dev/null <<EOF
Package: ${PACKAGE}-dev
Architecture: $(dpkg-architecture -qDEB_BUILD_ARCH)
Section: libdevel
Depends: \${shlibs:Depends}, ${PACKAGE}, \${misc:Depends}
Description: ${SHORT_DESCRIPTION}
EOF
echo -e "${DESCRIPTION}\n" | sudo -u "${USER}" tee -a debian/control >/dev/null

sudo -Eu "${USER}" tee -a debian/control >/dev/null <<EOF
Package: gir1.2-${PACKAGE}
Architecture: $(dpkg-architecture -qDEB_BUILD_ARCH)
Depends: \${shlibs:Depends}, ${PACKAGE}, \${misc:Depends}
Description: ${SHORT_DESCRIPTION}
EOF
echo "${DESCRIPTION}" | sudo -u "${USER}" tee -a debian/control >/dev/null

# Fix install files
sudo -Eu "${USER}" tee -a "debian/${PACKAGE}.install" >/dev/null <<EOF
/etc/profile.d/
/usr/bin/
/usr/lib/x86_64-linux-gnu/*.so*
/usr/lib/x86_64-linux-gnu/*.a
/usr/share/locale/
EOF

sudo -Eu "${USER}" tee -a "debian/${PACKAGE}-dev.install" >/dev/null <<EOF
/usr/include/
/usr/lib/x86_64-linux-gnu/pkgconfig/
EOF

sudo -Eu "${USER}" tee -a "debian/gir1.2-${PACKAGE}.install" >/dev/null <<EOF
/usr/share/gir-1.0/
/usr/lib/x86_64-linux-gnu/girepository-1.0/
/usr/share/vala/
EOF

# Fix README
run rm -rf debian/README.Debian
run cp README debian/README.source

if run debuild -i -us -uc -b
then
    cd ../ || exit 1
    rm -rf libvte/
    find . -type f -not -name "*.deb" -delete
else
    echo "Build failed!"
fi

exit
