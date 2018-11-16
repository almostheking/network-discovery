#!/bin/bash

set -o errexit
DEBUG='false'; [[ "${DEBUG}" == 'true' ]] && set -o xtrace
set -o pipefail

readonly IP_RANGE=$1
readonly DELAY_TIME=$2
readonly WD=/tmp

_scan_and_parse () {
	sudo nmap -R -sP $IP_RANGE | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}' | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}';
}

gen_report () {
	echo -e "UNRECOGNIZED SYSTEMS CONNECTED TO THE NETWORK\n" > $WD/alarm_report.txt;
	echo -e "Investigate the following unauthorized or otherwise unexpected connections to the network visible to $(uname -a | awk '{print $2}'):\n" >> $WD/alarm_report.txt;
	cat $WD/diffs.txt >> $WD/alarm_report.txt;
	echo -e "\nEND REPORT, $(date)" >> $WD/alarm_report.txt;
	cat $WD/alarm_report.txt | sed 's|)|)\n|g' > $WD/alarm_report_final.txt;
}

mailtime () {
	mail -s "Scanner ALARM" jlignelli@mrwsystems.com -a "FROM:netgarde@mrwsystems.com" < $WD/alarm_report_final.txt;
	#sleep 3s;
	#sudo systemctl restart postfix;
	rm -f $WD/alarm_scan.txt $WD/diffs.txt $WD/alarm_report*.txt;
	sleep $DELAY_TIME;
}

if [ -e $WD/alarm_scan.lock ]; then
	echo Locked;
else
	touch $WD/alarm_scan.lock;
	_scan_and_parse | sort > $WD/alarm_scan.txt; cp $WD/alarm_scan.txt /home/joe/alarm_scan.txt;
	comm -13 ~/FINAL_WHITELIST.txt $WD/alarm_scan.txt > $WD/diffs.txt;
	echo "TEST" >> $WD/diffs.txt;

	if [[ $(wc -w <$WD/diffs.txt) -gt 0 ]]; then
		gen_report
		mailtime
	else
		rm -f $WD/alarm_scan.txt $WD/diffs.txt $WD/alarm_report*.txt;
	fi

	rm -f $WD/alarm_scan.lock;
fi
