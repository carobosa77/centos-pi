#!/bin/bash

source do_actions.env

MAILTO=${MAILTO-root}

################################################################################
# Secure SSH server ############################################################
################################################################################

# s/^PasswordAuthentication yes$/PasswordAuthentication no/
do_file_sed '
  s/^#LogLevel INFO$/LogLevel VERBOSE/
  s/^PermitRootLogin yes$/PermitRootLogin prohibit-password/
  s/^#MaxAuthTries 6$/MaxAuthTries 2/
  s/^#MaxSessions 10$/MaxSessions 2/
  s/^#PermitEmptyPasswords no$/PermitEmptyPasswords no/
  s/^#AllowAgentForwarding yes$/AllowAgentForwarding no/
  s/^#AllowTcpForwarding yes$/AllowTcpForwarding no/
  s/^X11Forwarding yes$/X11Forwarding no/
  s/^#TCPKeepAlive yes/TCPKeepAlive no/
  s/^#Compression delayed$/Compression no/
  s/^#ClientAliveCountMax 3$/ClientAliveCountMax 2/
' /etc/ssh/sshd_config

systemctl restart sshd.service

################################################################################
# Apply Strong Password Policy #################################################
################################################################################

# do_file_append /etc/pam.d/passwd << EOD
# password required pam_pwquality.so retry=3
# EOD

# do_file_append /etc/security/pwquality.conf << EOD
# minlen = 8
# minclass = 4
# maxsequence = 3
# maxrepeat = 3
# EOD

do_file_sed '
  s/^UMASK\t\t022$/UMASK\t\t027/
  s/^PASS_MAX_DAYS\t99999$/PASS_MAX_DAYS\t90/
  s/^PASS_MIN_DAYS\t0$/PASS_MIN_DAYS\t1/
  /^ENCRYPT_METHOD SHA512$/a SHA_CRYPT_MIN_ROUNDS 20000\nSHA_CRYPT_MAX_ROUNDS 100000
' /etc/login.defs

################################################################################
# Hardening base-os ############################################################
################################################################################

do_file_update /etc/issue << EOF
Authorized uses only. All activity may be monitored and reported.
EOF
do_file_update /etc/issue.net << EOF
Authorized uses only. All activity may be monitored and reported.
EOF

do_file_sed 's/^    umask 0[02]2$/    umask 027/' /etc/profile

if ! [ -f /etc/security/limits.d/99-centos-pi.conf ]; then
  cat > /etc/security/limits.d/99-centos-pi.conf << EOF
* soft core 0
* hard core 0
EOF

  chmod 644 /etc/security/limits.d/99-centos-pi.conf
  chown root.root /etc/security/limits.d/99-centos-pi.conf
fi

#/etc/pam.d/common-password

if ! [ -f /etc/sysctl.d/99-centos-pi.conf ]; then
  cat > /etc/sysctl.d/99-centos-pi.conf << EOF
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.sysrq=0

net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.default.log_martians=1

net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
EOF
  chmod 644 /etc/sysctl.d/99-centos-pi.conf
  chown root.root /etc/sysctl.d/99-centos-pi.conf
fi

################################################################################
# psacct - Kernel process accounting ###########################################
# sysstat - Performance monitoring tools #######################################
################################################################################

do_dnf_install psacct sysstat

systemctl enable psacct.service
systemctl start psacct.service
systemctl enable sysstat.service
systemctl start sysstat.service

################################################################################
# dnf-automatic - Automatic updates ############################################
################################################################################

do_dnf_install dnf-automatic

do_file_sed "
  s/^apply_updates = no$/apply_updates = yes/
  s/^email_to = root$/email_to = ${MAILTO}/
" /etc/dnf/automatic.conf

systemctl enable dnf-automatic.timer
systemctl start dnf-automatic.timer

################################################################################
# Fail2ban - intrusion prevention software #####################################
################################################################################

do_dnf_install epel-release
do_dnf_install fail2ban

if [ ! -e /etc/fail2ban/jail.d/sshd.local ]; then
  cat > /etc/fail2ban/jail.d/sshd.local << EOF
[sshd]
enabled = true
EOF
fi

if [ ! -e /etc/fail2ban/jail.local ]; then
  cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
action = %(action_mwl)s
EOF
fi

systemctl enable fail2ban.service
systemctl start fail2ban.service

################################################################################
# AIDE - Advanced Intrusion Detection Environment
################################################################################

do_dnf_install aide

if [ ! -e /etc/cron.weekly/aide ]; then
  cat > /etc/cron.weekly/aide << EOF
#!/bin/sh

/usr/sbin/aide --init | mail -s "AIDE weekly" ${MAILTO}@localhost
FILENAME=/var/lib/aide/aide.db.$( date +%F_%T ).gz
cp /var/lib/aide/aide.db.new.gz \$FILENAME
# chattr +i $FILENAME
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
EOF

  chmod ugo+x /etc/cron.weekly/aide
fi

if [ ! -e /etc/cron.daily/aide ]; then
  cat > /etc/cron.daily/aide << EOF
#!/bin/sh

/usr/sbin/aide --check | mail -s "AIDE daily" ${MAILTO}@localhost
EOF

  chmod ugo+x /etc/cron.daily/aide
fi

