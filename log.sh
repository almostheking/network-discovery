#!/bin/bash

# This script logs connections and disconnections from a given network by periodically scanning for active devices.

set -o errexit
DEBUG='false'; [[ "${DEBUG}" == 'true' ]] && set -o xtrace
set -o pipefail

readonly IP_RANGE=$1
readonly FULLDATE=$(date)
readonly DATESTAMP=$(date | awk '{print $1,$2,$3}')
readonly WD=/tmp
readonly SD=/home/scanman/asset_log

# Function scans and parses IP range results.
_scan_and_parse () {
	sudo nmap -R -sP $IP_RANGE | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'  | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}' | sort> $WD/scan.$count.txt;
}

# This creates a running scan list by comparing the previous loop's scanlist with the current loop's scan results.
_create_scan_results () {
	if [ -e $WD/scanlist.txt ]; then
		comm -13 $WD/scanlist.txt $WD/scan.$count.txt > $WD/unique.txt;
		cat $WD/unique.txt >> $WD/scanlist.txt;
		sort $WD/scanlist.txt > $WD/tmp && mv $WD/tmp $WD/scanlist.txt;
		rm -f $WD/scan.$count.txt $WD/unique.txt;
	else
		mv $WD/scan.$count.txt $WD/scanlist.txt;
	fi
}

# Function simply creates lists of devices to add or subtract from the rolling list.
_addsub_lists () {
	comm -23 $WD/rolling.txt $WD/scanlist.txt > $WD/sub.txt;
	comm -13 $WD/rolling.txt $WD/scanlist.txt > $WD/add.txt;
}

# Function processes the add and sub lists, turning them into log entries and attaching them to the running log file.
_proc_addsub_lists () {
	if [[ $(wc -w <$WD/sub.txt) -gt 0 ]]; then
		awk -v var="~$FULLDATE DISCONNECTED: " '{print var$0}' $WD/sub.txt > $WD/tmp && mv $WD/tmp $WD/sub.txt;
		cat $WD/sub.txt >> $SD/cumulative.txt;
	fi

	if [[ $(wc -w <$WD/add.txt) -gt 0 ]]; then
		awk -v var="~$FULLDATE CONNECTED: " '{print var$0}' $WD/add.txt > $WD/tmp && mv $WD/tmp $WD/add.txt;
		cat $WD/add.txt >> $SD/cumulative.txt;
	fi

	mv $WD/scanlist.txt $WD/rolling.txt; 
}

# Function archives the running log file and clears the way for a new one to be made
_archive_cumulo () {
	tar -cvf "$(cat $SD/cumulative.txt | grep "Log Generated: " | awk '{print $3,$4,$5}')_archive.tar" $SD/cumulative.txt;
	rm -f $WD/rolling.txt $SD/cumulative.txt;
}

# Creates a new running log file based on scanlists results
_gen_cumulo () {
	mv $WD/scanlist.txt $WD/rolling.txt;
	echo -e "Log Generated: $FULLDATE\n" > $SD/cumulative.txt;
	echo -e "INITIAL SCAN:\n" >> $SD/cumulative.txt; cat $WD/rolling.txt >> $SD/cumulative.txt;
	echo -e "\n" >> $SD/cumulative.txt;
}

_promote_cleanliness () {
	rm -f $WD/add.txt $WD/sub.txt;
}

for count in 1 2 3 4 5 6 7 8 9
do
	_scan_and_parse
	_create_scan_results
done

if [ -e $WD/rolling.txt ]; then
	if [[ $DATESTAMP = $(cat $SD/cumulative.txt | grep "Log Generated: " | awk '{print $3,$4,$5}') ]]; then
		_addsub_lists
		_proc_addsub_lists
		_promote_cleanliness
	else
		_archive_cumulo
		_promote_cleanliness
	fi
else
	_gen_cumulo
fi
