# Our images are fat
MFSROOT_MAXSIZE=	512m

BRANCH?=		BR_RIPT_BSD10

WRKDIR=			${.CURDIR}/tmp
BASE=			${WRKDIR}
BASEFILE=		${.CURDIR}/install.tar.gz
CUSTOMFILES=		/nonexistent
FREEBSD9=		1
IMAGE=			disk.img
KERNELFILE=		/dev/null
KERNDIR=		kernel.amd64
PRUNELIST=		tools/prunelist-isi

WITHOUT_RESCUE=

MFSMODULES=	geom_mirror geom_nop opensolaris zfs ext2fs snp smbus ipmi ntfs nullfs tmpfs
MFSMODULES+=	if_bxe if_cxgb if_cxgbe if_em if_igb if_ixgbe

BOOTFILES=	boot defaults loader loader.help *.rc *.4th
BOOTFILES+=	*boot mbr pmbr zfsloader


${BASE}:
	mkdir -p ${.TARGET}

fetch-image: ${BASEFILE}
${BASEFILE}:
	fetch -o ${.TARGET} http://buildbiox.west.isilon.com/snapshots/latest.${BRANCH}/obj.DEBUG/${.TARGET:T}
