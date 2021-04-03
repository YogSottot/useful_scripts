#!/usr/bin/env bash

mail=$1
hostname=$(/bin/hostname)

echo "ImunfiyAV detected virus. Check the web-interface for report" | mailx -s "$(echo -e  "Virus detected on ${hostname}\nContent-Type: text/html; charset=UTF-8")" "${mail}"
