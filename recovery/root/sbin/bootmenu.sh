#!/sbin/sh

# Ketut P. Kumajaya, May 2013, Nov 2013, Mar 2014, Sept 2014
# Do not remove above credits header!

format_to_ext4() {
  # Don't reformat ext4 formatted filesystem
  if [ $(blkid ${1} | grep -c "ext4") -lt 1 ]; then
    make_ext4fs -J ${1}
  fi
}

format_to_f2fs() {
  # Don't reformat f2fs formatted filesystem
  if [ $(blkid ${1} | grep -c "f2fs") -lt 1 ]; then
    mkfs.f2fs ${1}
  fi
}

DEFAULTROM=0
F2FS=0

# Galaxy Note 2 N7105 block device
# Don't use /dev/block/platform/*/by-name/* symlink!
SYSTEMDEV="/dev/block/mmcblk0p13"
DATADEV="/dev/block/mmcblk0p16"
CACHEDEV="/dev/block/mmcblk0p12"
# Use a common /cache
HIDDENDEV="/dev/block/mmcblk0p12"

# Galaxy Tab 3 T31x block device
# SYSTEMDEV="/dev/block/mmcblk0p20"
# DATADEV="/dev/block/mmcblk0p21"
# CACHEDEV="/dev/block/mmcblk0p19"
# HIDDENDEV="/dev/block/mmcblk0p16"

# Galaxy Tab 2 block device
# SYSTEMDEV="/dev/block/mmcblk0p9"
# DATADEV="/dev/block/mmcblk0p10"
# CACHEDEV="/dev/block/mmcblk0p7"
# HIDDENDEV="/dev/block/mmcblk0p11"

# Set CPU governor, NEXT kernel for Galaxy Tab 2 default governor is performance
# echo interactive > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Rotate touchscreen orientation, for Galaxy Tab 2 P31xx
# echo 0 > /sys/devices/virtual/sec/tsp/pivot

# Waiting for kernel init process
sleep 1
mkdir /.secondrom

# Mount /data partition as ext4 or f2fs, will never be unmounted in 2nd recovery
if [ $(blkid $DATADEV | grep -c "ext4") -eq 1 ]; then
  busybox mount -t ext4 -o noatime,nodiratime,noauto_da_alloc,barrier=1 $DATADEV /.secondrom
else
  busybox mount -t f2fs -o noatime,nodiratime,background_gc=off,inline_xattr,active_logs=2 $DATADEV /.secondrom
  F2FS=1
fi

# Reset default recovery
echo -n 0 > /.secondrom/media/.defaultrecovery

# Check if /data/media/.secondrom/system.img exists
if [ -f /.secondrom/media/.secondrom/system.img ]; then
  # Show nice looking AROMA boot menu
  aroma 1 0 /res/misc/bootmenu.zip
  # Clear framebuffer device
  dd if=/dev/zero of=/dev/graphics/fb0
  DEFAULTROM=`cat /.secondrom/media/.defaultrecovery`
fi

if [ "$DEFAULTROM" == "1" ]; then
  # Make sure /cache filesystem same as /data filesystem
  if [ "$F2FS" == "1" ]; then
    format_to_f2fs $HIDDENDEV
  else
    format_to_ext4 $HIDDENDEV
  fi

  # 2nd recovery spesific files
  mv -f /res/misc/recovery.fstab.2 /etc/recovery.fstab
  rm -f /sbin/mount /sbin/umount
  mv -f /res/misc/mount.2 /sbin/mount
  mv -f /res/misc/umount.2 /sbin/umount
  mv -f /res/misc/virtual_keys.2.png /res/images/virtual_keys.png
  chmod 755 /sbin/mount /sbin/umount

  # Associate /dev/block/loop0 with system.img
  losetup /dev/block/loop0 /.secondrom/media/.secondrom/system.img
  # Remove default /system block device
  rm -f $SYSTEMDEV
  # Symlink /system block device to /dev/block/loop0 for transparent operation
  ln -s /dev/block/loop0 $SYSTEMDEV

  # Only if /preload partition as /cache partition
  if [ "$HIDDENDEV" != "$CACHEDEV" ]; then
    # Remove default /cache block device
    rm -f $CACHEDEV
    # Symlink /cache block device to /preload block device for transparent operation
    ln -s $HIDDENDEV $CACHEDEV
  fi

  # Bind mount /.secondrom/media/.secondrom/data to /data for transparent operation
  # no real block device and always locked
  mkdir -p /.secondrom/media/.secondrom/data
  busybox mount --bind /.secondrom/media/.secondrom/data /data
  mkdir -p /data/media
  busybox mount --bind /.secondrom/media /data/media

  # Create philz-touch_6.ini if not available and set menu_text_color to blue
  if [ ! -f /data/philz-touch/philz-touch_6.ini ]; then
    mkdir -p /data/philz-touch
    echo "menu_text_color=4" >> /data/philz-touch/philz-touch_6.ini
  fi
else
  # Make sure /cache filesystem same as /data filesystem
  if [ "$F2FS" == "1" ]; then
    format_to_f2fs $CACHEDEV
  else
    format_to_ext4 $CACHEDEV
  fi

  # 1st recovery spesific files
  rm -f /sbin/mount /sbin/umount
  mv -f /res/misc/mount /sbin/mount
  mv -f /res/misc/umount /sbin/umount
  chmod 755 /sbin/mount /sbin/umount

  # Create /data/philz-touch directory if not available
  if [ ! -f /.secondrom/philz-touch/philz-touch_6.ini ]; then
    mkdir -p /.secondrom/philz-touch
  fi

  # Unmount /data
  busybox umount -f /.secondrom
fi
