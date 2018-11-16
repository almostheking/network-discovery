#!/bin/bash

set -o errexit
DEBUG='false'; [[ "${DEBUG}" == 'true' ]] && set -o xtrace
set -o pipefail

readonly IP_RANGE=$1
readonly FULLDATE=$(date)
readonly DATESTAMP=$(date | awk '{print $1,$2,$3}')
readonly WD=/tmp

_scan_and_parse () {
	sudo nmap -R -sP $IP_RANGE | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}'  | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}' | sort> $WD/scan.$count.txt;
}

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

_addsub_lists () {
	comm -23 $WD/rolling.txt $WD/scanlist.txt > $WD/sub.txt;
	comm -13 $WD/rolling.txt $WD/scanlist.txt > $WD/add.txt;
}

_proc_addsub_lists () {
	if [[ $(wc -w <$WD/sub.txt) -gt 0 ]]; then
		awk -v var="~$FULLDATE DISCONNECTED: " '{print var$0}' $WD/sub.txt > $WD/tmp && mv $WD/tmp $WD/sub.txt;
		cat $WD/sub.txt >> cumulative.txt;
	fi

	if [[ $(wc -w <$WD/add.txt) -gt 0 ]]; then
		awk -v var="~$FULLDATE CONNECTED: " '{print var$0}' $WD/add.txt > $WD/tmp && mv $WD/tmp $WD/add.txt;
		cat $WD/add.txt >> cumulative.txt;
	fi

	mv $WD/scanlist.txt $WD/rolling.txt; 
}

_archive_cumulo () {
	tar -cvf "$(cat cumulative.txt | grep "Log Generated: " | awk '{print $3,$4,$5}')_archive.tar" cumulative.txt;
	rm -f $WD/rolling.txt cumulative.txt;
}

_gen_cumulo () {
	mv $WD/scanlist.txt $WD/rolling.txt;
	echo -e "Log Generated: $FULLDATE\n" > cumulative.txt;
	echo -e "INITIAL SCAN:\n" >> cumulative.txt; cat $WD/rolling.txt >> cumulative.txt;
	echo -e "\n" >> cumulative.txt;
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
	if [[ $DATESTAMP = $(cat cumulative.txt | grep "Log Generated: " | awk '{print $3,$4,$5}') ]]; then
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
