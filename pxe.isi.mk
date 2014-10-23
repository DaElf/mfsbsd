.if defined(MIN)
PXE_HOST?=	work-dog-1.west.isilon.com
PXE_USER?=	root
PXE_PATH?=	/bits/tftpboot/pxe/images/mfsbsd/mfsbsd-onefs.gz
.endif

PXE_HOST?=	qafs.west.isilon.com
PXE_USER?=	root
PXE_PATH?=	/tftpboot/pxe/images/mfsbsd/mfsbsd-onefs.gz
IP_ADDR?=	10.10.10.10
MA= ${IP_ADDR:S/./ /g}

# XXX: this seems like something that should be coded into the dhcp
# configuration auxiliary parameters
PXE_IP!=host	${PXE_HOST} | awk '{ print $$NF }'

config-file:
	@printf '%02X' ${MA}; echo

pxe-entry:
	@echo "label OneFS-BSD10"
	@echo "  menu label OneFS-BSD10"
	@echo "  kernel memdisk"
	@echo "  append raw"
	@echo "  initrd http://${PXE_IP}/${PXE_PATH}"

${IMAGE}.gz:
	gzip --keep --force ${IMAGE}

publish-pxe: ${IMAGE}.gz
	rsync -av ${.ALLSRC} ${PXE_USER}@${PXE_HOST}:${PXE_PATH}