cat << EOD >> final.bash

/etc/cron.weekly/aide
EOD

################################################################################
# Rkhunter - Rootkit Scanner ###################################################
################################################################################

do_dnf_install epel-release
do_dnf_install rkhunter file

if [ ! -e /etc/rkhunter.conf.local ]; then
  cat > /etc/rkhunter.conf.local << EOF
ALLOW_SSH_ROOT_USER=prohibit-password
EOF

  chmod --reference=/etc/rkhunter.conf /etc/rkhunter.conf.local
fi

cat << EOD >> final.bash

/usr/bin/rkhunter --update
/usr/bin/rkhunter --propupd
EOD

################################################################################
# ClamAV - Antivirus Scanner ###################################################
#   https://www.adminbyaccident.com/gnu-linux/how-to-install-the-clamav-antivirus-on-centos-8/
################################################################################

do_dnf_install clamav clamav-update clamd

setsebool -P antivirus_can_scan_system 1

freshclam
systemctl enable clamav-freshclam.service
systemctl start clamav-freshclam.service

do_file_sed '
  s/^#LocalSocket \/run\/clamd.scan\/clamd.sock$/LocalSocket \/run\/clamd.scan\/clamd.sock/
  s/^#OnAccessIncludePath \/home$/OnAccessIncludePath \/home/
  s/^#OnAccessPrevention yes$/OnAccessPrevention yes/
  s/^#OnAccessExcludeUname clamav$/OnAccessExcludeUname clamscan/
' /etc/clamd.d/scan.conf

do_file_sed '
  s/^Description = clamd scanner (%i) daemon$/Description = clamd scanner daemon/
  s/^ExecStart = \/usr\/sbin\/clamd -c \/etc\/clamd.d\/%i.conf$/ExecStart = \/usr\/sbin\/clamd -c \/etc\/clamd.d\/scan.conf/
' /usr/lib/systemd/system/clamd@.service

systemctl enable clamd@.service
systemctl start clamd@scan

systemctl enable clamonacc.service
systemctl start clamonacc.service

if [ ! -e /etc/cron.daily/clamscan ]; then
  cat > /etc/cron.daily/clamscan << EOF
#!/bin/sh

/usr/bin/clamscan -r / --exclude-dir=/sys/ --quiet --infected | mail -s "Clam daily scan" ${MAILTO}@localhost
EOF

  chmod ugo+x /etc/cron.daily/clamscan
fi

################################################################################
# Lynis - Security Auditing and Scanning Tool for Linux ########################
#   https://www.tecmint.com/linux-security-auditing-and-scanning-with-lynis-tool/
################################################################################

do_dnf_install lynis

if [ ! -e /etc/lynis/custom.prf ]; then
  cp --preserve=all /etc/lynis/default.prf /etc/lynis/custom.prf
fi

do_file_append /etc/lynis/custom.prf << EOF
# disable raspberry-pi specific checks
skip-test=STRG-1846

# disable centos 8 specific checks
skip-test=FIRE-4512

# disable physical access checks
skip-test=BOOT-5122
skip-test=USB-1000

# disable lone machines checks
skip-test=LOGG-2154

# disable lynis false positives
skip-test=ACCT-9626

#skip-test=SSH-7408:Port
#skip-test=LYNIS
EOF

if [ ! -e /etc/cron.daily/lynis ]; then
  cat > /etc/cron.daily/lynis << EOF
#!/bin/sh

/usr/bin/lynis audit system --cronjob | mail -s "Lynis daily" ${MAILTO}@localhost
EOF

  chmod ugo+x /etc/cron.daily/lynis
fi

################################################################################
# Tripwire - Security and Data Integrity #######################################
#   https://kifarunix.com/install-and-configure-tripwire-security-monitoring-tool-on-centos-8/
################################################################################

do_dnf_install tripwire

tripwire-setup-keyfiles

# Modify /etc/tripwire/twcfg.txt and run: twadmin -m F -S /etc/tripwire/site.key /etc/tripwire/twcfg.txt
# Modify  /etc/tripwire/twpol.txt and run: twadmin -m P -S /etc/tripwire/site.key /etc/tripwire/twpol.txt

do_file_append /etc/tripwire/twcfg.txt << EOF
GLOBALEMAIL=${MAILTO}@localhost
EOF

twadmin -m F -S /etc/tripwire/site.key /etc/tripwire/twcfg.txt

cat << EOD >> final.bash

TMPFILE1=\$( mktemp )
TMPFILE2=\$( mktemp )
tripwire --init 2> \$TMPFILE1
grep -A 1 '^### Warning: File system error.$' \$TMPFILE1 | grep '^### Filename: ' | cut -d' ' -f3 | \
    while read FILE; do echo "s:\${FILE}:# centos-pi \${FILE}:"; done > \$TMPFILE2
sed -i -f \$TMPFILE2 /etc/tripwire/twpol.txt
rm -f \$TMPFILE1 \$TMPFILE2
twadmin -m P -S /etc/tripwire/site.key /etc/tripwire/twpol.txt
tripwire --init
rm /etc/tripwire/tw.pol.bak
EOD

################################################################################
# OSSEC – (HIDS) Host-based Intrusion Detection System http://ossec.github.io/
# tcp-wrappers

