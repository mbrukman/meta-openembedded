SUMMARY = "Initramfs generator using udev"
HOMEPAGE = "https://dracut.wiki.kernel.org/index.php/Main_Page"
DESCRIPTION = "Dracut is an event driven initramfs infrastructure. dracut (the tool) is used to create an initramfs image by copying tools and files from an installed system and combining it with the dracut framework, usually found in /usr/lib/dracut/modules.d."

LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://COPYING;md5=b234ee4d69f5fce4486a80fdaf4a4263"

PE = "1"
PV = "050"
PR = "r0.alpha.rootfs"

# v049 tag plus run from a rootfs
SRCBRANCH = "allow-separate-rootfs"
SRCREV = "6fe40f64f923e61e17c9d3db06cf9bfe6e83a68a"
SRC_URI = "git://github.com/zboszor/dracut.git;protocol=https;branch=${SRCBRANCH} \
           file://0001-util.h-include-sys-reg.h-when-libc-glibc.patch \
           file://execute_dracut \
           "

DEPENDS += "kmod"
DEPENDS_append_libc-musl = " fts"

inherit bash-completion pkgconfig

S = "${WORKDIR}/git"

EXTRA_OECONF = "--prefix=${prefix} \
                --libdir=${prefix}/lib \
                --datadir=${datadir} \
                --sysconfdir=${sysconfdir} \
                --sbindir=${sbindir} \
                --disable-documentation \
                --bindir=${bindir} \
                --includedir=${includedir} \
                --localstatedir=${localstatedir} \
               "

# RDEPEND on systemd optionally
PACKAGECONFIG ??= "${@bb.utils.filter('DISTRO_FEATURES', 'systemd', d)}"
PACKAGECONFIG[systemd] = "--with-systemdsystemunitdir=${systemd_unitdir}/system/,,,systemd"

EXTRA_OEMAKE += 'libdir=${prefix}/lib LDLIBS="${LDLIBS}"'

LDLIBS_append_libc-musl = " -lfts"

do_configure() {
    ./configure ${EXTRA_OECONF}
}

do_install() {
    oe_runmake install DESTDIR=${D}
    # Its Makefile uses cp -arx to install modules.d, so fix the owner
    # to root:root
    chown -R root:root ${D}/${prefix}/lib/dracut/modules.d

    install -d -m0755 ${D}${datadir}/opkg/intercept
    install -m0755 ${WORKDIR}/execute_dracut ${D}${datadir}/opkg/intercept
}

FILES_${PN} += "${prefix}/lib/kernel \
                ${prefix}/lib/dracut \
                ${systemd_unitdir} \
                ${datadir}/opkg/intercept \
               "
FILES_${PN}-dbg += "${prefix}/lib/dracut/.debug"

CONFFILES_${PN} += "${sysconfdir}/dracut.conf"

RDEPENDS_${PN}_class-target = " \
                     findutils cpio util-linux-blkid util-linux-getopt util-linux-losetup util-linux-umount util-linux \
                     bash ldd xz plymouth-initrd kbd-consolefonts kbd-consoletrans kbd-keymaps kbd-unimaps gzip tar sed \
                     openssh-scp openssh-ssh linux-firmware \
                     ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'systemd', '', d)} \
                    "
RDEPENDS_${PN}_class-native = "coreutils-native findutils-native cpio-native util-linux-native bash-native cross-compiler-ldd"

# This could be optimized a bit, but let's avoid non-booting systems :)
RRECOMMENDS_${PN}_class-target = " \
                     kernel-modules \
                     busybox \
                     coreutils \
                     intel-microcode \
                    "

BBCLASSEXTEND = "native"
