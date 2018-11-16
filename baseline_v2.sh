#!/bin/bash

# This script, when given an IP range to scan, will begin to generate an asset whitelist to be used alongside the alarm_scan.sh script.
# Note that this script ought to be run multiple times over a period of time, and the results need to be analyzed in order to determine a final whitelist.

set -o errexit
DEBUG='false'; [[ "${DEBUG}" == 'true' ]] && set -o xtrace
set -o pipefail

readonly IP_RANGE=$1
readonly WD=/tmp

# Function scans and parses given IP range.
_scan_and_parse () {
	sudo nmap -R -sP $IP_RANGE | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'  | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}';
}

# Whitelists that are given as arguments to this function are compared, and the FIRST whitelist given is added to based on the differences between it and the second whitelist given.
_compare_wls () {
	comm -13 $1 $2 > $WD/weird.txt;
	cat $WD/weird.txt >> $1 && rm -f $WD/weird.txt;
	sort $1 > $WD/tmp && mv $WD/tmp $1;
}

# Scans are run repeatedly to help make the end result more accurate. Some elusive devices evade the scans occasionally.
for count in 1 2 3
do
	_scan_and_parse | sort> $WD/wl_big.$count.txt;

	for scount in 1 2 3
	do
		_scan_and_parse | sort> $WD/wl_lil.$scount.txt;
		_compare_wls $WD/wl_big.$count.txt $WD/wl_lil.$scount.txt;
		rm -f $WD/wl_lil.$scount.txt;
	done

	if [ -e $WD/whitelist.txt ]; then
		_compare_wls $WD/whitelist.txt $WD/wl_big.$count.txt;
		rm -f $WD/wl_big.$count.txt;
	else
		mv $WD/wl_big.$count.txt $WD/whitelist.txt;
	fi
done

# Here, the final whitelist is either created or extended.
if [ -e ~/FINAL_WHITELIST.txt ]; then
	_compare_wls ~/FINAL_WHITELIST.txt $WD/whitelist.txt;
	rm -f $WD/whitelist.txt;
else
	mv $WD/whitelist.txt ~/FINAL_WHITELIST.txt;
fi
