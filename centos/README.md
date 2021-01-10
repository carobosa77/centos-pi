# CentOS on a Raspberry Pi

This folder (https://github.com/carobosa77/centos-pi/centos) includes the scripts used to configure CentOS on a Raspberry Pi.

- The `centos/do_actions.env` script includes every auxiliary bash function used for the installation and the configuration processes. Every function in the script is self documented.

These steps are realized in the Raspberry Pi itself:

0) Install the EPEL repository: `dnf install epel-release`; and update your OS: `dnf update`.

1) Install all the packages that will be needed: `bash do_actions.env do_dnf_install $( grep do_dnf_install *.bash | cut -d' ' -f2- | tr '\n' ' ' )`

2) Check that the files which will be modified did not change after the script was developed: `find backup/ -type f | while read FILE; do diff --brief ${FILE} /${FILE#*/}; done`.

3) CentOS for Raspberry Pi has certain peculiarities that I consider appropriate to modify. See the `raspberry-pi.bash` script for more details.

4) At this time, a MTA is useful to receive the generated mail as notifications of the processes to be configured later. Run: `mail.bash`

5) Harden your CentOS installation: `harden.bash`. Note: This script only applies the appropriate measures for a lone machine.

6) Realize final actions: `final.bash`. This scripts contains the last steps indicated by the previous scripts, to finalize them.

Other checks:

- Enabled services
    systemctl list-units -t service
    netstat -tulpn
    ss -tulpn
    nmap -sT -O 192.168.1.10

- Installed packages
    rpm -qa
    yum list installed

- File attributes
    find /  -path /proc -prune -o -type f \( -perm -4000 -o -perm -2000 \) -exec ls -l {} \;
    find / -nouser -o -nogroup -exec ls -l {} \;
    find / -path /proc -prune -o -perm -2 ! -type l –ls

