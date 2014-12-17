#!/bin/sh
set -e

find / -name \*.core -print -exec rm {} \;
(cd /etc; ln -fs ../isi-etc/gconfig .; ln -fs ../isi-etc/mcp .)

python -c "import isi.sys.bootdisk as bootdisk; bootdisk.unlock_bootdisks();"

if [ -z $1]; then
    #image='http://buildbiox.west.isilon.com/snapshots/latest.BR_RIPT_BSD10/obj.DEBUG/install.tar.gz'
    image='http://buildbiox.west.isilon.com/snapshots/b.11124/obj.DEBUG/install.tar.gz'
else
    image=$1
fi

if [ ! -f /tmp/install.tar.gz ]; then
    echo "fetching ${image}"
    fetch -o /tmp/install.tar.gz ${image}
    if [ $? -ne 0 ]; then
	echo "Error fetching file, aborting"
	exit 1
    fi
else
    echo "found ${image}"
fi

for _mirror in `gmirror list | grep name | awk '{print $3}'`; do
    echo "destroying $_mirror"
    gmirror destroy -f $_mirror
done

size=`gpart show ada0 | head -1 | awk '{print $3}'`

disks="ada0 ada1"

for d in ${disks}; do
    gpart destroy -F $d || true
    gpart create -s gpt $d
done

partition_disk() {
    disk=$1
    size=$2
    
    echo $size
    
    s_mfg=65536
    s_keys=65536
    s_crash=4194304
    s_jb=1048577
    s_var0=2097152
    s_root0=2097152
    
    start_ks=`expr $size - $s_keys - 8`
    start_mfg=`expr $start_ks - $s_mfg`
    start_crash=`expr $start_mfg - $s_crash` 
    start_jb=`expr $start_crash - $s_jb`
    start_var0=`expr $start_jb - $s_var0`
    
    echo "starting keystore @ $start_ks"
    echo "starting mfg @ $start_mfg"
    echo "starting crash @ $start_crash"
    echo "starting jb @ $start_jb"
    echo "starting var0 @ $start_var0"
    
#    gpart add -i 12 -t freebsd-ufs -l keystore  -b $start_ks    -s $s_keys   $disk
#    gpart add -i 11 -t freebsd-ufs -l mfg       -b $start_mfg   -s $s_mfg    $disk
#    gpart add -i 9  -t freebsd-ufs -l var-crash -b $start_crash -s $s_crash  $disk
#    gpart add -i 8  -t freebsd-ufs -l journal-backup -b $start_jb -s $s_jb   $disk
    
    gpart add -i 1 -t freebsd-boot       -l boot                -s 128       $disk
    gpart add -i 3 -t isilon-bootdiskid  -l bootdiskid -b 162   -s 1         $disk
    gpart add -a 4k -i 4 -t freebsd-ufs  -l root0      -b 108544 -s $s_root0 $disk
    gpart add -a 4k -i 6 -t freebsd-ufs  -l var0                 -s $s_var0 $disk

    gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 $disk
}

stash_important_stuff() {
    mkdir -p /tmp/stash/mfg
    mkdir -p /tmp/stash/keystore
    rsync -avH /root0/mfg/ /tmp/stash/mfg/
    rsync -avH /root0/keystore/ /tmp/stash/keystore/
}

restore_important_stuff() {

    rsync -avH /tmp/stash/mfs/ /root0/mfg/
    rsync -avH /tmp/stash/keystore/ /root0/keystore/
    
}
			
partition_disk "ada0" $size
partition_disk "ada1" $size

gpart set -a bootme -i 4 $disk

make_mirror() {

    disks=$1
    part=$2
    label=$3
    parts=
    for d in ${disks}; do
	parts="${parts} ${d}p${part}"
    done

    gmirror label ${label} ${parts}
}

make_mirror "${disks}" 4 root0
make_mirror "${disks}" 6 var0
#make_mirror "${disks}" 11 mfg
#make_mirror "${disks}" 12 keystore


newfs /dev/mirror/root0
newfs /dev/mirror/var0

mkdir -p /root0
mount /dev/mirror/root0 /root0
mkdir -p /root0/var
mount /dev/mirror/var0 /root0/var

time tar xf /tmp/install.tar.gz --exclude ./usr/lib/debug -C /root0

#chroot /root0 sh -c 'echo a | pw usermod root -h 0'

#rm -f /root0/etc/rc.conf
#touch /root0/etc/rc.conf
#echo 'ifconfig_em0="DHCP"' >> /root0/etc/rc.conf
#echo 'sshd_enable="YES"' >> /root0/etc/rc.conf

sed  s/\#PermitRootLogin\ no/PermitRootLogin\ yes/ < /root0/etc/ssh/sshd_config > /tmp/$$
mv /tmp/$$ /root0/etc/ssh/sshd_config

sed  s/console="comconsole"/console="vidconsole"/ < /root0/boot/loader.conf > /tmp/$$
mv /tmp/$$ /root0/boot/loader.conf

umount /root0/var
umount /root0
