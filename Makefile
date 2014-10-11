# $Id$
#
# mfsBSD
# Copyright (c) 2007-2015 Martin Matuska <mm at FreeBSD.org>
#
# Version 2.1
#

# Include any isi config overrides
.sinclude "config.isi.mk"

#
# User-defined variables
#
BASE?=/cdrom/usr/freebsd-dist
KERNCONF?= GENERIC
MFSROOT_FREE_INODES?=10%
MFSROOT_FREE_BLOCKS?=10%
MFSROOT_MAXSIZE?=80m

# If you want to build your own kernel and make you own world, you need to set
# -DCUSTOM or CUSTOM=1
#
# To make buildworld use 
# -DCUSTOM -DBUILDWORLD or CUSTOM=1 BUILDWORLD=1
#
# To make buildkernel use
# -DCUSTOM -DBUILDKERNEL or CUSTOM=1 BUILDKERNEL=1
#
# For all of this use
# -DCUSTOM -DBUILDWORLD -DBUILDKERNEL or CUSTOM=1 BUILDKERNEL=1 BUILDWORLD=1
#

#
# Paths
#
SRC_DIR?=/usr/src
CFGDIR?=conf
SCRIPTSDIR=scripts
PACKAGESDIR?=packages
CUSTOMFILESDIR=customfiles
TOOLSDIR=	tools
PRUNELIST?=	${TOOLSDIR}/prunelist
KERN_EXCLUDE?=	${TOOLSDIR}/kern_exclude
PKG_STATIC?=	${TOOLSDIR}/pkg-static
#
# Program defaults
#
MKDIR?=		/bin/mkdir -p
CHOWN?=		/usr/sbin/chown
CAT?=		/bin/cat
PWD?=		/bin/pwd
TAR?=		/usr/bin/tar
GTAR?=		/usr/local/bin/gtar
CP?=		/bin/cp
MV?=		/bin/mv
RM?=		/bin/rm
RMDIR?=		/bin/rmdir
CHFLAGS?=	/bin/chflags
GZIP?=		/usr/bin/gzip
TOUCH?=		/usr/bin/touch
INSTALL?=	/usr/bin/install
LS?=		/bin/ls
LN?=		/bin/ln
FIND?=		/usr/bin/find
PW?=		/usr/sbin/pw
SED?=		/usr/bin/sed
UNAME?=		/usr/bin/uname
BZIP2?=		/usr/bin/bzip2
XZ?=		/usr/bin/xz
MAKEFS?=	/usr/sbin/makefs
MKISOFS?=	/usr/local/bin/mkisofs
SSHKEYGEN?=	/usr/bin/ssh-keygen
SYSCTL?=	/sbin/sysctl
PKG?=		/usr/local/sbin/pkg
#
WRKDIR?=	${.CURDIR}/work
#
BSDLABEL?=	bsdlabel
#
DOFS=		${TOOLSDIR}/doFS.sh

SCRIPTS?=	mdinit mfsbsd interfaces packages
BOOTMODULES?=	acpi ahci
MFSMODULES?=	\
MFSMODULES?=	geom_mirror geom_nop opensolaris zfs ext2fs snp smbus ipmi ntfs nullfs tmpfs \
	aesni crypto cryptodev geom_eli
#
BOOTFILES?=	boot *boot mbr pmbr defaults loader zfsloader loader.help *.rc *.4th device.hints
MFSMODULES+=	if_cxgb if_cxgbe if_igb if_ixg
#

.if defined(V)
_v=
VERB=1
.else
_v=@
VERB=
.endif

.if !defined(ARCH)
TARGET!=	${SYSCTL} -n hw.machine_arch
.else
TARGET=		${ARCH}
.endif

.if !defined(RELEASE)
RELEASE!=	${UNAME} -r
.endif

.if !defined(SE)
IMAGE_PREFIX?=	mfsbsd
.else
IMAGE_PREFIX?=	mfsbsd-se
.endif

