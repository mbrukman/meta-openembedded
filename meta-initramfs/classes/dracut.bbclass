DRACUT_PN ??= "${PN}"
DRACUT_OPTS ??= "--early-microcode --lzma"

python __anonymous () {
    pkg = d.getVar("DRACUT_PN", True)
    if pkg != 'dracut':
        d.appendVar("RDEPENDS_%s" % pkg, " dracut ")
    if not pkg.startswith('kernel'):
        d.appendVarFlag("do_configure", "depends", "virtual/kernel:do_shared_workdir")
        d.appendVarFlag("do_compile", "depends", "virtual/kernel:do_compile_kernelmodules")
}

export BUILD_TIME_KERNEL_VERSION = "${@oe.utils.read_file('${STAGING_KERNEL_BUILDDIR}/kernel-abiversion')}"

dracut_postinst () {
	MY_KERNEL_VERSION=$(readlink $D/boot/bzimage | sed 's,^.*bzImage-,,')
	if [[ -z "$MY_KERNEL_VERSION" ]]; then
		MY_KERNEL_VERSION="${KERNEL_VERSION}"
	fi
	if [[ -z "$MY_KERNEL_VERSION" ]]; then
		MY_KERNEL_VERSION="${BUILD_TIME_KERNEL_VERSION}"
	fi
	if [[ -z "$MY_KERNEL_VERSION" ]]; then
		exit 1
	fi

	if [ -n "$D" ]; then
		#DEBUGOPTS="--debug --keep"
		DEBUGOPTS="--keep"

		# We have to unset "prefix" as dracut uses it to move files around.
		# Yocto has it set as part of the build environment.
		$INTERCEPT_DIR/postinst_intercept execute_dracut ${PKG} mlprefix=${MLPREFIX} \
			prefix= \
			MY_KERNEL_VERSION=$MY_KERNEL_VERSION \
			DEPMODOPT="\"-b $D\"" \
			dracutsysrootdir=$D \
			DEBUGOPTS="\"$DEBUGOPTS\"" \
			DRACUT_OPTS="\"${DRACUT_OPTS}\"" \
			EXTRAOPTS="\"-k $D/lib/modules/$MY_KERNEL_VERSION\"" \
			systemdutildir=${systemd_unitdir} \
			systemdsystemunitdir=${systemd_system_unitdir} \
			systemdsystemconfdir=/etc/systemd/system \
			udevdir=/usr/lib/udev \
			DRACUT_TMPDIR=${WORKDIR}/dracut-tmpdir \
			DRACUT_ARCH="${TUNE_ARCH}" \
			DRACUT_TESTBIN=/bin/bash.bash \
			DRACUT_COMPRESS_LZMA=$NATIVE_ROOT/usr/bin/lzma \
			DRACUT_LDD="\"PATH='$PATH' ${STAGING_BINDIR_CROSS}/ldd --root $D\"" \
			DRACUT_LDCONFIG=$NATIVE_ROOT/usr/bin/ldconfig \
			DRACUT_INSTALL="\"$NATIVE_ROOT/usr/lib/dracut/dracut-install\"" \
			DRACUT_INSTALL_PATH="/usr/sbin:/usr/bin:/sbin:/bin"
	else
		execute_dracut $MY_KERNEL_VERSION ${DRACUT_OPTS}
	fi
}

dracut_populate_packages[vardeps] += "dracut_postinst"

python dracut_populate_packages() {
    localdata = d.createCopy()

    pkg = d.getVar('DRACUT_PN', True)

    postinst = d.getVar('pkg_postinst_%s' % pkg, True)
    if not postinst:
        postinst = '#!/bin/sh\n'
    postinst += localdata.getVar('dracut_postinst', True)
    d.setVar('pkg_postinst_%s' % pkg, postinst)
}

PACKAGESPLITFUNCS_prepend = "dracut_populate_packages "

DRACUT_DEPENDS = " \
			binutils-cross-${TUNE_ARCH} gcc-cross-${TUNE_ARCH} \
			ldconfig-native coreutils-native findutils-native \
			cpio-native util-linux-native kmod-native xz-native \
			dracut-native pkgconfig-native cross-compiler-ldd \
			systemd \
		"
DEPENDS_append_class-target = " ${DRACUT_DEPENDS}"
PACKAGE_WRITE_DEPS_append = " ${DRACUT_DEPENDS}"
