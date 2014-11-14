# Our images are fat
MFSROOT_MAXSIZE=	512m

BRANCH?=		BR_RIPT_BSD10

WRKDIR=			${.CURDIR}/tmp
BASE=			${WRKDIR}
BASEFILE=		${.CURDIR}/install.tar.gz
KERN_TAR=		kernel.IQ.amd64.debug.txz 
CUSTOMFILES=		/nonexistent
FREEBSD9=		1
IMAGE=			disk.img
KERNELFILE=		/dev/null
KERNDIR?=		kernel.amd64
PRUNELIST=		tools/prunelist-isi

# need xz and tar to build /usr from .usr.tar.xz
WITH_RESCUE=

MFSMODULES=	geom_mirror geom_nop opensolaris zfs ext2fs snp smbus ipmi ntfs nullfs tmpfs
MFSMODULES+=	if_bxe if_cxgb if_cxgbe if_em if_igb if_ixgbe
MFSMODULES+=	cpuctl kcs
MFSMODULES+=	efs

BOOTFILES=	boot defaults loader loader.help *.rc *.4th
BOOTFILES+=	*boot mbr pmbr zfsloader

${BASE}:
	mkdir -p ${.TARGET}

fetch-image: ${BASEFILE}
${BASEFILE}:
	fetch -o ${.TARGET} http://buildbiox.west.isilon.com/snapshots/latest.${BRANCH}/obj.DEBUG/${.TARGET:T}

mn-fetch:
	fetch -o install.tar.gz http://mn-build-00.west.isilon.com/mn-builds/BR_RIPT_BSD10_436/install.tar.gz
	fetch -o ${KERN_TAR} http://mn-build-00.west.isilon.com/mn-builds/BR_RIPT_BSD10_436/${KERN_TAR}

F=${.CURDIR}/../mfsbsd/${KERN_TAR}
e:
	@echo "${KERN_TAR:R}"
	@echo "${F:tA}"
