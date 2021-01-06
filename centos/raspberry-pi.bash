#!/bin/bash

source do_actions.env ""

if [ ! -e /etc/hostname ]; then
    echo "localhost.localdomain" > /etc/hostname
    chmod 644 /etc/hostname
    chown root.root /etc/hostname

    hostname localhost
    domainname localdomain
fi

# firewall-cmd --list-all
firewall-cmd --remove-service=cockpit
firewall-cmd --remove-service=dhcpv6-client

# systemctl status kdump.service
systemctl stop kdump.service
systemctl disable kdump.service

