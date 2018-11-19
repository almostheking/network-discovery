#!/bin/bash

# This script, when given an IP address range to scan, a delay time, and the existence of a FINAL_WHITELIST.txt in the root /home directory, will notify you of new devices connecting to a restricted network.

set -o errexit
DEBUG='false'; [[ "${DEBUG}" == 'true' ]] && set -o xtrace
set -o pipefail

readonly IP_RANGE=$1
readonly DELAY_TIME=$2
readonly WD=/tmp
readonly HOME=/home/scanman

# Function performs nmap ping/ARP scan and attempts to resolve hostnames.
# Scan results are parsed.
_scan_and_parse () {
	sudo nmap -R -sP $IP_RANGE | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}' | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}';
}

# Function creates alarm file with alarm scan results.
gen_report () {
	echo -e "UNRECOGNIZED SYSTEMS CONNECTED TO THE NETWORK\n" > $WD/alarm_report.txt;
	echo -e "Investigate the following unauthorized or otherwise unexpected connections to the network visible to $(uname -a | awk '{print $2}'):\n" >> $WD/alarm_report.txt;
	cat $WD/diffs.txt >> $WD/alarm_report.txt;
	echo -e "\nEND REPORT, $(date)" >> $WD/alarm_report.txt;
	cat $WD/alarm_report.txt | sed 's|)|)\n|g' > $WD/alarm_report_final.txt;
}

# Function sends alarm email. Must be manually configured to send email to desired recipients.
# The sleep command allows for the configuration of a delay after an alarm is sent so that the script doesn't flood you with identical alarms before you can investigate fully.
mailtime () {
	mail -s "Scanner ALARM" jlignelli@mrwsystems.com -a "FROM:netgarde@mrwsystems.com" < $WD/alarm_report_final.txt;
	rm -f $WD/alarm_scan.txt $WD/diffs.txt $WD/alarm_report*.txt;
	sleep $DELAY_TIME;
}

# If the lock file exists, the script doesn't run.
if [ -e $WD/alarm_scan.lock ]; then
	exit;
else
	touch $WD/alarm_scan.lock;
	_scan_and_parse | sort > $WD/alarm_scan.txt; cp $WD/alarm_scan.txt $HOME/alarm_scan_log/"alarm_scan_$(date).txt";
	comm -13 ~/FINAL_WHITELIST.txt $WD/alarm_scan.txt > $WD/diffs.txt;
	#echo "TEST" >> $WD/diffs.txt;

	if [[ $(wc -w <$WD/diffs.txt) -gt 0 ]]; then
		gen_report
		mailtime
	else
		rm -f $WD/alarm_scan.txt $WD/diffs.txt $WD/alarm_report*.txt;
	fi

	rm -f $WD/alarm_scan.lock;
fi
