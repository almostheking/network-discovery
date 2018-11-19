#!/bin/bash
readonly WD=/home/scanman/alarm_scan_log

if [ -e $WD/alarm*.txt ]; then
    tar cfv $WD/"alarms_$(date | awk '{print $2,$3,$6}').tar" $WD/alarm*.txt && rm -f $WD/alarm*.txt;
else
    exit;
fi