IMAGE?=		${IMAGE_PREFIX}-${RELEASE}-${TARGET}.img
ISOIMAGE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.iso
TARFILE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar
GCEFILE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar.gz
_DISTDIR=	${WRKDIR}/dist/${RELEASE}-${TARGET}

.if !defined(DEBUG)
EXCLUDE=	--exclude *.symbols
.else
EXCLUDE=
.endif

# Roothack stuff
.if defined(ROOTHACK_FILE) && exists(${ROOTHACK_FILE})
ROOTHACK=	1
ROOTHACK_PREBUILT=1
_ROOTHACK_FILE=	${ROOTHACK_FILE}
.else
_ROOTHACK_FILE=	${WRKDIR}/roothack/roothack
.endif

.if defined(ISI)
BASE=		${.CURDIR}
BASEFILE=	${BASE}/install.tar.gz
# kernel is packaged in install.tar.gz
KERNELFILE=/dev/null
PKGNG=1
.endif

#default to new layout
BASEFILE?=	${BASE}/base.txz
KERNELFILE?=	${BASE}/kernel.txz

.if defined(MAKEJOBS)
_MAKEJOBS=	-j${MAKEJOBS}
.endif

_ROOTDIR=	${WRKDIR}/freebsd
_BOOTDIR=	${_ROOTDIR}/boot
.if defined(ROOTHACK)
_DESTDIR=	${_ROOTDIR}/rw
MFSROOT_FREE_INODES?=1%
MFSROOT_FREE_BLOCKS?=1%
.else
_DESTDIR=	${_ROOTDIR}
.endif

.if !defined(SE)
# Environment for custom build
BUILDENV?= env \
	NO_FSCHG=1 \
	WITHOUT_CLANG=1 \
	WITHOUT_DICT=1 \
	WITHOUT_GAMES=1 \
	WITHOUT_LIB32=1

# Environment for custom install
INSTALLENV?= ${BUILDENV} \
	WITHOUT_TOOLCHAIN=1
.endif

.if defined(FULLDIST)
NO_PRUNE=1
WITH_RESCUE=1
.endif

DO_PRUNE?=	-X ${PRUNELIST}

all: image

destdir: ${_DESTDIR} ${_BOOTDIR}
${_DESTDIR}:
	${MKDIR} ${_DESTDIR}
	${CHOWN} root:wheel ${_DESTDIR}

${_BOOTDIR}:
	${MKDIR} ${_BOOTDIR}/kernel ${_BOOTDIR}/modules
	${CHOWN} -R root:wheel ${_BOOTDIR}

extract: destdir ${BASEFILE} ${WRKDIR}/.extract_done
${WRKDIR}/.extract_done:
.if !defined(CUSTOM)
	${_v}if [ ! -d "${BASE}" ]; then \
		echo "Please set the environment variable BASE to a path"; \
		echo "with FreeBSD distribution files (e.g. /cdrom/9.2-RELEASE)"; \
		echo "Examples:"; \
		echo "make BASE=/cdrom/9.2-RELEASE"; \
		echo "make BASE=/cdrom/usr/freebsd-dist"; \
		exit 1; \
	fi
	@echo "Extracting base and kernel ..."
	${_v}${TAR} --unlink -xpf ${BASEFILE} ${DO_PRUNE} -C ${_DESTDIR}
	if [ -f ${KERNELFILE} ]; then \
		${TAR} --unlink -xpf ${KERNELFILE} -C ${_ROOTDIR}; \
	fi
	@echo " done"
.endif
	${_v}${TOUCH} ${WRKDIR}/.extract_done

build: extract ${WRKDIR}/.build_done
${WRKDIR}/.build_done:
.if defined(CUSTOM)
. if defined(BUILDWORLD)
	@echo -n "Building world ..."
	${_v}cd ${SRC_DIR} && \
	${BUILDENV} make ${_MAKEJOBS} buildworld TARGET=${TARGET}
. endif
. if defined(BUILDKERNEL)
	@echo -n "Building kernel KERNCONF=${KERNCONF} ..."
	${_v}cd ${SRC_DIR} && make buildkernel KERNCONF=${KERNCONF} TARGET=${TARGET}
