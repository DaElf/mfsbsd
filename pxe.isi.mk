PXE_HOST?=		qafs.west.isilon.com
PXE_USER?=		root
PXE_PATH?=		/tftpboot/pxe/images/mfsbsd/mfsbsd-onefs.gz

# XXX: this seems like something that should be coded into the dhcp
# configuration auxiliary parameters
PXE_IP!=host	${PXE_HOST} | awk '{ print $$NF }'


pxe-entry:
	@echo "label OneFS-BSD10"
	@echo "  menu label OneFS-BSD10"
	@echo "  kernel memdisk"
	@echo "  append raw"
	@echo "  initrd http://${PXE_IP}/${PXE_PATH}"

publish-pxe: ${IMAGE}.gz
	rsync -av ${.ALLSRC} ${PXE_USER}@${PXE_HOST}:${PXE_PATH}

