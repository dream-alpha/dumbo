#!/bin/sh 
#
# dumbo.sh (c) gutemine 2023 
#           co-authors from version 1.3 Fred Bogus Trumper 
#
VERSION="V1.3.1"
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 3
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
VERBOSE=""
LINE="======================================================================"
DREAMBOX=""
DUMBO="/data/dumbo"
IMAGEDIRS="$DUMBO /data/backup /media/hdd/backup /media/ba/backup"
DUMBOTMP="/tmp"
ERASETMP=/tmp/erase.cmd
HELP=false
PASSWD=false
SHOWDEVICE=false
COPYFLASH=false
COPYDATA=false
FORCE=false
RESCUE=false
EMERGENCY=false
EXECUTE=false
FORCE=false
BOOTDEVICE=""
IMAGENAME=""
PARTITION_SIZE=""

function dumboExit() {
exit 0
}

showRainbow() {
   echo ""
   echo -e "        \e[0;101m                                                      \e[0m" 
   echo -e "        \e[0;43m                                                      \e[0m" 
   echo -e "        \e[0;103m                                                      \e[0m" 
   echo -e "        \e[1;102m                                                      \e[0m" 
   echo -e "        \e[1;104m                                                      \e[0m" 
   echo -e "        \e[0;105m                                                      \e[0m" 
   echo ""
}

setCmdLine() {
   CMDLINE=""
   if [ $DREAMBOX == "dreamone" ]; then
      CMDLINE="logo=osd0,loaded,0x7f800000 vout=1080p50hz,enable hdmimode=1080p50hz fb_width=1280 fb_height=720 console=ttyS0,1000000 root=/dev/mmcblk1p2 rootwait rootfstype=ext4 no_console_suspend panel_type=lcd_4"
   else
      if [ $DREAMBOX == "dreamtwo" ]; then
         CMDLINE="logo=osd0,loaded,0x0 vout=1080p50hz,enable hdmimode=1080p50hz fb_width=1280 fb_height=720 console=ttyS0,1000000 root=/dev/mmcblk1p2 rootwait rootfstype=ext4 no_console_suspend panel_type=lcd_4"
      else
         echo "only dreamone | dreamtwo supported"
         echo $LINE
         dumboExit
      fi
   fi
   #echo $CMDLINE
}

addCommand() {
   if [ ! -e /usr/sbin/dumbo ]; then
      ln -sfn /data/dumbo/dumbo.sh /usr/sbin/dumbo
   fi
}

showHeader() {
   echo $LINE
   echo -e "         ************ dumbo.sh (c) gutemine 2023 **************"
   echo -e "         ************ $VERSION by Fred Bogus Trumper **************"
   echo $LINE
   #rainbow disabled , pride day has already passed 
   #showRainbow
   #echo $LINE
}

showUsage() {
   echo "Usage: dumbo.sh [OPTIONS]..."
   echo ""
   echo "OPTIONS:"
   echo ""
   echo "    -i, -image     filename without path and extension tar.xz|tar.gz|tar.bz2"
   echo "                   to be extracted on sd-card - default are from $DUMBO" 
   echo "    -m, -model     dreamone|dreamtwo create sd-card for Dreambox model"
   echo "                                              - default use current Dreambox"
   echo "    -c, -copy      copy flash image to sd-card" 
   echo "    -d, -data      copy /data from Flash      - works only with -c or -i"
   echo "    -b, -boot      set bootdevice sd | flash  - default is sd"
   echo "    -p, -pass      copy password from Flash"
   echo "    -f, -force     force to accept sd-cards > 128 GB"
   echo "    -r, -rescue    build rescue loader sd-card"
   echo "    -e, -emergency build emergency repair sd-card"
   echo "    -a, -auto      automatic execution of commands on emergency sd-card"
   echo "                   !!! THINK TWICE IF YOU REALLY WANT THAT !!!"
   echo "    -s, -show      show device and boot info"
   echo "    -v, -verbose   more verbose output"
   echo "    -h, -help      show this help/usage text"
   echo $LINE
}

showVerbose() {
   if $COPYFLASH; then 
      echo "Flash:    will be copied"
   else
      echo "Image:    $IMAGE will be extracted"
   fi
   if $COPYDATA; then 
      echo "/data:     will be copied"
   else
      echo "/data:     will NOT be copied"
   fi
   echo "Device:   $BOOTDEVICE"
   echo "Dreambox: $DREAMBOX"
   if $PASSWD; then 
      echo "Password: will be copied"
   else
      echo "Password: will NOT be copied"
   fi
   if [ -e /usr/share/amlogic-boot-bin/$DREAMBOX/fip.bin ]; then
      echo "FIP:      available"
   fi
   echo $LINE
}

showDevice() {
   if checkSD; then
      if [ -e /sys/class/block/mmcblk1/size  ]; then
         SIZE=`fdisk -l /dev/mmcblk1 | grep Disk`
         echo $SIZE
         echo $LINE
      fi
      if [ -e /dev/mmcblk1p1 -a -e /dev/disk/by-partlabel/DREAMBOOT ]; then
         echo "FAT partition found"
      fi
      if [ -e /dev/mmcblk1p2 -a -e /dev/disk/by-partlabel/dreambox-rootfs ]; then
         echo "rootfs partition found"
      fi
      if [ -e /dev/mmcblk1p3 -a -e /dev/disk/by-partlabel/dreambox-data ]; then
         echo "data partition found"
      fi
      showBooted
   else
      dumboExit
   fi
}

doCleanup() {
   echo "cleaning logs ..."
   echo $LINE
   rm $DUMBOTMP/autoexec > /dev/null 2>&1
   rm $DUMBOTMP/autoexec.img > /dev/null 2>&1
   rm $ERASETMP > /dev/null 2>&1
}

getModel() {
   if [ -z $DREAMBOX ]; then
      if [ `cat /proc/stb/info/model | grep one | wc -l` -gt 0 ]; then
         DREAMBOX="dreamone"
      fi
      if [ `cat /proc/stb/info/model | grep two | wc -l` -gt 0 ]; then
         DREAMBOX="dreamtwo"
      fi
   fi
   if [ $DREAMBOX == "dreamone" -o $DREAMBOX == "dreamtwo" ]; then
      true
   else
      echo "ERROR: only dreamone | dreamtwo supported"
      false
   fi
}

