#!/bin/bash -x

# Expect:
#   HH_ANDROID_ENV - script which will configure all Android env
#   HH_UNPACK_IRFS - script which will unpack uInitramfs
#   HH_ANDROID_INPRODUCT_PATH - Path to which all Android images should be copied
#   HH_PRODUCT_PROVISIONING - script for product provisioning
#   HH_OUT_PRODUCT_IMAGE_COPY - directory to which result product image should be copied

#export HH_ENABLED=1
export HH_VERSION=0.2
export HH_PATH=~/bin/hhelpers/henv.sh
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
  adb connect `systemctl -n 1 status isc-dhcp-server | tail -n1 | awk ' {print $8} '`
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

