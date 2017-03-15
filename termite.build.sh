#!/bin/bash
PACKAGE="termite"
DEBEMAIL="github@mgor.se"
DEBFULLNAME="docker-ubuntu-${PACKAGE}-builder"
DEBCOPYRIGHT="debian/copyright"
URL="https://github.com/thestinger/termite"
DISTRO="$(lsb_release -sc)"

export DISTRO URL USER DEBCOPYRIGHT DEBFULLNAME DEBEMAIL PACKAGE

run() {
    sudo -Eu "${USER}" -H "${@}"
}

run git clone --recursive "${URL}.git" "${PACKAGE}" && \
cd "${PACKAGE}" || exit


VERSION="$(git describe --tags | sed -r 's/^v//')"
export VERSION

run dh_make -p "${PACKAGE}_${VERSION}" -s -y --createorig

# Patch Makefile
run sed -ri 's|(rm termite)$|\1 \|\| true|' Makefile
run sed -ri 's|^(PREFIX = /usr)/local|\1|' Makefile

# Create symbolic links
sudo -Eu "${USER}" -H tee "debian/${PACKAGE}.links" <<EOF
/usr/share/terminfo/x/xterm-termite /lib/terminfo/x/xterm-termite
EOF

# Fix debian/copyright
COPYRIGHT_YEAR="$(git --no-pager log | awk '/^Date/ {year=$(NF-1)} END{print year}')"
COPYRIGHT_OWNER="$(git config remote.origin.url | awk -F/ '{print $(NF-1)}')"
export COPYRIGHT_YEAR COPYRIGHT_OWNER

{ echo ""; awk '/Files: debian/,/^$/' "${DEBCOPYRIGHT}"; } | sudo -Eu "${USER}" -H tee "${DEBCOPYRIGHT}.template" >/dev/null
sudo -Eu "${USER}" -H tee "${DEBCOPYRIGHT}" >/dev/null <<EOF

Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ${PACKAGE}
Source: $(git config remote.origin.url)

Files: *
Copyright: ${COPYRIGHT_YEAR} ${COPYRIGHT_OWNER}
License: Custom
EOF

#shellcheck disable=SC2002
cat "${DEBCOPYRIGHT}.template" | sudo -Eu "${USER}" -H tee -a "${DEBCOPYRIGHT}" >/dev/null && rm -rf "${DEBCOPYRIGHT}.template"

# Fix debian/changelog
run rm -rf debian/changelog
run dch -D "${DISTRO}" --create --package "${PACKAGE}" --newversion "${VERSION}" "Automagically built in docker"

# Fix debian/control
SHORT_DESCRIPTION="$(awk -F, '{gsub(/^A k/, "K", $1); print $1"."; exit}' README.rst)"
DESCRIPTION="$(head -2 README.rst | sed -r "s|.*${SHORT_DESCRIPTION}.*, a|A|i; N;s/\n/ /" | fold -s -w 60 | sed -r 's|^[\ \t]*||g; s|^(.)| \1|')"
export SHORT_DESCRIPTION DESCRIPTION

run sed -i '/^#/d' debian/control
run sed -r -i "s|^(Section:).*|\1 x11|" debian/control
run sed -r -i "s|^(Homepage:).*|\1 ${URL}|" debian/control
run sed -r -i "s|^(Architecture:).*|\1 $(dpkg --print-architecture)|" debian/control
run sed -r -i "s|^(Description:).*|\1 ${SHORT_DESCRIPTION}|" debian/control
run sed -r -i "s|^(Depends: .*)|\1, libvte-2.91-0, libgtk-3-0|" debian/control
run sed -i '$ d' debian/control
echo "${DESCRIPTION}" | sudo -u "${USER}" tee -a debian/control >/dev/null
run rm -rf debian/README.Debian
run cp README.rst debian/README.source

if run debuild -i -us -uc -b
then
    cd ../  || exit 1
    rm -rf "${PACKAGE}"
    find . -type f -not -name "*.deb" -delete
else
    echo "Build failed!"
fi

exit