getImage() {
   IMAGE=""
   TAR="tar -xJ"	
   if [ -z $IMAGENAME ];  then
      # if no image name is passed check for AIO image in dumbo directory 
      if [ -e $DUMBO/dreambox*-dreambox*.tar.xz ]; then
         IMAGE=`ls -1 $DUMBO/dreambox*-dreambox*.tar.xz | tail -n 1`
      fi
   else
      for IMAGEDIR in $IMAGEDIRS; do
         if [ -e $IMAGEDIR/$IMAGENAME.tar.xz ]; then
            IMAGE=$IMAGEDIR/$IMAGENAME.tar.xz
            TAR="tar -xJ"	
         fi
         if [ -e $IMAGEDIR/$IMAGENAME.tar.gz ]; then
            IMAGE=$IMAGEDIR/$IMAGENAME.tar.gz
            TAR="tar -xz"	
         fi
         if [ -e $IMAGEDIR/$IMAGENAME.tar.bz2 ]; then
            IMAGE=$IMAGEDIR/$IMAGENAME.tar.bz2
            TAR="tar -xj"	
         fi
      done
   fi
   if [ -z $IMAGENAME ];  then
      if [ -z $IMAGE ];  then
         if $COPYFLASH;  then
            echo "INFO: Flash image will be copied to sd-card"
            echo $LINE
            true
         else
            echo "ERROR: NO AIO image found in $DUMBO for extracting to sd-card"
            echo $LINE
            false 
         fi
      else
         if $COPYFLASH;  then
            echo "INFO: Flash image will be copied to sd-card"
            echo $LINE
            true
         else
            echo "INFO: AIO image $IMAGE found in $DUMBO for extracting to sd-card"
            echo $LINE
            true
         fi
      fi
   else
      if [ -z $IMAGE ]; then
         echo "ERROR: $IMAGENAME NOT found for extracting to sd-card"
         echo $LINE
         false
      else
         echo "INFO: $IMAGE found for extracting to sd-card"
         echo $LINE
         true
      fi
   fi
}

checkBinaries() {
   if [ -e /var/lib/dpkg/status ]; then
      UPDATE="apt-get update"
      INSTALL="apt-get -f -y install"
   else
      UPDATE="opkg update"
      INSTALL="opkg install"
   fi
   if [ ! -e /sbin/fdisk ]; then
      echo "WARNING: NO fdisk found, installing ..."
      $UPDATE
      $INSTALL util-linux-fdisk
      echo $LINE
   fi
   if [ ! -e /usr/sbin/sgdisk ]; then
      echo "WARNING: NO sgdisk found, installing from feed ..."
      $UPDATE
      if [ -e /var/lib/dpkg/status ]; then
         $INSTALL gptfdisk-sgdisk
      else
         $INSTALL util-linux-sgdisk
      fi
      echo $LINE
   fi
   if [ ! -e /usr/bin/xz ]; then
      echo "WARNING: NO xz found, installing from feed ..."
      $UPDATE
      $INSTALL xz
      echo $LINE
   fi
   if [ ! -e /usr/sbin/mkfs.fat -a ! /sbin/mkfs.fat ]; then
      echo "WARNING: NO mkfs.fat found, installing from feed ..."
      $UPDATE
      $INSTALL dosfstools
      echo $LINE
   fi
   if [ ! -e /usr/bin/wget.wget ]; then
      echo "WARNING: NO full wget found, installing ..."
      $UPDATE
      $INSTALL wget
      echo $LINE
   fi
}

checkFIP() {
   if [ -e /etc/apt/sources.list.d/aio.list ]; then
      # works without it - unless in case of emergency
      if [ ! -e /usr/share/amlogic-boot-bin ]; then
         echo "no amlogic-boot-bin found, installing ..."
         apt-get update
         apt-get install amlogic-boot-bin
      else
         echo "amlogic-boot-bin found"
      fi
      echo $LINE
   fi
}

checkAIO() {
   echo "checking for AIO Image in Flash"
   echo $LINE
   if [ ! -e /boot/dreamseven.dtb ]; then
      echo "NO AIO Image in Flash"
      echo $LINE
      false
   else
      echo "AIO Image in Flash"
      echo $LINE
      true
   fi
}

checkGPT() {
echo "checking for GPT in Flash"
   echo $LINE
   PARTITION_SIZE=$(cat /proc/partitions | grep mmcblk0p1 | awk '{print $3}')
   if [ ! $PARTITION_SIZE -eq 114688 ];then
      echo "NO GPT in Flash"
      echo $LINE
      false
   else  
      echo "GPT in Flash!"
      echo $LINE	    
      true
   fi		
}
   
checkDtb () {
echo $LINE
echo checking $DREAMBOX.dtb
echo $LINE
if [ ! -e /boot/$DREAMBOX.dtb  ]; then
   echo "/boot/$DREAMBOX.dtb not found!"
   echo $LINE
   showResult
   dumboExit
else
   echo "check $DREAMBOX.dtb passed"
   echo $LINE
fi
}

showBooted() {
   if [ `grep /dev/mmcblk1 /proc/cmdline | wc -l` -gt 0 ]; then
      echo "INFO: booted from sd-card"
      echo $LINE
      true
   else
      echo "INFO: booted from Flash"
      echo $LINE
      false
   fi
}

showData() {
   if [ `grep /dev/mmcblk1p3 /proc/mounts | grep /data | wc -l` -gt 0 ]; then
      echo "INFO: /data mounted from sd-card"
      echo $LINE
      true
   else
      echo "INFO: /data mounted from Flash"
      echo $LINE
      false
   fi
}

checkSD() {
   echo "checking sd-card"
   echo $LINE
   if [ ! -e /dev/mmcblk1 ]; then
      echo "NO sd-card found"
      echo $LINE
      false
   else
      echo "sd-card found"
      echo $LINE
      BLOCKS=`cat /sys/class/block/mmcblk1/size`
      SIZE=`expr $BLOCKS / 2048 / 1024` 
	  MB_SIZE=`expr $BLOCKS / 2048`
      echo "usable size $SIZE GB / $MB_SIZE MB"
      echo $LINE
      if [ $RESCUE == true -o $EMERGENCY == true ];then
	     if [ $BLOCKS -lt 967600 ]; then
            echo -e "this is too small - please use at least an 500MB sd-card for rescue\nloader or emergency repair sd-card"
            echo $LINE
            dumboExit
	     fi
	  else
	     if [ $SIZE -lt 6 ]; then
            echo "this is too small - please use at least an 8 GB sd-card"
            echo $LINE
            dumboExit
         fi
	  fi
      if ! $FORCE; then
         if [ $SIZE -gt 150 ]; then
            echo "this is too big - please maximum 128 GB sd-card, or use -f option"
            echo $LINE
            dumboExit
         fi
      fi
      true
   fi
}

checkFAT() {
   echo "checking FAT on SD Card"
   echo $LINE
   if [ ! -e /tmp/DREAMBOOT ]; then
      mkdir /tmp/DREAMBOOT
   fi
   if [ ! -e /dev/mmcblk1p1 ]; then
      echo "sd-card FAT partition NOT found"
      echo $LINE
      false
   else
      echo "sd-card FAT partition found"
      echo $LINE
      if [ `grep /dev/mmcblk1p1 /proc/mounts | grep /tmp/DREAMBOOT | wc -l` -eq 0 ]; then
         mount /dev/mmcblk1p1 /tmp/DREAMBOOT > /dev/null 2>&1
      fi
      # should be now mounted 
      if [ `grep /dev/mmcblk1p1 /proc/mounts | grep /tmp/DREAMBOOT | wc -l` -eq 0 ]; then
         echo "sd-card FAT partition NOT mounted"
         false
      else
         echo "sd-card FAT partition mounted"
         true
      fi
   fi
}

