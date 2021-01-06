#!/bin/bash

source do_actions.env ""

do_dnf_install postfix mailx

do_file_sed 's/^#mynetworks_style = host$/mynetworks_style = host/' /etc/postfix/main.cf

systemctl restart postfix.service
