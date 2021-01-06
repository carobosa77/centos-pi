#!/bin/bash

source do_actions.env

MAILTO=root@localhost

# psacct - Kernel process accounting

do_dnf_install psacct

systemctl enable psacct.service
systemctl start psacct.service

# Secure SSH server

# s/^PasswordAuthentication yes$/PasswordAuthentication no/
do_file_sed '
  s/^#LogLevel INFO$/LogLevel INFO/
  s/^PermitRootLogin yes$/PermitRootLogin prohibit-password/
  s/^#MaxAuthTries 6$/MaxAuthTries 2/
  s/^#PermitEmptyPasswords no$/PermitEmptyPasswords no/
  s/^X11Forwarding yes$/X11Forwarding no/' /etc/ssh/sshd_config

systemctl restart sshd.service

# Apply Strong Password Policy

# do_file_append /etc/pam.d/passwd << EOD
# password required pam_pwquality.so retry=3
# EOD

# do_file_append /etc/security/pwquality.conf << EOD
# minlen = 8
# minclass = 4
# maxsequence = 3
# maxrepeat = 3
# EOD

# Hardening /etc/sysctl.conf

# if ! [ -f /etc/sysctl.d/99-centos-pi.conf ]; then
#   cat > /etc/sysctl.d/99-centos-pi.conf << EOF
# net.ipv4.conf.all.accept_source_route=0
# ipv4.conf.all.forwarding=0
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
# net.ipv6.conf.lo.disable_ipv6 = 1
# net.ipv4.conf.all.accept_redirects=0
# net.ipv4.conf.all.secure_redirects=0
# net.ipv4.conf.all.send_redirects=0
# net.ipv4.conf.all.rp_filter=2
# net.ipv4.icmp_echo_ignore_all = 0
# EOF
#   chmod 644 /etc/sysctl.d/99-centos-pi.conf
#   chown root.root /etc/sysctl.d/99-centos-pi.conf
# fi

# Automatic updates: dnf-automatic

do_dnf_install dnf-automatic

do_file_sed 's/^apply_updates = no$/apply_updates = yes/' /etc/dnf/automatic.conf

systemctl enable dnf-automatic.timer
systemctl start dnf-automatic.timer

# INP: Fail2ban

do_dnf_install epel-release
do_dnf_install fail2ban

systemctl enable fail2ban.service
systemctl start fail2ban.service

# AIDE - Advanced Intrusion Detection Environment

do_dnf_install aide

if [ ! -e /etc/cron.weekly/aide ]; then
  cat > /etc/cron.weekly/aide << EOF
#!/bin/sh

/usr/sbin/aide --init | mail $MAILTO -saide\ weekly
FILENAME=/var/lib/aide/aide.db.$( date +%F_%T ).gz
cp /var/lib/aide/aide.db.new.gz $FILENAME
# chattr +i $FILENAME
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
EOF

  chmod ugo+x /etc/cron.weekly/aide
fi

if [ ! -e /etc/cron.daily/aide ]; then
  cat > /etc/cron.daily/aide << EOF
#!/bin/sh

/usr/sbin/aide --check | mail $MAILTO -saide\ daily
EOF

  chmod ugo+x /etc/cron.daily/aide
fi

# Rootkit Scanner: Rkhunter

do_dnf_install epel-release
do_dnf_install rkhunter

# Antivirus Scanner: ClamAV (https://www.adminbyaccident.com/gnu-linux/how-to-install-the-clamav-antivirus-on-centos-8/)

do_dnf_install clamav clamav-update clamd

setsebool -P antivirus_can_scan_system 1

freshclam
systemctl enable clamav-freshclam.service
systemctl start clamav-freshclam.service

do_file_sed '
  s/^#LocalSocket \/run\/clamd.scan\/clamd.sock$/LocalSocket \/run\/clamd.scan\/clamd.sock/
  s/^#OnAccessIncludePath \/home$/OnAccessIncludePath \/home/
  s/^#OnAccessPrevention yes$/OnAccessPrevention yes/
  s/^#OnAccessExcludeUname clamav$/OnAccessExcludeUname clamscan/' /etc/clamd.d/scan.conf

do_file_sed '
  s/^Description = clamd scanner (%i) daemon$/Description = clamd scanner daemon/
  s/^ExecStart = \/usr\/sbin\/clamd -c \/etc\/clamd.d\/%i.conf$/ExecStart = \/usr\/sbin\/clamd -c \/etc\/clamd.d\/scan.conf/' /usr/lib/systemd/system/clamd@.service

systemctl enable clamd@.service
systemctl start clamd@scan

systemctl enable clamonacc.service
systemctl start clamonacc.service


if [ ! -e /etc/cron.daily/clamscan ]; then
  cat > /etc/cron.daily/clamscan << EOF
#!/bin/sh

/usr/bin/clamscan -r / --exclude-dir=/sys/ --quiet --infected | mail $MAILTO -sClam\ daily
EOF

  chmod ugo+x /etc/cron.daily/clamscan
fi

# Lynis - Security Auditing and Scanning Tool for Linux (https://www.tecmint.com/linux-security-auditing-and-scanning-with-lynis-tool/)

do_dnf_install lynis

if [ ! -e /etc/cron.daily/lynis ]; then
  cat > /etc/cron.daily/lynis << EOF
#!/bin/sh

/usr/bin/lynis audit system --cronjob | mail $MAILTO -slynis\ daily
EOF

  chmod ugo+x /etc/cron.daily/lynis
fi

# Tripwire - Security and Data Integrity https://kifarunix.com/install-and-configure-tripwire-security-monitoring-tool-on-centos-8/

do_dnf_install tripwire

tripwire-setup-keyfiles

# Modify /etc/tripwire/twcfg.txt and run: twadmin -m F -S /etc/tripwire/site.key /etc/tripwire/twcfg.txt
# Modify  /etc/tripwire/twpol.txt and run: twadmin -m P -S /etc/tripwire/site.key /etc/tripwire/twpol.txt

TMPFILE1=$( mktemp )
TMPFILE2=$( mktemp )
tripwire --init 2>&1 | tee $TMPFILE1
grep -A 1 '^### Warning: File system error.$' $TMPFILE1 | grep '^### Filename: ' | cut -d' ' -f3 | \
    while read FILE; do echo "s:${FILE}:# centos-pi ${FILE}:"; done > $TMPFILE2
sed -i -f $TMPFILE2 /etc/tripwire/twpol.txt
rm -f $TMPFILE1 $TMPFILE2
twadmin -m P -S /etc/tripwire/site.key /etc/tripwire/twpol.txt

tripwire --init

/etc/cron.weekly/aide

# OSSEC – (HIDS) Host-based Intrusion Detection System http://ossec.github.io/
# tcp-wrappers