doUmount() {
   umount /tmp/FLASH > /dev/null 2>&1
   umount /tmp/DREAMBOOT > /dev/null 2>&1
   umount /tmp/dreambox-rootfs > /dev/null 2>&1
   umount /tmp/dreambox-data > /dev/null 2>&1
   umount /autofs/mmcblk1p1 > /dev/null 2>&1
   umount /autofs/mmcblk1p2 > /dev/null 2>&1
   umount /autofs/mmcblk1p3 > /dev/null 2>&1
   umount /media/mmcblk1p1 > /dev/null 2>&1
   umount /media/mmcblk1p2 > /dev/null 2>&1
   umount /media/mmcblk1p3 > /dev/null 2>&1
   umount /dev/mmcblk1p1 > /dev/null 2>&1
   umount /dev/mmcblk1p2 > /dev/null 2>&1
   umount /dev/mmcblk1p3 > /dev/null 2>&1
   if [ -e /var/lib/dpkg/status ]; then
      echo "stopping autofs"
      echo $LINE
      systemctl stop autofs
   fi
}

doDestroy() {
   rm $ERASETMP > /dev/null 2>&1
   touch $ERASETMP
   echo "destroying disklabel on sd-card"
   echo $LINE
   sgdisk -z /dev/mmcblk1
   partprobe /dev/mmcblk1
}

doFIP() {
   if [ -e /usr/share/amlogic-boot-bin/$DREAMBOX/fip.bin ]; then
      echo $LINE
      echo "adding FIP binary to sd-card"
      echo $LINE
      dd if=/usr/share/amlogic-boot-bin/$DREAMBOX/fip.bin of=/dev/mmcblk1 bs=512 count=8192
      partprobe /dev/mmcblk1
      echo $LINE
   fi
}

doFATPartition() {
   touch $ERASETMP
   echo "partitioning sd-card"
   echo $LINE
   echo "d" >> $ERASETMP
   echo "1" >> $ERASETMP
   echo "d" >> $ERASETMP
   echo "2" >> $ERASETMP
   echo "d" >> $ERASETMP
   echo "3" >> $ERASETMP
   echo "d" >> $ERASETMP
   echo "4" >> $ERASETMP
   # creating DREAMBOOT Partition
   echo "n" >> $ERASETMP
   echo "p" >> $ERASETMP
   echo "1" >> $ERASETMP
   echo "8192" >> $ERASETMP
   echo "73727" >> $ERASETMP
   # changing DREAMBOOT Partition to FAT
   echo "t" >> $ERASETMP
   echo "6" >> $ERASETMP
   echo "w" >> $ERASETMP
   #cat $ERASETMP
   fdisk -u -b 512 -S 512 < $ERASETMP /dev/mmcblk1 > /dev/null 2>&1 
   partprobe /dev/mmcblk1
   #
   # checking results
   #
   if [ -e /dev/mmcblk1 ]; then
      if [ ! -e /dev/mmcblk1p1 ]; then
         if [ -e /var/lib/opkg/status ]; then
            # bad idea ...
            mknod /dev/mmcblk1p1 b 179 129
         else
            echo "/dev/mmcblk1p1 not found - reboot without sd-card, insert and try again"
            echo $LINE                                                                
            dumboExit
         fi
      else
         echo "/dev/mmcblk1p1 exists"
         echo $LINE
      fi
   fi
}

doPartitions() {
   touch $ERASETMP
   echo "partitioning sd-card"
   echo $LINE
   echo "d" >> $ERASETMP
   echo "1" >> $ERASETMP
   echo "d" >> $ERASETMP
   echo "2" >> $ERASETMP
   echo "d" >> $ERASETMP
   echo "3" >> $ERASETMP
   echo "d" >> $ERASETMP
   echo "4" >> $ERASETMP
   # creating DREAMBOOT Partition
   echo "n" >> $ERASETMP
   echo "p" >> $ERASETMP
   echo "1" >> $ERASETMP
   echo "8192" >> $ERASETMP
   echo "73727" >> $ERASETMP
   # creating rootfs Partition
   echo "n" >> $ERASETMP
   echo "p" >> $ERASETMP
   echo "2" >> $ERASETMP
   echo "73728" >> $ERASETMP
   echo "8462335" >> $ERASETMP
   if $COPYDATA; then
      # creating data Partition
      echo "n" >> $ERASETMP
      echo "p" >> $ERASETMP
      echo "3" >> $ERASETMP
      echo "8462336" >> $ERASETMP
      echo "" >> $ERASETMP
   fi
   # changing DREAMBOOT Partition to FAT
   echo "t" >> $ERASETMP
   echo "1" >> $ERASETMP
   echo "6" >> $ERASETMP
   echo "w" >> $ERASETMP
   #cat $ERASETMP
   fdisk -u -b 512 -S 512 < $ERASETMP /dev/mmcblk1 > /dev/null 2>&1 
   partprobe /dev/mmcblk1
   #
   # checking results
   #
   if [ -e /dev/mmcblk1 ]; then
      if [ ! -e /dev/mmcblk1p1 ]; then
         if [ -e /var/lib/opkg/status ]; then
            # bad idea ...
            mknod /dev/mmcblk1p1 b 179 129
         else
            echo "/dev/mmcblk1p1 not found - reboot without sd-card, insert and try again"
            echo $LINE                                                                
            dumboExit
         fi
      else
         echo "/dev/mmcblk1p1 exists"
         echo $LINE
      fi
      if [ ! -e /dev/mmcblk1p2 ]; then
         if [ -e /var/lib/opkg/status ]; then
            # bad idea ...
            mknod /dev/mmcblk1p2 b 179 130
         else
            echo "/dev/mmcblk1p2 not found - reboot without sd-card, insert and try again"
            echo $LINE                                                                
            dumboExit
         fi
      else
         echo "/dev/mmcblk1p2 exists"
         echo $LINE
      fi
      if [ ! -e /dev/mmcblk1p3 ]; then
         if [ -e /var/lib/opkg/status ]; then
            # bad idea ...
            mknod /dev/mmcblk1p3 b 179 131
         else
            echo "/dev/mmcblk1p3 not found."
            echo $LINE                                                                
            # dumboExit
         fi
      else
         echo "/dev/mmcblk1p3 exists"
         echo $LINE
      fi
   fi
   umount /tmp/FLASH > /dev/null 2>&1
   umount /tmp/DREAMBOOT > /dev/null 2>&1
   umount /tmp/dreambox-rootfs > /dev/null 2>&1
   umount /tmp/dreambox-data > /dev/null 2>&1
   umount /media/mmcblk1p1 > /dev/null 2>&1
   umount /media/mmcblk1p2 > /dev/null 2>&1
   umount /media/mmcblk1p3 > /dev/null 2>&1
   umount /dev/mmcblk1p1 > /dev/null 2>&1
   umount /dev/mmcblk1p2 > /dev/null 2>&1
   umount /dev/mmcblk1p3 > /dev/null 2>&1
}

