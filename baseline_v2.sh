#!/bin/bash

set -o errexit
DEBUG='false'; [[ "${DEBUG}" == 'true' ]] && set -o xtrace
set -o pipefail

readonly IP_RANGE=$1
readonly WD=/tmp

_scan_and_parse () {
	sudo nmap -R -sP $IP_RANGE | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'  | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}';
}

_compare_wls () {
	comm -13 $1 $2 > $WD/weird.txt;
	cat $WD/weird.txt >> $1 && rm -f $WD/weird.txt;
	sort $1 > $WD/tmp && mv $WD/tmp $1;
}

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

if [ -e ~/FINAL_WHITELIST.txt ]; then
	_compare_wls ~/FINAL_WHITELIST.txt $WD/whitelist.txt;
else
	mv $WD/whitelist.txt ~/FINAL_WHITELIST.txt;
fi
