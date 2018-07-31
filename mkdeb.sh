#!/bin/bash
# Build a Debian package of pyat.
set -e

: ${MY_DIR:=$( dirname "$0" )}
: ${PYTHON:=$( which python2 )}

# Set a work directory if not already given
if [ -z "${WORK_DIR}" ]; then
	WORK_DIR=$( mktemp -d )

	# On failure, abort or exit, clean up
	cleanup() {
		rm -fr "${WORK_DIR}"
	}

	trap cleanup EXIT
	trap cleanup INT
	trap cleanup QUIT
	trap cleanup TERM
fi

# Set the output directory if not already given
: ${OUT_DIR:=${MY_DIR}/out}

# Retrieve the Debian source package name and version from the changelog.
eval $( sed -ne '1 {
	s/^\([^ ]*\) (\(.*\)) .*$/DEB_SRCPKG="\1" DEB_VERSION="\2"/;
	p;
}' ${MY_DIR}/debian/changelog )

# Split apart the Debian package version
DEB_PKGVERSION=${DEB_VERSION#*-}
DEB_BASEVERSION=${DEB_VERSION%-${DEB_PKGVERSION}}

# Retrieve the Python package name and version from setup.py
PY_PKGNAME=$( ${PYTHON} ${MY_DIR}/setup.py --name )
PY_VERSION=$( ${PYTHON} ${MY_DIR}/setup.py --version )

# Make the "original" source tarball
mkdir ${WORK_DIR}/pydist
${PYTHON} ${MY_DIR}/setup.py sdist --dist-dir=${WORK_DIR}/pydist --formats=gztar
# This should create ${WORK_DIR}/pydist/${PY_PKGNAME}-${PY_VERSION}.tar.gz

# Copy the source to a temporary workspace so we don't pollute the source.
BUILD_DIR=${WORK_DIR}/deb/${PY_PKGNAME}-${PY_VERSION}
mkdir ${WORK_DIR}/deb
mv ${WORK_DIR}/pydist/${PY_PKGNAME}-${PY_VERSION}.tar.gz \
	${WORK_DIR}/deb/${DEB_SRCPKG}_${DEB_BASEVERSION}.orig.tar.gz

mkdir ${BUILD_DIR}
tar 	--exclude ./.git \
	--exclude ./$( basename ${OUT_DIR} ) \
	--exclude ./dist \
	--exclude ./deb_dist \
	-C ${MY_DIR} -cf - . | tar -C ${BUILD_DIR} -xvf -

# Build it
( cd ${BUILD_DIR} && dpkg-buildpackage -us -uc )

# Create the output directory
if [ ! -d "${OUT_DIR}" ]; then
	mkdir "${OUT_DIR}"
fi

# Copy the resulting files
cp ${WORK_DIR}/deb/*.{tar.gz,deb,dsc,changes} ${OUT_DIR}