doFATFormat() {
   if [ `grep /dev/mmcblk1p1 /proc/mounts | grep /tmp/DREAMBOOT | wc -l` -gt 0 ]; then
      echo "WARNING: /dev/mmcblk1p1 formated as DREAMBOOT and MOUNTED"
      echo $LINE
   else
      echo $LINE
      echo "formating /dev/mmcblk1p1 as DREAMBOOT"
      echo $LINE
      umount /dev/mmcblk1p1 > /dev/null 2>&1
      umount /dev/mmcblk1p1 > /dev/null 2>&1
      mkfs.fat -F 16 -S 512 -v -n DREAMBOOT /dev/mmcblk1p1
      echo $LINE
      if [ ! -e /tmp/DREAMBOOT ]; then
         mkdir /tmp/DREAMBOOT
      fi
      echo "mounting /dev/mmcblk1p1 at /tmp/DREAMBOOT"
      echo $LINE
      mount /dev/mmcblk1p1 /tmp/DREAMBOOT
   fi
}

doRootfsFormat() {
   if [ `grep /dev/mmcblk1p2 /proc/mounts | grep /tmp/dreambox-rootfs | wc -l` -gt 0 ]; then
      echo "WARNING: /dev/mmcblk1p2 formated as dreambox-rootfs and MOUNTED"
      echo $LINE
   else
      echo "formating /dev/mmcblk1p2 as dreambox-rootfs"
      echo $LINE
      umount /dev/mmcblk1p2 > /dev/null 2>&1
      umount /dev/mmcblk1p2 > /dev/null 2>&1
      mkfs.ext4 -F -L dreambox-rootfs /dev/mmcblk1p2
      echo $LINE
      if [ ! -e /tmp/dreambox-rootfs ]; then
         mkdir /tmp/dreambox-rootfs
      fi
      echo "mounting /dev/mmcblk1p2 at /tmp/dreambox-rootfs"
      echo $LINE
      mount /dev/mmcblk1p2 /tmp/dreambox-rootfs
   fi
}


doDataFormat() {
   if [ `grep /dev/mmcblk1p3 /proc/mounts | grep /tmp/dreambox-data | wc -l` -gt 0 ]; then
      echo "WARNING: /dev/mmcblk1p3 formated as dreambox-data and MOUNTED"
      echo $LINE
   else
      echo "formating /dev/mmcblk1p3 as dreambox-data"
      echo $LINE
      umount /dev/mmcblk1p3 > /dev/null 2>&1
      umount /dev/mmcblk1p3 > /dev/null 2>&1
      mkfs.ext4 -F -L dreambox-data /dev/mmcblk1p3
      echo $LINE
      if [ ! -e /tmp/dreambox-data ]; then
         mkdir /tmp/dreambox-data
      fi
      echo "mounting /dev/mmcblk1p3 at /tmp/dreambox-data"
      echo $LINE
      mount /dev/mmcblk1p3 /tmp/dreambox-data
   fi
}

