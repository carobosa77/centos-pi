# CentOS on a Raspberry Pi

This project includes the scripts used to install and configure CentOS on a Raspberry Pi.

- The [install](https://github.com/carobosa77/centos-pi/install) directory contains the scripts used to install CentOS to the Raspberry Pi itself, including the option of creating partitions during the process.

- The [centos](https://github.com/carobosa77/centos-pi/centos) directory contains the scripts used to configure CentOS on the Raspberry Pi.

The steps realized in another computer (not the Raspberry Pi itself) are:

0) Generate the SSH keys to identify yourself: `ssh-keygen`. This is done only the first time, no need to regenerate the keys every time the Raspberry Pi is reinstalled.

1) Install CentOS to the Raspberry Pi ([install](https://github.com/carobosa77/centos-pi/install) directory). Plug the SSD card and boot. The first time it boots, will last a few minutes, because it has to rebuild the SELINUX information.

2) Copy the public key to the Raspberry Pi: `ssh-copy-id root@raspberry-pi` (use the IP instead).

3) Connect to the Raspberry Pi: `ssh root@raspberry-pi` (use the IP instead).

The steps realized in the Raspberry Pi itself (via SSH) are:

4) Copy/sftp/git or download the centos-pi github's project to the Raspberry Pi.

5) Execute the configuration scripts from the [centos](https://github.com/carobosa77/centos-pi/centos) directory.

