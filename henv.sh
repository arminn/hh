#!/bin/bash -x

# Expect:
#   HH_ANDROID_ENV - script which will configure all Android env
#   HH_UNPACK_IRFS - script which will unpack uInitramfs
#   HH_ANDROID_INPRODUCT_PATH - Path to which all Android images should be copied
#   HH_PRODUCT_PROVISIONING - script for product provisioning
#   HH_OUT_PRODUCT_IMAGE_COPY - directory to which result product image should be copied

#export HH_ENABLED=1
export HH_VERSION=0.3
export HH_PRODUCT_WORKDIR=/mnt/hdd3/media/prod-devel/current
export HH_PRODUCT_CONFIG=devel
export HH_TMP_

################################################################
# hh - prints general status
################################################################
function hh()
{
  echo "HH version: "${HH_VERSION}
  echo "HH is enabled:"${HH_ENABLED}
  echo "Supported commands are:"
  echo "  hh-aenv,hh-source,hh-remount,hh-push-sync,hh-push-sync-reboot"
  if [ -z ${HH_ANDROID_ENV} ]; then
    echo "Please set HH_ANDROID_INIT as path to init script..."
  else echo "Android env: "${HH_ANDROID_ENV};
  fi
  if [ ! -z ${HH_ANDROID_INPRODUCT_PATH} ]; then
    echo "HH_ANDROID_INPRODUCT_PATH="${HH_ANDROID_INPRODUCT_PATH}	
  fi
  echo "HH_PRODUCT_PROVISIONING="${HH_PRODUCT_PROVISIONING}
  echo "HH_OUT_PRODUCT_IMAGE_COPY"=${HH_OUT_PRODUCT_IMAGE_COPY}
}

function _get_board_ip()
{
  export BOARD_IP=`systemctl -n 1 status isc-dhcp-server | tail -n1 | awk ' {print $8} '`
}

################################################################
# hh-aenv - will init Android env in current session, using
#           HH_ANDROID_ENV, which point to Android env script
################################################################
function hh-aenv()
{
  source ${HH_ANDROID_ENV}
}

################################################################
# _connect_sync - used internally for get sync connection
################################################################
function _connect_sync()
{
  _get_board_ip
  adb connect ${BOARD_IP}":5555"
  #adb connect `systemctl -n 1 status isc-dhcp-server | tail -n1 | awk ' {print $8} '`
  adb wait-for-device
}

################################################################
# hh-remount - remount partitions on devices, if it possible
################################################################
function hh-remount()
{
  _connect_sync
  adb root
  _connect_sync
  adb remount
}

################################################################
# hh-push-sync - do remount and sync all new data to device
################################################################
function hh-push-sync()
{
  _connect_sync
  adb root
  _connect_sync
  adb remount
  adb sync
  adb shell sync
}

################################################################
# hh-push-sync-reboot - same as hh-push-sync and after reboot
################################################################
function hh-push-sync-reboot()
{
  _connect_sync
  adb root
  _connect_sync
  adb remount
  adb sync
  adb shell sync
  adb reboot
}

################################################################
# hh-check-selinux - check dmesg for selinux messages
################################################################
function hh-check-selinux()
{
  POLICY=/tmp/policy.tmp
  _connect_sync
  adb pull /sys/fs/selinux/policy ${POLICY}
  adb shell su root dmesg | grep 'avc: ' | audit2allow -p ${POLICY}
}