doExtract() {
   mount -o remount,async /tmp/DREAMBOOT
   mount -o remount,async /tmp/dreambox-rootfs
   mount -o remount,async /tmp/dreambox-data
   if $COPYFLASH; then
      echo "mounting Flash to /tmp/FLASH"
      echo $LINE
      mkdir /tmp/FLASH > /dev/null 2>&1
      mount -o bind / /tmp/FLASH > /dev/null 2>&1
      if [ `grep /tmp/FLASH /proc/mounts | wc -l` -eq 0 ]; then
         echo "ERROR: FLASH NOT mounted at /tmp/FLASH"
         echo $LINE
         dumboExit
      else
         echo "copying Flash to sd-card"
         echo "will take time ..."
         rm -r /tmp/dreambox-rootfs > /dev/null 2>&1
         cp -RP /tmp/FLASH/* /tmp/dreambox-rootfs 
         echo $LINE
      fi
   else
      echo "extracting to sd-card $IMAGE"
      echo "will take time ..."
      echo $LINE
      if [ -e $IMAGE ]; then
         if [ `grep /dev/mmcblk1p2 /proc/mounts | grep /tmp/dreambox-rootfs | wc -l` -eq 0 ]; then
            echo "ERROR: /dev/mmcblk1p2 NOT mounted at /tmp/dreambox-rootfs"
            echo $LINE
            dumboExit
         fi
         rm -r /tmp/dreambox-rootfs > /dev/null 2>&1
         $TAR $VERBOSE -f $IMAGE -C /tmp/dreambox-rootfs 
         echo $LINE
      else
         echo "NO *.tar.* Image found"
         echo $LINE
         dumboExit
      fi
   fi
   if [ `du -d 0 /tmp/dreambox-rootfs | cut -f 1` -gt 300000 ]; then
      echo "Dreambox Image extracted"
      echo $LINE
   else
      echo "Dreambox Image NOT extracted"
      echo $LINE
      dumboExit
   fi
}

doFAT() {
   if [ -e /tmp/dreambox-rootfs/boot/Image.gz-4.9 ]; then
      if [ `du  /tmp/dreambox-rootfs/boot/Image.gz-4.9 | cut -f 1` -gt 10000 ]; then
         echo "Kernel found in image"
         echo $LINE
      else
         echo "ERROR: Kernel NOT found in Image"
         echo $LINE
         dumboExit
      fi
      if [ -e /tmp/DREAMBOOT/kernel.img ]; then
         echo "WARNING: Kernel already found on sd-card"
         echo $LINE
      else
         echo "Flashing kernel to sd-card"
         echo $LINE
         mkbootimg --base 0 --kernel_offset 0x1080000 --second_offset 0x1000000 -o /tmp/DREAMBOOT/kernel.img --kernel /tmp/dreambox-rootfs/boot/Image.gz-4.9 --second /tmp/dreambox-rootfs/boot/$DREAMBOX.dtb --board one --cmdline "$CMDLINE"
      fi
   fi
   if [ -e /tmp/dreambox-rootfs/boot/$DREAMBOX.dtb  ]; then
      if [ -e /tmp/DREAMBOOT/$DREAMBOX.dtb ]; then
         echo "WARNING: $DREAMBOX.dtb already found on sd-card"
         echo $LINE
      else
         echo "$DREAMBOX.dtb copied to sd-card"
         echo $LINE
         cp /tmp/dreambox-rootfs/boot/$DREAMBOX.dtb /tmp/DREAMBOOT/$DREAMBOX.dtb
      fi
   else
      echo "ERROR: $DREAMBOX.dtb NOT found in image"
      echo $LINE
      dumboExit
   fi
   if [ -e /tmp/dreambox-rootfs/boot/bootlogo.bmp  ]; then
      if [ -e /tmp/DREAMBOOT/bootlogo.bmp ]; then
         echo "WARNING: bootlogo.bmp already found on sd-card"
         echo $LINE
      else
         echo "bootlogo.bmp copied to sd-card"
         echo $LINE
         cp /tmp/dreambox-rootfs/boot/bootlogo.bmp /tmp/DREAMBOOT/bootlogo.bmp
      fi
   else
      echo "ERROR: bootlogo.bmp NOT found in image"
      echo $LINE
      dumboExit
   fi
   # for later usage
   if [ -e /tmp/dreambox-rootfs/usr/share/u-boot-bin/$DREAMBOX/u-boot.bin  ]; then
      if [ -e /tmp/DREAMBOOT/u-boot.bin ]; then
         echo "WARNING: u-boot.bin already found on sd-card"
         echo $LINE
      else
         echo "u-boot.bin copied to sd-card"
         echo $LINE
         cp /tmp/dreambox-rootfs/usr/share/u-boot-bin/$DREAMBOX/u-boot.bin /tmp/DREAMBOOT/u-boot.bin
      fi
   else
      echo "INFO: u-boot.bin NOT found in image"
      echo $LINE
   fi
}


checkRescueImage () {
   echo "checking rescue-image"
   echo $LINE
   if checkAIO  &>/dev/null; then
      echo -e "AIO Image in Flash!"
   else
      echo -e "NO AIO Image in Flash"
   fi 
   if [ $PARTITION_SIZE -eq 114688 ];then
      echo "GPT in Flash"
   else
	  echo "NO GPT in Flash"
   fi
   echo "checking rescue-image"
   echo $LINE
   
   # check for rescue-image #106 in /data/dumbo
   if [ -e $DUMBO/dreambox-rescue-image-dreambox*.bootimg ]; then
      echo "found rescue-image #106 in $DUMBO"
   # check for rescue-image #106 in /usr/share/rescue-image/dreambox	  
   elif [ -e /usr/share/rescue-image/dreambox/dreambox-rescue-image-dreambox*.bootimg ]; then
      echo -e "rescue-image #106 already installed\ncopy $(cd /usr/share/rescue-image/dreambox/ && ls -1 dreambox-rescue-image-dreambox*.bootimg|tail -n 1) to $DUMBO"
      cp -RP /usr/share/rescue-image/dreambox/dreambox-rescue-image-dreambox-*.bootimg $DUMBO/
   # check for rescue-image #106 on https://repo.fury.io/aio/ - only available if an AIO Image is in Flash
   elif grep -qs "https://repo.fury.io/aio/" /etc/apt/sources.list.d/* ;then
      echo -e "gutemine's aio repository found in apt source lists"
	  # prevents to build an emergency repair sd-card with no AIO in Flash and added gutemine's aio repo
      if ! checkAIO  &>/dev/null; then
         echo -e "\033[1;31mthere is no business for gutemine's aio repo in this Image!!\nboot an AIO Image to build an emergency repair sd-card with\nrescue-image #106\n\e[0m"
		 dumboExit
      fi
      echo "try to download rescue-image #106"
	  echo -e "\033[1;33mINFORMATION:\e[0m rescue-image #106 will NOT be installed!\nplease wait ..."
	  echo "extract rescue-image #106"
      [ ! -d /tmp/.rescue-image ] && mkdir -p /tmp/.rescue-image
      cd /tmp/.rescue-image
      apt-get update &>/dev/null
      apt-get download rescue-image &>/dev/null
	  if [ -e /tmp/.rescue-image/rescue-image_106*_arm64.deb ]; then
         dpkg-deb -x /tmp/.rescue-image/rescue-image_106*_arm64.deb /tmp/.rescue-image/ &>/dev/null
         echo "move rescue-image #106 to $DUMBO"
		 mv /tmp/.rescue-image/usr/share/rescue-image/dreambox/dreambox-rescue-image-dreambox-20230508.bootimg $DUMBO &>/dev/null
		 echo "clean up"
         rm -rf /tmp/.rescue-image &>/dev/null
		 if [ ! -e $DUMBO/dreambox-rescue-image-dreambox*.bootimg ]; then 
		    echo "download rescue-image #106 failed"
	     fi
      else
         echo "download rescue-image #106 failed"
      fi
   elif [ $PARTITION_SIZE -eq 114688 -a $EMERGENCY == true ] ; then
      echo -e "rescue-image #106 is required but was not found!"
	  if checkAIO  &>/dev/null; then
         echo -e "gutemine's aio repository was not found in apt source lists\nadd gutemine's aio repository do install rescue-image #106"
	  else
	     echo -e "boot an AIO Image and install or download rescue-image #106 to build\nan emergency repair sd-card for use with GPT in Flash"
	  fi
	  echo $LINE
	  echo -en "\033[1;31mrescue-image check not passed!\e[0m\n\n"
	  dumboExit
  # check for rescue-image 104 for dreamone or dreamtwo in $DUMBO
   elif [ -e $DUMBO/dreambox-rescue-image-${DREAMBOX}*.bootimg ]; then
      echo "found rescue-image #104 in $DUMBO"   
  # check for rescue-image for dreamone or dreamtwo in /usr/share/rescue-image/${DREAMBOX}/
   elif [ -e /usr/share/rescue-image/${DREAMBOX}/dreambox-rescue-image-${DREAMBOX}*.bootimg ]; then
      echo -e "found found rescue-loader #104 in Flash\ncopy $(cd /usr/share/rescue-image/${DREAMBOX} && ls -1 dreambox-rescue-image-${DREAMBOX}*.bootimg|tail -n 1) to $DUMBO"
      cp -RP /usr/share/rescue-image/${DREAMBOX}/dreambox-rescue-image-${DREAMBOX}*.bootimg $DUMBO/
  # try to download rescue image 104 for dreamone or dreamtwo from http://www.download.blue-panel.com using wget
   elif  wget http://download.blue-panel.com/opendreambox/2.6/unstable/images/${DREAMBOX}/dreambox-rescue-image-${DREAMBOX}-20211029.bootimg --quiet --spider;then
      echo -e "rescue-loader #104 not found\ntry to download rescue-loader #104 from download.blue-panel.com"
      wget http://download.blue-panel.com/opendreambox/2.6/unstable/images/${DREAMBOX}/dreambox-rescue-image-${DREAMBOX}-20211029.bootimg -qO $DUMBO/dreambox-rescue-image-${DREAMBOX}-20211029.bootimg
      echo "download successfull"
  # try to download rescue image 104 for dreamone or dreamtwo from https://www.opendreambox.com using wget
   elif wget http://www.opendreambox.com/opendreambox/2.6/unstable/images/${DREAMBOX}/dreambox-rescue-image-${DREAMBOX}-20211029.bootimg --quiet --spider;then
      echo -e "rescue-loader #104 not found\ntry to download rescue-loader #104 from www.opendreambox.com"
      wget http://www.opendreambox.com/opendreambox/2.6/unstable/images/${DREAMBOX}/dreambox-rescue-image-${DREAMBOX}-20211029.bootimg -qO $DUMBO/dreambox-rescue-image-${DREAMBOX}-20211029.bootimg
      echo "download successfull"	  
   fi
  
   if [ $PARTITION_SIZE -eq 114688 -a $EMERGENCY == true ] ; then
      if [ -e $DUMBO/dreambox-rescue-image-dreambox*.bootimg ]; then
	     echo $LINE
         echo "rescue-image check #106 passed"
		 # prevents to build an emergency repair sd-card with no AIO in Flash with rescue-image #106 and useless no AIO u-boot.bin if GPT in Flash
		 if ! checkAIO &>/dev/null; then
		    echo -e "\n\033[1;31mERROR!\nthis will build an emergency repair sd-card with rescue-image #106\nWITHOUT latest u-boot.bin in Flash (no AIO Image)\nthis emergency repair sd-card will be useless with GPT in flash!\nboot an AIO Image to build an emergency repair sd-card with\nrescue-image #106 for GPT in Flash!\n\e[0m\n"
			dumboExit
	     fi				 
	  else
		 echo $LINE
         echo -e "\033[1;31mrescue-image check not passed!\e[0m\n"
		 echo dumboExit	
      fi
   fi
   
   if [ $PARTITION_SIZE == 114688 -a $RESCUE == true ]; then
      if [ -e $DUMBO/dreambox-rescue-image-dreambox*.bootimg ]; then
	     echo $LINE 
		 echo -e "rescue-image check #106 passed!"
	  elif [ -e $DUMBO/dreambox-rescue-image-${DREAMBOX}*.bootimg ]; then
         echo $LINE
         echo -e "rescue-image check #106 not passed!"
         if checkAIO &> /dev/null;then
	        echo -e "gutemine's aio repository was not found in apt source lists\nadd gutemine's aio repository do install rescue-image #106"
		 fi
         echo -e "rescue-image check #104 passed\n"
         echo -e "\033[1;33mPlease note: a rescue-image sd-card build with rescue-image #106 is\nrecommended with GPT in flash!\e[0m\n"
         echo -en "continue? (yes/no) "
         read -sn 1 ANSWER
		 case $ANSWER in
		    y|Y) echo -ne "\ncontinue with rescue-image #104\n";;
		      *) echo -e "\n\nbuild rescue-image sd-card with rescue-image #104 terminated\n";dumboExit;;
	     esac
      else
	     echo -e "rescue-image #106 not found!"
	     if checkAIO &> /dev/null;then
	        echo -e "gutemine's aio repository was not found in apt source lists\nadd gutemine's aio repository do install rescue-image #106"
		 fi
		 echo -e "rescue-image #104 not found!"
		 echo -e "download from https://download.blue-panel.com failed!"
		 echo -e "download from http://www.dopendreambox.com failed!"
		 echo $LINE
		 echo -e "\033[1;31mrescue-image check not passed!\e[0m\n"	
		 dumboExit   	
		 exit 
      fi
    fi    
		 
   if [ $PARTITION_SIZE -ne 114688 ]; then
      if [ -e $DUMBO/dreambox-rescue-image-dreambox*.bootimg ]; then
	     echo $LINE
         echo "rescue-image check #106 passed"
      elif [ -e $DUMBO/dreambox-rescue-image-${DREAMBOX}*.bootimg ]; then
	     echo $LINE
         echo "rescue-image check #104 passed"
	  else
	    echo -e "rescue-image #106 not found!"
		if checkAIO &> /dev/null;then
		   echo -e "gutemine's aio repository was not found in apt source lists\nadd gutemine's aio repository do install rescue-image #106!"
		fi
		echo -e "rescue-image #104 not found!"
		echo -e "download from https://download.blue-panel.com failed!"
		echo -e "download from http://www.dopendreambox.com failed!"
		echo $LINE
		echo -e "\033[1;31mrescue-image check not passed!\e[0m\n"
		dumboExit
	  fi
   fi
}

copyRescueImageToDREAMBOOT () {
   if [ -e $DUMBO/dreambox-rescue-image-dreambox*.bootimg ]; then
      echo "copying AIO Rescue Image 106 to FAT"
      echo $LINE
      cp $DUMBO/dreambox-rescue-image-dreambox*.bootimg /tmp/DREAMBOOT/rescue.bootimg
   else
      if [ $DREAMBOX == "dreamone" ]; then
         echo "copying dreamone Rescue Image 104 to FAT"
         echo $LINE
         cp $DUMBO/dreambox-rescue-image-dreamone*.bootimg /tmp/DREAMBOOT/rescue.bootimg
      fi
      if [ $DREAMBOX == "dreamtwo" ]; then
         echo "copying dreamtwo Rescue Image 104 to FAT"
         echo $LINE
         cp $DUMBO/dreambox-rescue-image-dreamtwo*.bootimg /tmp/DREAMBOOT/rescue.bootimg
      fi
   fi
}

copyDtbToDREAMBOOT () {
   if [ -e /boot/$DREAMBOX.dtb  ]; then
      if [ -e /tmp/DREAMBOOT/$DREAMBOX.dtb ]; then
         echo "WARNING: $DREAMBOX.dtb already found on sd-card"
         echo $LINE
      else
         echo "$DREAMBOX.dtb copied to sd-card"
         echo $LINE
         cp /boot/$DREAMBOX.dtb /tmp/DREAMBOOT/$DREAMBOX.dtb
      fi
   else
      echo "ERROR: $DREAMBOX.dtb NOT found in Flash"
      echo $LINE
      dumboExit
   fi
}


doRescue() {
   echo "creating Rescue loader sd-card"
   echo $LINE
   echo "!!! USE WITH CARE, THIS IS NOT ASPIRIN !!!"
   echo $LINE

   checkRescueImage
   checkDtb

   doUmount
   doDestroy
   # NOT sure if this is here a good idea !
   #checkFIP
   doFIP 
   doFATPartition
   doFATFormat

   copyRescueImageToDREAMBOOT
   copyDtbToDREAMBOOT

   echo "creating autoexec.img for rescue sd-card"
   echo $LINE
   echo "fatload mmc 0:1 \${dtb_mem_addr} $DREAMBOX.dtb" >> $DUMBOTMP/autoexec
   echo "setenv bootcmd \"fatload mmc 0:1 \${loadaddr} rescue.bootimg; bootm;\"" >> $DUMBOTMP/autoexec
   cat $DUMBOTMP/autoexec
   echo $LINE
   mkimage -A arm64 -O linux -T script -C none -n autoexec -d $DUMBOTMP/autoexec $DUMBOTMP/autoexec.img
   rm $DUMBOTMP/autoexec > /dev/null 2>&1
   if [ -e $DUMBOTMP/autoexec.img ]; then
      echo "copying autoexec.img to rescue sd-card"
      echo $LINE
      cp $DUMBOTMP/autoexec.img /tmp/DREAMBOOT/autoexec.img
      rm $DUMBOTMP/autoexec.img > /dev/null 2>&1
   else
      echo "ERROR: creating rescue autoexec.img failed"
      echo $LINE
      dumboExit
   fi
   showResult
   doFinish
}


doEmergency() {
   echo "creating Emergency Repair sd-card"
   echo $LINE
   echo "!!! USE WITH CARE, THIS IS NOT ASPIRIN !!!"
   echo $LINE

   checkRescueImage
   checkDtb

   doUmount
   doDestroy
   doFIP 
   doFATPartition
   doFATFormat

   copyRescueImageToDREAMBOOT
   copyDtbToDREAMBOOT


   if [ -e /usr/share/u-boot-bin/$DREAMBOX/u-boot.bin  ]; then
      if [ -e /tmp/DREAMBOOT/u-boot.bin ]; then
         echo "WARNING: u-boot.bin already found on sd-card"
         echo $LINE
      else
         echo "u-boot.bin copied to sd-card"
         echo $LINE
         cp /usr/share/u-boot-bin/$DREAMBOX/u-boot.bin /tmp/DREAMBOOT/u-boot.bin
      fi
   else
      echo "ERROR: u-boot.bin NOT found in image"
      echo "for emergency sd-card an AIO Image should be in Flash"
      echo "to have the LATEST u-boot.bin !!!"
      echo $LINE
      dumboExit
   fi

   echo "creating autoexec.img for emergency sd-card"
   echo $LINE
   if $EXECUTE; then
      echo "wtih automatic execution of commands"
      echo "!!!!! THINK TWICE IF YOU REALLY WANT THAT !!!!!"
   fi
   echo "" >> $DUMBOTMP/autoexec 
   echo "################ Device-Tree RECOVERY ######################" >> $DUMBOTMP/autoexec
   echo "echo 'copy dtb to ram'" >> $DUMBOTMP/autoexec
   echo "echo 'fatload mmc 0 \${dtb_mem_addr} $DREAMBOX.dtb'" >> $DUMBOTMP/autoexec
   if $EXECUTE; then
         echo "fatload mmc 0 \${dtb_mem_addr} $DREAMBOX.dtb" >> $DUMBOTMP/autoexec
   fi
   echo "echo 'write dtb from ram to emmc'" >> $DUMBOTMP/autoexec
   echo "echo 'store dtb write \${dtb_mem_addr}'" >> $DUMBOTMP/autoexec
   if $EXECUTE; then
         echo "store dtb write \${dtb_mem_addr}" >> $DUMBOTMP/autoexec
   fi
   echo "################ Bootloader RECOVERY #######################" >> $DUMBOTMP/autoexec
   echo "echo 'copy u-boot to ram'" >> $DUMBOTMP/autoexec
   echo "echo 'fatload mmc 0 \${loadaddr} u-boot.bin'" >> $DUMBOTMP/autoexec
   if $EXECUTE; then
         echo "fatload mmc 0 \${loadaddr} u-boot.bin" >> $DUMBOTMP/autoexec
   fi
   echo "echo 'write u-boot from ram to emmc'" >> $DUMBOTMP/autoexec
   echo "echo 'amlmmc write bootloader \${loadaddr} 0 \${filesize}'" >> $DUMBOTMP/autoexec
   if $EXECUTE; then
         echo "amlmmc write bootloader \${loadaddr} 0 \${filesize}" >> $DUMBOTMP/autoexec
   fi
   echo "################ Rescue Image RECOVERY #####################" >> $DUMBOTMP/autoexec
   echo "echo 'copy rescue image to ram'" >> $DUMBOTMP/autoexec
   echo "echo 'fatload mmc 0 \${loadaddr} rescue.bootimg'" >> $DUMBOTMP/autoexec
   if $EXECUTE; then
         echo "fatload mmc 0 \${loadaddr} rescue.bootimg" >> $DUMBOTMP/autoexec
   fi
   echo "echo 'write rescue image from ram to emmc'" >> $DUMBOTMP/autoexec
   echo "echo 'amlmmc write recovery \${loadaddr} 0 \${filesize}'" >> $DUMBOTMP/autoexec
   if $EXECUTE; then
         echo "amlmmc write recovery \${loadaddr} 0 \${filesize}" >> $DUMBOTMP/autoexec
   fi
   echo $LINE
   cat $DUMBOTMP/autoexec
   echo $LINE
   mkimage -A arm64 -O linux -T script -C none -n autoexec -d $DUMBOTMP/autoexec $DUMBOTMP/autoexec.img
   rm $DUMBOTMP/autoexec > /dev/null 2>&1
   if [ -e $DUMBOTMP/autoexec.img ]; then
      echo "copying autoexec.img to emergency sd-card"
      echo $LINE
      cp $DUMBOTMP/autoexec.img /tmp/DREAMBOOT/autoexec.img
      rm $DUMBOTMP/autoexec.img > /dev/null 2>&1
   else
      echo "ERROR: creating emergency autoexec.img failed"
      echo $LINE
      dumboExit
   fi
   showResult
   doFinish
}

showAutoexec() {
   echo $LINE
   if [ -e /tmp/DREAMBOOT/autoexec.img ]; then
      strings /tmp/DREAMBOOT/autoexec.img
      echo $LINE
      if [ `grep boot_from_flash /tmp/DREAMBOOT/autoexec.img | wc -l` -gt 0 ]; then
         echo "Flash will be booted from sd-card"
      else
         echo "Image will be booted from sd-card"
      fi
      echo $LINE
   fi
}

doAutoexec() {
   echo "create autoexec.img for $BOOTDEVICE"
   echo $LINE
   #
   # below code comes from update-autoexec
   #
   source librecovery
   create_workspace
   LC_ALL=C grep -h ^[a-zA-Z0-9] /etc/u-boot.scr.d/*.scr > $DUMBOTMP/autoexec 2>/dev/null || true
   if [ -e $DUMBOTMP/autoexec ]; then
      if [ $BOOTDEVICE == "sd" ]; then 
         echo "adapting autoexec.img for booting from sd-card"
         sed -i "s/mmc 1:6/mmc 0:1/g" $DUMBOTMP/autoexec
         sed -i "s/\/boot\/bootlogo.bmp/bootlogo.bmp/g" $DUMBOTMP/autoexec
         sed -i "s/ext4load/fatload/g" $DUMBOTMP/autoexec
         echo "fatload mmc 0:1 \${dtb_mem_addr} $DREAMBOX.dtb" >> $DUMBOTMP/autoexec
         echo "setenv bootcmd \"fatload mmc 0:1 \${loadaddr} kernel.img; bootm;\"" >> $DUMBOTMP/autoexec
      else
         PARTITION_SIZE=`cat /proc/partitions | grep mmcblk0p1 | awk '{print $3}'`
         if [ ${PARTITION_SIZE} -eq 114688 ]; then 
            echo "adapting autoexec.img for booting with GPT from Flash"
            sed -i "s/mmc 1:6/mmc 1:5/g" $DUMBOTMP/autoexec                           
            echo "setenv bootcmd \"ext4load mmc 1:5 \${loadaddr} /boot/kernel.img; bootm;\"" >> $DUMBOTMP/autoexec 
         else
            echo "keeping autoexec.img for booting from Flash"
        echo "setenv bootcmd \"run boot_from_flash; bootm;\"" >> $DUMBOTMP/autoexec
         fi
      fi
      echo $LINE
      cat $DUMBOTMP/autoexec
      echo $LINE
      mkimage -A arm64 -O linux -T script -C none -n autoexec -d $DUMBOTMP/autoexec $DUMBOTMP/autoexec.img
      rm $DUMBOTMP/autoexec > /dev/null 2>&1
      if [ -e $DUMBOTMP/autoexec.img ]; then
         echo "copying autoexec.img to sd-card"
         echo $LINE
         cp $DUMBOTMP/autoexec.img /tmp/DREAMBOOT/autoexec.img
         rm $DUMBOTMP/autoexec.img > /dev/null 2>&1
      else
         echo "ERROR: creating autoexec.img failed"
         echo $LINE
         dumboExit
      fi
   else
      echo "ERROR: failed generating autoexec"
      echo $LINE
      dumboExit
   fi
}

showResult() {
   if [ `grep /dev/mmcblk1p1 /proc/mounts | grep /tmp/DREAMBOOT | wc -l` -gt 0 ]; then
      echo "content of FAT on sd-card"
      echo $LINE
      ls -alh /tmp/DREAMBOOT
      echo $LINE
   fi
   if  [ -e /dev/mmcblk1 ]; then
      echo "partitions on sd-card"
      #fdisk -u -l /dev/mmcblk1
      parted /dev/mmcblk1 print
      echo $LINE
   fi
}

doSpreading() {
   if [ ! -e /tmp/dreambox-data/dumbo ]; then
      mkdir /tmp/dreambox-data/dumbo 
   fi
   if [ ! -e /tmp/dreambox-data/dumbo/dumbo.sh ]; then
      echo "spreading dumbo.sh to sd-card, to be able"
      echo "to use dumbo.sh -b flash when booted from sd-card"
      echo $LINE
      cp $DUMBO/dumbo.sh /tmp/dreambox-data/dumbo/dumbo.sh
   fi
   if $PASSWD; then
      echo "spreading password file to sd-card"
      echo $LINE
      cp /etc/passwd /tmp/dreambox-rootfs/etc/passwd
      cp /etc/shadow /tmp/dreambox-rootfs/etc/shadow
   fi
   if $COPYDATA; then
      if showData; then
         echo "WARNING: data partition already mounted, skipping copying Flash data to sd-card"
         echo $LINE
      else
         echo "INFO: copying Flash data partition content to sd-card"
         echo $LINE
         cp -RP /data/* /tmp/dreambox-data
      fi 
   fi
}

doFinish() {
   sync
   sync
   umount /tmp/FLASH > /dev/null 2>&1
   umount /tmp/DREAMBOOT > /dev/null 2>&1
   umount /tmp/dreambox-rootfs > /dev/null 2>&1
   umount /tmp/dreambox-data > /dev/null 2>&1
   umount /media/mmcblk1p1 > /dev/null 2>&1
   umount /media/mmcblk1p2 > /dev/null 2>&1
   umount /media/mmcblk1p3 > /dev/null 2>&1
   umount /dev/mmcblk1p1 > /dev/null 2>&1
   umount /dev/mmcblk1p2 > /dev/null 2>&1
   umount /dev/mmcblk1p3 > /dev/null 2>&1
   if [ -e /var/lib/dpkg/status ]; then
      if [ `systemctl status autofs | grep inactive | wc -l` -gt 0 ]; then
         echo "starting autofs"
         echo $LINE
         systemctl start autofs
      fi
   fi
}

#
# check command line arguments
#
if [ -z $1 ]; then
    HELP=true
fi
while [ $# -gt 0 ] ; do
    case $1 in	
        -i | -image | --i | --image)
           IMAGENAME="$2"
           ;;
        -m | -model | --m | --model)
           DREAMBOX="$2"
           ;;
        -b | -boot | --b | --boot)
           BOOTDEVICE="$2"
           ;;
        -h | -help | --h | --help)
           HELP=true
           ;;
        -p | -pass | --p | --pass)
           PASSWD=true
           ;;
        -s | -show | --s | --show)
           SHOWDEVICE=true
           ;;
        -d | -data | --d | --data)
           COPYDATA=true
           ;;
        -c | -copy | --c | --copy)
           COPYFLASH=true
           ;;
        -r | -rescue | --r | --rescue)
           RESCUE=true
           ;;
        -e | -emergency | --e | --emergency)
           EMERGENCY=true
           ;;
        -a | -auto | --a | --auto)
           EXECUTE=true
           ;;
        -f | -force | --f | --force)
           FORCE=true
           ;;
        -v | -verbose | --v | --verbose)
           VERBOSE="-v"
           ;;
    esac
    shift
done

if ! getModel; then
   dumboExit
fi

setCmdLine

if [ -z $BOOTDEVICE ]; then
   BOOTDEVICE="sd"
else
   showHeader
   if ! checkSD; then
      dumboExit
   fi
   if [ $BOOTDEVICE != "sd" -a $BOOTDEVICE != "flash" ]; then
      echo "'$BOOTDEVICE' is not a valid bootdevice option - only 'sd' or 'flash' accept"
      echo $LINE
      showUsage
      dumboExit
   else
      echo "changing bootdevice to $BOOTDEVICE"
      echo $LINE
      if checkFAT; then
         doAutoexec
         showResult
         doFinish
      fi
      dumboExit
   fi
fi

#
# here comes the main action ...
#

showHeader

addCommand

if $EMERGENCY; then
   if $RESCUE; then
      echo "-e and -r are conflicting, use only one!"
      echo $LINE
      dumboExit
   fi
fi

if $HELP; then
   showUsage
   dumboExit
fi

if  $SHOWDEVICE; then
   showDevice
   if checkFAT; then
       showAutoexec
   fi
   showResult
   doFinish
   dumboExit
fi

if ! checkSD; then
   dumboExit
fi

checkBinaries

doCleanup

checkGPT

checkAIO

if showBooted; then
   dumboExit
else
   showData
fi

if $RESCUE; then
   doRescue
   dumboExit
fi

if $EMERGENCY; then
   doEmergency
   dumboExit
fi

if [ ! -z $VERBOSE ]; then
   showVerbose
fi

if getImage; then
   doUmount
   doDestroy
   doFIP 
   doPartitions
   doFATFormat
   doRootfsFormat
   doDataFormat
   doExtract
   doFAT
   if checkFAT; then
      doAutoexec
      doSpreading
      showResult
      doFinish
      echo "sd-card Image creation finished"
      echo $LINE
   fi
fi
#
# Done, see you next time, but why did it take you so long to show up ?
#
