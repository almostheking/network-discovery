#!/bin/bash

if [ -e /home/scanman/alarm_scan_log/alarm*.txt ]; then
  tar cfv "alarms_$(date | awk '{print $2,$3,$6}').tar" alarm*.txt && rm -f alarm_scan*.txt;
else
  exit;
fi
