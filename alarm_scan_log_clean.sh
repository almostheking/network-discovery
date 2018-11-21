#!/bin/bash
set -e
set -o pipefail
readonly WD=/home/scanman/alarm_scan_log

tar cfv $WD/"alarms_$(date | awk '{print $2,$3,$6}').tar" $WD/alarm*.txt && rm -f $WD/alarm_scan*.txt;

exit;
