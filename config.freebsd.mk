MFSROOT_MAXSIZE=	80m

WRKDIR=			${.CURDIR}/tmp
BASE=			${.CURDIR}/10.1-RELEASE
CUSTOMFILES=		/nonexistent
FREEBSD9=		1
IMAGE=			disk.img
PRUNELIST=		tools/prunelist

# need xz and tar to build /usr from .usr.tar.xz
WITH_RESCUE=

PACKAGES=
