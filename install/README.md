# Installation scripts

This directory contains the scripts used to install CentOS to the Raspberry Pi itself, including the option of creating partitions during the process.

The following scripts are provided:

## dd.bash

This script writes the indicated image content into a SD card.

To write the image to the SD card, use the following command, assuming that `2020-02-13-raspbian-buster-full.zip` is the image filename and `/dev/mmcblk0` is the device for the target SD card:

    sudo bash dd.bash 2020-02-13-raspbian-buster-full.zip /dev/mmcblk0

The script performs the following actions:

 1. Umounts the partitions of the device indicated, if mounted.

 2. Uncompresses the image, if `xz`, `gz` or `zip`.

 3. Writes the image to the device, while shows the progress.

## ping.bash

This script searches for computers in your network.

To search a Raspberry Pi with CentOS in the network, use the following command:

    bash ping.bash -p 22 -n 29 192.168.1.128

The script will search all computers with ping in `192.168.1.128/29` (`192.168.1.128` to `192.168.1.135`) that have port `22` (SSH) open.

## dd_partitions.env

This script includes the auxiliary processes to write the image content into a SD card, with partitions.

This script should be invoked from a file or environment with the proper configuration.

The following scripts define the settings to write some distributions to the SD card, with partitions. Must be executed by the root user. Before using them, the corresponding image should be downloaded.

- The script **`CentOS-Userland-7-armv7hl-generic-Minimal-1908-sda.bash`** writes [CentOS 7](http://isoredirect.centos.org/altarch/7/isos/armhfp/).

- The script **`CentOS-Userland-8-armv7hl-generic-Minimal-1911-sda.bash`** writes [CentOS 8](http://isoredirect.centos.org/altarch/8/isos/armhfp/).

The process performs the following actions:

 1. Performs some basic validations to the environment variables.

 2. Asks for confirmation before writing, unless `FORCED=true` indicated.

 3. Extracts and makes a copy of the source image in a temporary directory; and mounts the copy.

 4. Umounts the partitions of the device indicated, if mounted.

 5. Creates the partitions in the target device, and format them. The UUIDs and LABELs should be preserved, when possible, to avoid errors.

 6. Builds the new `fstab` file, replacing the device names with their corresponding UUID.

 7. Moves the files from the copy of the image to the target partition. Unmounts the partitions of the image copy as they become empty.

 8. Finally, deletes the temporary directory.

**About LVM**: When creating this scripts, lvm was not available in the CentOS image for Raspberry Pi.