################################################################
# hh-clean-kernel-out - cleans all kernel compilation artifacts
################################################################
function hh-clean-kernel-out()
{
  if [ -z ${ANDROID_PRODUCT_OUT} ]; then
    echo "Please proceed with hh-env"
    return -1
  fi
  if [ -d  ${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ ]; then
    rm -rf ${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ
  fi
  if [ -d  ${ANDROID_PRODUCT_OUT}/obj/KERNEL_MODULES ]; then
    rm -rf ${ANDROID_PRODUCT_OUT}/obj/KERNEL_MODULES/
  fi
}

function hh-make-update()
{
  if [ -z ${HH_ANDROID_INPRODUCT_PATH} ]; then
    echo "Please setup HH_ANDROID_INPRODUCT_PATH"
    exit -1
  fi
  if [ -z ${ANDROID_PRODUCT_OUT} ]; then
    echo "Please setup hh-aenv"
    exit -1
  fi

  make -j5
  cp ${ANDROID_PRODUCT_OUT}/*.img ${HH_ANDROID_INPRODUCT_PATH}
  cp ${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ/arch/arm64/boot/Image ${HH_ANDROID_INPRODUCT_PATH}
  pushd ${HH_PRODUCT_TOP}
  echo "Before provisioning"
  PATH=$PATH:. ./mk_sdcard_image.sh -p . -d /tmp/test.img -c devel -r -v
  if [ ! -z ${HH_OUT_PRODUCT_IMAGE_COPY} ]; then
    sudo cp /tmp/test.img ${HH_OUT_PRODUCT_IMAGE_COPY}
  fi
  popd
}

function hh-update()
{
  if [ -z ${HH_ANDROID_INPRODUCT_PATH} ]; then
    echo "Please setup HH_ANDROID_INPRODUCT_PATH"
    exit -1
  fi
  if [ -z ${ANDROID_PRODUCT_OUT} ]; then
    echo "Please setup hh-aenv"
    exit -1
  fi

  #make -j5
  cp ${ANDROID_PRODUCT_OUT}/*.img ${HH_ANDROID_INPRODUCT_PATH}
  cp ${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ/arch/arm64/boot/Image ${HH_ANDROID_INPRODUCT_PATH}
  pushd ${HH_PRODUCT_TOP}
  echo "Before provisioning "${HH_PRODUCT_PROVISIONING}
  PATH=$PATH:. ./mk_sdcard_image.sh -p . -d /tmp/test.img -c devel -r -v
  if [ ! -z ${HH_OUT_PRODUCT_IMAGE_COPY} ]; then
    sudo cp /tmp/test.img ${HH_OUT_PRODUCT_IMAGE_COPY}
  fi
  popd
}



# 3301965824 is a vendor offset
# I.e. you need to check vendor MiB offset in mk_sdcard_image.sh
# for the reference : xvda${DOMA_VENDOR_PARTITION_ID}    ext4 3149MiB  3418MiB
# 3149MiB == 3301965824
function hh-scp-vendor()
{
  _get_board_ip
  ssh root@${BOARD_IP} "mkdir -p /home/root/vendor/ && ls -l && /sbin/losetup -o 3301965824 -f /dev/mmcblk0p3 && mount /dev/loop0 /home/root/vendor/"
  scp -r ${ANDROID_PRODUCT_OUT}/vendor root@${BOARD_IP}:/home/root/
  ssh root@${BOARD_IP} "sync && umount /dev/loop0 && /sbin/losetup -d /dev/loop0"
}

function hh-scp-clear-vendor()
{
  _get_board_ip
  ssh root@${BOARD_IP} "mkdir -p /home/root/vendor/ && ls -l && /sbin/losetup -o 3301965824 -f /dev/mmcblk0p3 && mount /dev/loop0 /home/root/vendor/ && rm -rf /home/root/vendor/*"
  scp -r ${ANDROID_PRODUCT_OUT}/vendor root@${BOARD_IP}:/home/root/
  ssh root@${BOARD_IP} "sync && umount /dev/loop0 && /sbin/losetup -d /dev/loop0"
}


function hh-scp-kernel()
{
  KERNEL_PATH=${ANDROID_PRODUCT_OUT}/obj/KERNEL_OBJ/arch/arm64/boot/Image
  TMP_IFS=/tmp/ifs

  mkdir -p ${TMP_IFS}

  _get_board_ip
  ssh -oStrictHostKeyChecking=no root@${BOARD_IP} "mkdir -p /home/root/ifs/ && mount /dev/mmcblk0p1 /home/root/ifs/"
  scp root@${BOARD_IP}:/home/root/ifs/boot/uInitramfs ${TMP_IFS}/uInitramfs


  pushd ${TMP_IFS}
  yes y | uirfs.sh unpack uInitramfs ./u
  cp ${KERNEL_PATH} ./u/xt/doma/Image
  yes y | uirfs.sh pack uInitramfs ./u
  popd

  scp ${TMP_IFS}/uInitramfs root@${BOARD_IP}:/home/root/ifs/boot/uInitramfs
  ssh root@${BOARD_IP} "sync && umount /dev/mmcblk0p1"

}


################################################################
# hh-update-all-android - update ONLY android(DomA) on emmc
################################################################
function hh-update-all-android()
{
  _get_board_ip
  //hh-scp-kernel
  pushd ${HH_PRODUCT_WORKDIR}
  cp ${ANDROID_PRODUCT_OUT}/*.img ${HH_PRODUCT_WORKDIR}/domu-image-android/images/qemux86-64/
  export TMP_IMG=./tmp.img
  ./mk_sdcard_image.sh -p . -d ${TMP_IMG} -c ${HH_PRODUCT_CONFIG}
  local loop_dev=`sudo losetup --find --partscan --show ${TMP_IMG}`
  sudo dd if=${loop_dev}p3 bs=1M | ssh root@${BOARD_IP} 'dd of=/dev/mmcblk0p3 bs=1M status=progress && sync'
  sudo losetup -d ${loop_dev}
  popd
}

################################################################
# dhh-edit - used for development
################################################################
function dhh-edit()
{ 
  vim ${HH_PATH}
}

################################################################
# dhh-source - used for development
################################################################
function dhh-source()
{ 
  source ${HH_PATH}
  echo HH updated!
}

