#!/bin/bash

BOX="ubuntu-precise-64"

# location, location, location
FOLDER_BASE=`pwd`
FOLDER_BUILD="${FOLDER_BASE}/build"
FOLDER_VBOX="${FOLDER_BUILD}/vbox"
FOLDER_ISO="${FOLDER_BUILD}/iso"
FOLDER_ISO_CUSTOM="${FOLDER_BUILD}/iso/custom"
FOLDER_ISO_INITRD="${FOLDER_BUILD}/iso/initrd"

# let's make sure they exist
mkdir -p "${FOLDER_BUILD}"
mkdir -p "${FOLDER_VBOX}"
mkdir -p "${FOLDER_ISO}"

# let's make sure they're empty
chmod -R u+w "${FOLDER_ISO_CUSTOM}"
rm -rf "${FOLDER_ISO_CUSTOM}"
mkdir -p "${FOLDER_ISO_CUSTOM}"
chmod -R u+w "${FOLDER_ISO_INITRD}"
rm -rf "${FOLDER_ISO_INITRD}"
mkdir -p "${FOLDER_ISO_INITRD}"

ISO_URL="http://cdimage.ubuntu.com/releases/precise/beta-2/ubuntu-12.04-beta2-alternate-amd64+mac.iso"
ISO_FILENAME="${FOLDER_ISO}/`basename ${ISO_URL}`"

INITRD_FILENAME="${FOLDER_ISO}/initrd.gz"

# download the installation disk if you haven't already
if [ ! -e "${ISO_FILENAME}" ]; then
  wget -O "${ISO_FILENAME}" "${ISO_URL}"
fi

# customize it
if [ ! -e "${FOLDER_ISO}/custom.iso" ]; then
  tar -C "${FOLDER_ISO_CUSTOM}" -xf "${ISO_FILENAME}"

  # backup initrd.gz
  chmod u+w "${FOLDER_ISO_CUSTOM}/install" "${FOLDER_ISO_CUSTOM}/install/initrd.gz"
  mv "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # stick in our new initrd.gz
  cd "${FOLDER_ISO_INITRD}"
  gunzip -c "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org" | cpio -id
  cd "${FOLDER_BASE}"
  cp preseed.cfg "${FOLDER_ISO_INITRD}/preseed.cfg"
  cd "${FOLDER_ISO_INITRD}"
  find . | cpio --create --format='newc' | gzip  > "${FOLDER_ISO_CUSTOM}/install/initrd.gz"
  #cd "${FOLDER_ISO_CUSTOM}"
  #chmod u+w md5sum.txt
  #find . -type f -print0 | xargs -0 md5 | sed 's/MD5 (\(.*\)) = \(.*\)/\2 \1/' > md5sum.txt 
  #chmod u-w md5sum.txt

  # clean up permissions
  chmod u-w "${FOLDER_ISO_CUSTOM}/install" "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # make new iso
  #hdiutil makehybrid \
  #  -iso -joliet \
  #  -no-emul-boot \
  #  -eltorito-boot "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.bin" \
  #  -o "${FOLDER_ISO}/custom.iso" "${FOLDER_ISO_CUSTOM}"

  #mkisofs -o "${FOLDER_ISO}/custom.iso" \
  #  -r -J -no-emul-boot -boot-load-size 4 \
  #  -b isolinux/isolinux.bin \
  #  -c isolinux/boot.cat "${FOLDER_ISO_CUSTOM}"

  #chmod u+w "${FOLDER_ISO_CUSTOM}/preseed"
  #cp unattended.seed "${FOLDER_ISO_CUSTOM}/preseed/unattended.seed"

  # replace isolinux configuration
  cd "${FOLDER_BASE}"
  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux" "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  rm "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  cp isolinux.cfg "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"  

  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.bin"

  mkisofs -r -V "Custom Ubuntu Install CD" \
    -cache-inodes -quiet \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "${FOLDER_ISO}/custom.iso" "${FOLDER_ISO_CUSTOM}"

fi

# create virtual machine
if ! VBoxManage showvminfo "${BOX}" >/dev/null 2>/dev/null; then
  VBoxManage createvm \
    --name "${BOX}" \
    --ostype Ubuntu_64 \
    --register \
    --basefolder "${FOLDER_VBOX}"

  VBoxManage modifyvm "${BOX}" \
    --memory 360 \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none \
    --vram 12 \
    --pae off \
    --rtcuseutc on

  VBoxManage storagectl "${BOX}" \
    --name "IDE Controller" \
    --add ide \
    --controller PIIX4 \
    --hostiocache on

  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "${FOLDER_ISO}/custom.iso"

  VBoxManage storagectl "${BOX}" \
    --name "SATA Controller" \
    --add sata \
    --controller IntelAhci \
    --sataportcount 1 \
    --hostiocache off

  VBoxManage createhd \
    --filename "${FOLDER_VBOX}/${BOX}/${BOX}.vdi" \
    --size 40960

  VBoxManage storageattach "${BOX}" \
    --storagectl "SATA Controller" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "${FOLDER_VBOX}/${BOX}/${BOX}.vdi"
fi

VBoxManage startvm "${BOX}"

# hook up install cd

# "install a command line system"

# switch to tty1 (ctrl+alt+fn+f1)

# edit /etc/default/grub
# - GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
# + GRUB_CMDLINE_LINUX_DEFAULT=""

# sudo update-grub

# edit /etc/sudoers
# + %sudo   ALL=NOPASSWD: ALL

# restart ...?

# sudo apt-get update
# sudo apt-get upgrade

# sudo apt-get install build-essential

# Devices > Install Guest Additions
# sudo mount /dev/cdrom /media/cdrom
# sudo sh /media/cdrom/VBoxLinuxAdditions.run
# sudo umount /media/cdrom

# sudo apt-get install ruby-dev rubygems puppet ssh
# sudo gem install chef

# cd /home/vagrant
# mkdir .ssh
# wget -O .ssh/authorized_keys "https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub"
# chmod 755 .ssh
# chmod 644 .ssh/authorized_keys

# edit /etc/ssh/sshd_config
# + UseDNS no

# sudo rm .bash_history .nano_history .lesshst

# shutdown / restart

#vagrant package --base "$name"

# references:
# http://blog.ericwhite.ca/articles/2009/11/unattended-debian-lenny-install/
# http://cdimage.ubuntu.com/releases/precise/beta-2/
# http://www.imdb.com/name/nm1483369/
# http://vagrantup.com/docs/base_boxes.html