. endif
.endif
	${_v}${TOUCH} ${WRKDIR}/.build_done

install: destdir build ${WRKDIR}/.install_done
${WRKDIR}/.install_done:
.if defined(CUSTOM)
	@echo -n "Installing world and kernel KERNCONF=${KERNCONF} ..."
	${_v}cd ${SRC_DIR} && \
	${INSTALLENV} make installworld distribution DESTDIR="${_DESTDIR}" TARGET=${TARGET} && \
	${INSTALLENV} make installkernel KERNCONF=${KERNCONF} DESTDIR="${_ROOTDIR}" TARGET=${TARGET}
.endif
.if defined(SE)
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	@echo -n "Copying base.txz and kernel.txz ..."
. else
	@echo -n "Creating base.txz and kernel.txz ..."
. endif
	${_v}${MKDIR} ${_DISTDIR}
. if defined(ROOTHACK)
	${CP} -rp ${_BOOTDIR}/${KERNDIR}/* ${_DESTDIR}/boot/kernel/*
. endif
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	${_v}${CP} ${BASE}/base.txz ${_DISTDIR}/base.txz
	${_v}${CP} ${BASE}/kernel.txz ${_DISTDIR}/kernel.txz
. else
	${TAR} -c -C ${_DESTDIR} -J ${EXCLUDE} --exclude "boot/${KERNDIR}/*" -f ${_DISTDIR}/base.txz .
	${TAR} -c -C ${_DESTDIR} -J ${EXCLUDE} -f ${_DISTDIR}/kernel.txz boot/${KERNDIR}
. endif
	@echo " done"
. if defined(ROOTHACK)
	${RM} -rf ${_DESTDIR}/boot/${KERNDIR}
. endif
.endif
	${_v}${CHFLAGS} -R noschg ${_DESTDIR} > /dev/null 2> /dev/null || exit 0
.if !defined(WITHOUT_RESCUE) && defined(RESCUE_LINKS)
	${_v}cd ${_DESTDIR} && \
	for FILE in `${FIND} rescue -type f`; do \
	FILE=$${FILE##rescue/}; \
	if [ -f bin/$$FILE ]; then \
		${RM} bin/$$FILE && \
		${LN} rescue/$$FILE bin/$$FILE; \
	elif [ -f sbin/$$FILE ]; then \
		${RM} sbin/$$FILE && \
		${LN} rescue/$$FILE sbin/$$FILE; \
	elif [ -f usr/bin/$$FILE ]; then \
		${RM} usr/bin/$$FILE && \
		${LN} -s ../../rescue/$$FILE usr/bin/$$FILE; \
	elif [ -f usr/sbin/$$FILE ]; then \
		${RM} usr/sbin/$$FILE && \
		${LN} -s ../../rescue/$$FILE usr/sbin/$$FILE; \
	fi; \
	done
.endif
.if defined(WITHOUT_RESCUE)
	${_v}cd ${_DESTDIR} && ${RM} -rf rescue
.endif
	${_v}${TOUCH} ${WRKDIR}/.install_done

prune:
	@echo "Not doing a damn thing"

prune_: install ${WRKDIR}/.prune_done
${WRKDIR}/.prune_done:
.if !defined(NO_PRUNE)
	@echo -n "Removing selected files from distribution ..."
	${_v}if [ -f "${PRUNELIST}" ]; then \
		for FILE in `cat ${PRUNELIST}`; do \
			if [ -n "$${FILE}" ]; then \
				${RM} -rf ${_DESTDIR}/$${FILE}; \
			fi; \
		done; \
	fi
	${_v}${TOUCH} ${WRKDIR}/.prune_done
	@echo " done"
.endif

packages: install prune ${WRKDIR}/.packages_done
${WRKDIR}/.packages_done:
.if defined(PKGNG)
	@echo -n "Installing pkgng ..."
.  if !exists(${PKG_STATIC})
	@echo "pkg-static not found at: ${PKG_STATIC}"
	${_v}exit 1
.  endif
	${_v}mkdir -p ${_DESTDIR}/usr/local/sbin
	${_v}${INSTALL} -o root -g wheel -m 0755 ${PKG_STATIC} ${_DESTDIR}/usr/local/sbin/
	${_v}${LN} -sf pkg-static ${_DESTDIR}/usr/local/sbin/pkg
	@echo " done"
.endif
	${_v}if [ -d "${PACKAGESDIR}" ]; then \
		echo -n "Copying user packages ..."; \
		${CP} -rf ${PACKAGESDIR} ${_DESTDIR}; \
		echo " done"; \
	fi
.if defined(PKGNG)
	${_v}if [ -d "${_DESTDIR}/packages" ]; then \
		cd ${_DESTDIR}/packages && for FILE in *; do \
		echo -n "Installing user packages ..."; \
		done; \
	fi
	${_v}if [ -d "${_DESTDIR}/packages" ]; then \
                cd ${_DESTDIR}/packages && for _FILE in *; do \
                        _FILES="$${_FILES} /packages/$${_FILE}"; \
                done; \
                ${PKG} -c ${_DESTDIR} add -M $${_FILES}; \
	fi
.endif
	${_v}if [ -d "${_DESTDIR}/packages" ]; then \
		${RM} -rf ${_DESTDIR}/packages; \
		echo " done"; \
	fi
	${_v}${TOUCH} ${WRKDIR}/.packages_done


PACKAGES= \
	rsync

ABI=freebsd:10:x86:64
_pkgsite= env PACKAGESITE=http://pkg.freebsd.org/${ABI}/latest

packages: install prune ${WRKDIR}/.packages_done
${WRKDIR}/.packages_done:
	${CP} /etc/resolv.conf ${_DESTDIR}/etc/resolv.conf
.for _pkg in ${PACKAGES}
	${PKG} -c ${_DESTDIR} install -y ${_pkg}
.endfor
	${TOUCH} ${WRKDIR}/.packages_done
	${RM} ${_DESTDIR}/etc/resolv.conf

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo -n "Installing configuration scripts and files ..."
.for FILE in boot.config loader.conf rc.conf rc.local resolv.conf interfaces.conf ttys
. if !exists(${CFGDIR}/${FILE}) && !exists(${CFGDIR}/${FILE}.sample)
	@echo "Missing ${CFGDIR}/${FILE}.sample" && exit 1
. endif
.endfor
.if defined(SE)
	${_v}${INSTALL} -m 0644 ${TOOLSDIR}/motd.se ${_DESTDIR}/etc/motd
	${_v}${INSTALL} -d -m 0755 ${_DESTDIR}/cdrom
.else
	${_v}${INSTALL} -m 0644 ${TOOLSDIR}/motd ${_DESTDIR}/etc/motd
.endif
	${_v}${MKDIR} ${_DESTDIR}/stand ${_DESTDIR}/etc/rc.conf.d
	${_v}if [ -f "${CFGDIR}/boot.config" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/boot.config ${_ROOTDIR}/boot.config; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/boot.config.sample ${_ROOTDIR}/boot.config; \
	fi
	${_v}if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${_BOOTDIR}/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${_BOOTDIR}/loader.conf; \
	fi
	${_v}if [ -f "${CFGDIR}/rc.local" ]; then \
		${INSTALL} -m 0744 ${CFGDIR}/rc.local ${_DESTDIR}/etc/rc.local; \
	elif [ ! -f "${_DESTDIR}/etc/rc.local" ]; then \
		${INSTALL} -m 0744 ${CFGDIR}/rc.local.sample ${_DESTDIR}/etc/rc.local; \
   fi
.for FILE in rc.conf ttys
	${_v}if [ -f "${CFGDIR}/${FILE}" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE} ${_DESTDIR}/etc/${FILE}; \
	elif [ ! -f "${_DESTDIR}/etc/${FILE}" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE}.sample ${_DESTDIR}/etc/${FILE}; \
	fi
.endfor
.if defined(ROOTHACK)
	@echo 'root_rw_mount="NO"' >> ${_DESTDIR}/etc/rc.conf
.endif
	${_v}if [ -f "${CFGDIR}/resolv.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/resolv.conf ${_DESTDIR}/etc/resolv.conf; \
	fi
	${_v}if [ -f "${CFGDIR}/interfaces.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/interfaces.conf ${_DESTDIR}/etc/rc.conf.d/interfaces; \
	fi
	${_v}if [ -f "${CFGDIR}/authorized_keys" ]; then \
		${INSTALL} -d -m 0700 ${_DESTDIR}/root/.ssh; \
		${INSTALL} ${CFGDIR}/authorized_keys ${_DESTDIR}/root/.ssh/; \
	fi
	${_v}${MKDIR} ${_DESTDIR}/root/bin
	${_v}${INSTALL} ${TOOLSDIR}/zfsinstall ${_DESTDIR}/root/bin
	${_v}${INSTALL} ${TOOLSDIR}/destroygeom ${_DESTDIR}/root/bin
	${_v}for SCRIPT in ${SCRIPTS}; do \
		${INSTALL} -m 0555 ${SCRIPTSDIR}/$${SCRIPT} ${_DESTDIR}/etc/rc.d/; \
	done
#	${_v}${SED} -I -E 's/\(ttyv[2-7].*\)on /\1off/g' ${_DESTDIR}/etc/ttys
# Force ttyu0 to always be enabled with vt100 for console output
	${SED} -I -E 's/\(^ttyu0.*\)dialup\(.*\)off\(.*\)/\1vt100\2on \3/' ${_DESTDIR}/etc/ttys
.if !defined(ROOTHACK)
	${_v}echo "/dev/md0 / ufs rw 0 0" > ${_DESTDIR}/etc/fstab
	${_v}echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> ${_DESTDIR}/etc/fstab
.else
	${_v}${TOUCH} ${_DESTDIR}/etc/fstab
.endif
.if defined(ROOTPW)
	${_v}echo ${ROOTPW} | ${PW} -V ${_DESTDIR}/etc usermod root -h 0
.endif
	${_v}echo PermitRootLogin yes >> ${_DESTDIR}/etc/ssh/sshd_config
.if exists(${CFGDIR}/hosts)
	${_v}${INSTALL} -m 0644 ${CFGDIR}/hosts ${_DESTDIR}/etc/hosts
.elif exists(${CFGDIR}/hosts.sample)
	${_v}${INSTALL} -m 0644 ${CFGDIR}/hosts.sample ${_DESTDIR}/etc/hosts
.else
	@echo "Missing ${CFGDIR}/hosts.sample" && exit 1
.endif
	${_v}${TOUCH} ${WRKDIR}/.config_done
	@echo " done"

genkeys: config ${WRKDIR}/.genkeys_done
${WRKDIR}/.genkeys_done:
	@echo "Generating SSH host keys ..."
	${SSHKEYGEN} -t rsa1 -b 1024 -f ${_DESTDIR}/etc/ssh/ssh_host_key -N ''
	${SSHKEYGEN} -t dsa -f ${_DESTDIR}/etc/ssh/ssh_host_dsa_key -N ''
	${SSHKEYGEN} -t rsa -f ${_DESTDIR}/etc/ssh/ssh_host_rsa_key -N ''
	${TOUCH} ${WRKDIR}/.genkeys_done
	@echo " done"

customfiles: config ${WRKDIR}/.customfiles_done
${WRKDIR}/.customfiles_done:
.if exists(${CUSTOMFILESDIR})
	@echo "Copying user files ..."
	${_v}${CP} -afv ${CUSTOMFILESDIR}/ ${_DESTDIR}/
	${_v}${TOUCH} ${WRKDIR}/.customfiles_done
	@echo " done"
.endif

compress-usr: install prune config genkeys customfiles boot packages ${WRKDIR}/.compress-usr_done
${WRKDIR}/.compress-usr_done:
.if !defined(ROOTHACK)
	@echo -n "Compressing usr ..."
	${_v}${TAR} -c -J -C ${_DESTDIR} -f ${_DESTDIR}/.usr.tar.xz usr 
	${_v}${RM} -rf ${_DESTDIR}/usr && ${MKDIR} ${_DESTDIR}/usr 
.else
	@echo -n "Compressing root ..."
	${_v}${TAR} -c -C ${_ROOTDIR} -f - rw | \
	${XZ} -v -c > ${_ROOTDIR}/root.txz
	${_v}${RM} -rf ${_DESTDIR} && ${MKDIR} ${_DESTDIR}
.endif
	${_v}${TOUCH} ${WRKDIR}/.compress-usr_done
	@echo " done"

roothack: ${WRKDIR}/roothack/roothack
${WRKDIR}/roothack/roothack:
.if !defined(ROOTHACK_PREBUILT)
	${_v}${MKDIR} -p ${WRKDIR}/roothack
	${_v}cd ${TOOLSDIR}/roothack && env MAKEOBJDIR=${WRKDIR}/roothack make
.endif

install-roothack: compress-usr roothack ${WRKDIR}/.install-roothack_done
${WRKDIR}/.install-roothack_done:
	@echo -n "Installing roothack ..."
	${_v}${MKDIR} -p ${_ROOTDIR}/dev ${_ROOTDIR}/sbin
	${_v}${INSTALL} -m 555 ${_ROOTHACK_FILE} ${_ROOTDIR}/sbin/init
	${_v}${TOUCH} ${WRKDIR}/.install-roothack_done
	@echo " done"

boot: install prune ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo "Configuring boot environment ..."
	${MKDIR} -p ${WRKDIR}/disk/boot/kernel && ${CHOWN} root:wheel ${WRKDIR}/disk
	${TAR} -cf -  -X ${KERN_EXCLUDE} -C ${_BOOTDIR}/${KERNDIR} . | ${TAR} -xvf - -C ${WRKDIR}/disk/boot/kernel
	${_v}${CP} -rp ${_DESTDIR}/boot.config ${WRKDIR}/disk
.for FILE in ${BOOTFILES}
	-${CP} -rp ${_DESTDIR}/boot/${FILE} ${WRKDIR}/disk/boot
.endfor
.if defined(DEBUG)
	-${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/kernel.symbols ${WRKDIR}/disk/boot/kernel
.endif
.for FILE in ${BOOTMODULES}
	-${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/${FILE}.ko ${WRKDIR}/disk/boot/kernel
. if defined(DEBUG)
	-${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/${FILE}.ko.symbols ${WRKDIR}/disk/boot/kernel
. endif

	-find  ${_BOOTDIR}/${KERNDIR} -name 'acpi*.ko' -exec ${INSTALL} -m 0555 {} ${WRKDIR}/disk/boot/kernel/ \;
.endfor
	${_v}${MKDIR} -p ${_DESTDIR}/boot/modules
.for FILE in ${MFSMODULES}
	-${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/${FILE}.ko ${_DESTDIR}/boot/modules
. if defined(DEBUG)
	-${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/${FILE}.ko.symbols ${_DESTDIR}/boot/modules
. endif
.endfor
.if defined(ROOTHACK)
	@echo "Installing tmpfs module for roothack ..."
	${MKDIR} -p ${_ROOTDIR}/boot/modules
	${INSTALL} -m 0666 ${_BOOTDIR}/${KERNDIR}/tmpfs.ko ${_ROOTDIR}/boot/modules
	@echo " done"
.endif
	${RM} -rf ${_BOOTDIR}/${KERNDIR} ${_BOOTDIR}/*.symbols
	${TOUCH} ${WRKDIR}/.boot_done
	@echo " done"

.if defined(ROOTHACK)
mfsroot: install prune config genkeys customfiles boot compress-usr packages install-roothack ${WRKDIR}/.mfsroot_done
.else
mfsroot: install prune config genkeys customfiles boot compress-usr packages ${WRKDIR}/.mfsroot_done
.endif
${WRKDIR}/.mfsroot_done:
	@echo -n "Creating and compressing mfsroot ..."
	${_v}${MKDIR} ${WRKDIR}/mnt
	${_v}${MAKEFS} -t ffs -m ${MFSROOT_MAXSIZE} -f ${MFSROOT_FREE_INODES} -b ${MFSROOT_FREE_BLOCKS} ${WRKDIR}/disk/mfsroot ${_ROOTDIR} > /dev/null
	${_v}${RM} -rf ${WRKDIR}/mnt
	${_v}${GZIP} -9 -f ${WRKDIR}/disk/mfsroot
	${_v}${GZIP} -9 -f ${WRKDIR}/disk/boot/kernel/kernel
	${_v}if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${WRKDIR}/disk/boot/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${WRKDIR}/disk/boot/loader.conf; \
	fi
	${_v}${TOUCH} ${WRKDIR}/.mfsroot_done
	@echo " done"

fbsddist: install prune config genkeys customfiles boot compress-usr packages mfsroot ${WRKDIR}/.fbsddist_done
${WRKDIR}/.fbsddist_done:
.if defined(SE)
	@echo -n "Copying FreeBSD installation image ..."
	${_v}${CP} -rf ${_DISTDIR} ${WRKDIR}/disk/
	@echo " done"
.endif
	${_v}${TOUCH} ${WRKDIR}/.fbsddist_done

image: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${IMAGE}
${IMAGE}:
	@echo "This is the old mbr based image -- use make disk.img for gpt image"
	false
	@echo -n "Creating image file ..."
.if defined(BSDPART)
	${_v}${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	${_v}${INSTALL} -m 0444 ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
	${_v}${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	${_v}${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	${_v}${MV} ${WRKDIR}/disk.img ${.TARGET}
.else
	${_v}${TOOLSDIR}/do_gpt.sh ${.TARGET} ${WRKDIR}/disk 0 ${_ROOTDIR}/boot ${VERB}
.endif
	@echo " done"
	${_v}${LS} -l ${.TARGET}

disk.img: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist
	sh ./tools/do_gpt.sh disk.img ${WRKDIR}/disk 0

gce: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${IMAGE} ${GCEFILE}
${GCEFILE}:
	@echo -n "Creating GCE-compatible tarball..."
.if !exists(${GTAR})
	${_v}echo "${GTAR} is missing, please install archivers/gtar first"; exit 1
.else
	${_v}${GTAR} -C ${.CURDIR} -Szcf ${GCEFILE} --transform='s/${IMAGE}/disk.raw/' ${IMAGE}
	@echo " GCE tarball built"
	${_v}${LS} -l ${GCEFILE}
.endif

iso: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${ISOIMAGE}
${ISOIMAGE}:
	@echo -n "Creating ISO image ..."
.if defined(USE_MKISOFS)
. if !exists(${MKISOFS})
	@echo "${MKISOFS} is missing, please install sysutils/cdrtools first"; exit 1
. else
	${_v}${MKISOFS} -b boot/cdboot -no-emul-boot -r -J -V mfsBSD -o ${ISOIMAGE} ${WRKDIR}/disk
. endif
.else
	${_v}${MAKEFS} -t cd9660 -o rockridge,bootimage=i386\;/boot/cdboot,no-emul-boot,label=mfsBSD ${ISOIMAGE} ${WRKDIR}/disk
.endif
	@echo " done"
	${_v}${LS} -l ${ISOIMAGE}

tar: install prune config customfiles boot compress-usr mfsroot fbsddist ${TARFILE}
${TARFILE}:
	@echo -n "Creating tar file ..."
	${_v}cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${.CURDIR}/${TARFILE} {} \;
	@echo " done"
	${_v}${LS} -l ${TARFILE}

clean-roothack:
	${_v}${RM} -rf ${WRKDIR}/roothack

clean: clean-roothack
	${_v}if [ -d ${WRKDIR} ]; then ${CHFLAGS} -R noschg ${WRKDIR}; fi
	${_v}cd ${WRKDIR} && ${RM} -rf mfs mnt disk dist trees .*_done
	${RM} -f disk.img disk.img.gz


.sinclude "pxe.isi.mk"
