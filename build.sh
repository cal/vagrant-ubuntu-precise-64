#!/bin/bash

# make sure we have dependencies 
hash mkisofs 2>/dev/null || { echo >&2 "ERROR: mkisofs not found.  Aborting."; exit 1; }

set -o nounset
set -o errexit
#set -o xtrace

# Configurations
BOX="ubuntu-precise-64"
ISO_URL="http://releases.ubuntu.com/precise/ubuntu-12.04.1-alternate-amd64.iso"
ISO_MD5="682b0388d2a15bf9f38480b0eb4653f6"

# location, location, location
FOLDER_BASE=`pwd`
FOLDER_ISO="${FOLDER_BASE}/iso"
FOLDER_BUILD="${FOLDER_BASE}/build"
FOLDER_VBOX="${FOLDER_BUILD}/vbox"
FOLDER_ISO_CUSTOM="${FOLDER_BUILD}/iso/custom"
FOLDER_ISO_INITRD="${FOLDER_BUILD}/iso/initrd"

# start with a clean slate
if [ -d "${FOLDER_BUILD}" ]; then
  echo "Cleaning build directory ..."
  chmod -R u+w "${FOLDER_BUILD}"
  rm -rf "${FOLDER_BUILD}"
  mkdir -p "${FOLDER_BUILD}"
fi

# Setting things back up again
mkdir -p "${FOLDER_ISO}"
mkdir -p "${FOLDER_BUILD}"
mkdir -p "${FOLDER_VBOX}"
mkdir -p "${FOLDER_ISO_CUSTOM}"
mkdir -p "${FOLDER_ISO_INITRD}"

ISO_FILENAME="${FOLDER_ISO}/`basename ${ISO_URL}`"
INITRD_FILENAME="${FOLDER_ISO}/initrd.gz"
ISO_GUESTADDITIONS="/Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso"

# download the installation disk if you haven't already or it is corrupted somehow
echo "Downloading `basename ${ISO_URL}` ..."
if [ ! -e "${ISO_FILENAME}" ]; then
  curl --output "${ISO_FILENAME}" -L "${ISO_URL}"

  # make sure download is right...
  ISO_HASH=`md5 -q "${ISO_FILENAME}"`
  if [ "${ISO_MD5}" != "${ISO_HASH}" ]; then
    echo "ERROR: MD5 does not match. Got ${ISO_HASH} instead of ${ISO_MD5}. Aborting."
    exit 1
  fi
fi

# customize it
echo "Creating Custom ISO"
if [ ! -e "${FOLDER_ISO}/custom.iso" ]; then

  echo "Untarring downloaded ISO ..."
  tar -C "${FOLDER_ISO_CUSTOM}" -xf "${ISO_FILENAME}"

  # backup initrd.gz
  echo "Backing up current init.rd ..."
  chmod u+w "${FOLDER_ISO_CUSTOM}/install" "${FOLDER_ISO_CUSTOM}/install/initrd.gz"
  mv "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # stick in our new initrd.gz
  echo "Installing new initrd.gz ..."
  cd "${FOLDER_ISO_INITRD}"
  gunzip -c "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org" | cpio -id
  cd "${FOLDER_BASE}"
  cp preseed.cfg "${FOLDER_ISO_INITRD}/preseed.cfg"
  cd "${FOLDER_ISO_INITRD}"
  find . | cpio --create --format='newc' | gzip  > "${FOLDER_ISO_CUSTOM}/install/initrd.gz"

  # clean up permissions
  echo "Cleaning up Permissions ..."
  chmod u-w "${FOLDER_ISO_CUSTOM}/install" "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # replace isolinux configuration
  echo "Replacing isolinux config ..."
  cd "${FOLDER_BASE}"
  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux" "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  rm "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  cp isolinux.cfg "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"  
  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.bin"

  # add late_command script
  echo "Add late_command script ..."
  chmod u+w "${FOLDER_ISO_CUSTOM}"
  cp "${FOLDER_BASE}/late_command.sh" "${FOLDER_ISO_CUSTOM}"
  
  echo "Running mkisofs ..."
  mkisofs -r -V "Custom Ubuntu Install CD" \
    -cache-inodes -quiet \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "${FOLDER_ISO}/custom.iso" "${FOLDER_ISO_CUSTOM}"

fi

echo "Creating VM Box..."
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

  VBoxManage startvm "${BOX}"

  echo -n "Waiting for installer to finish "
  while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
  done
  echo ""

  # Forward SSH
  VBoxManage modifyvm "${BOX}" \
    --natpf1 "guestssh,tcp,,2222,,22"

  # Attach guest additions iso
  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "${ISO_GUESTADDITIONS}"

  VBoxManage startvm "${BOX}"

  # get private key
  curl --output "${FOLDER_BUILD}/id_rsa" "https://raw.github.com/mitchellh/vagrant/master/keys/vagrant"
  chmod 600 "${FOLDER_BUILD}/id_rsa"

  # install virtualbox guest additions
  ssh -i "${FOLDER_BUILD}/id_rsa" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 2222 vagrant@127.0.0.1 "sudo mount /dev/cdrom /media/cdrom; sudo sh /media/cdrom/VBoxLinuxAdditions.run; sudo umount /media/cdrom; sudo shutdown -h now"
  echo -n "Waiting for machine to shut off "
  while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
  done
  echo ""

  VBoxManage modifyvm "${BOX}" --natpf1 delete "guestssh"

  # Detach guest additions iso
  echo "Detach guest additions ..."
  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium emptydrive
fi

echo "Building Vagrant Box ..."
vagrant package --base "${BOX}"

# references:
# http://blog.ericwhite.ca/articles/2009/11/unattended-debian-lenny-install/
# http://cdimage.ubuntu.com/releases/precise/beta-2/
# http://www.imdb.com/name/nm1483369/
# http://vagrantup.com/docs/base_boxes.html
