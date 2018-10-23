#!/bin/bash

IP_RANGE=$1
WD=/tmp

# Scans 9 times and creates final scan output
for count in 1 2 3 4 5 6 7 8 9
do
	sudo nmap -sP -R $IP_RANGE | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | grep "MAC" | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}' | sort> $WD/scan.$count.txt

	if [ -e $WD/fini.txt ]; then
		comm -13 $WD/fini.txt $WD/scan.$count.txt > $WD/unique.txt;
		cat $WD/unique.txt >> $WD/fini.txt; sort $WD/fini.txt > $WD/tmp && mv $WD/tmp $WD/fini.txt;
		rm -f $WD/scan.$count.txt $WD/unique.txt;
	else
		mv $WD/scan.$count.txt $WD/fini.txt;
	fi
done

# Establish time variables for shorter lines
datestamp=$(date | awk '{print $1,$2,$3}')
fulldate=$(date)

# If rolling file exists, check its date, and if it matches with today's date, update logs.
# If the rolling file doesn't match with today's date, archive the cumulative log and start fresh
# If rolling file doesn't exist, create it and attach initial scan data to new cumulative file.
if [ -e $WD/rolling.txt ]; then
	if [[ $datestamp = $(cat cumulative.txt | grep "Log Generated: " | awk '{print $3,$4,$5}') ]]; then
		comm -23 $WD/rolling.txt $WD/fini.txt > $WD/byebye.txt;
		comm -13 $WD/rolling.txt $WD/fini.txt > $WD/hello.txt;
		if [[ $(wc -w <$WD/byebye.txt) -gt 0 ]]; then
			for line in $(cat $WD/byebye.txt);
			do
				grep -v "$line" $WD/rolling.txt > $WD/new_rolling.txt;
				sort $WD/new_rolling.txt > $WD/rolling.txt; rm $WD/new_rolling.txt;
			done
			awk -v var="~$fulldate DISCONNECTED: " '{print var$0}' $WD/byebye.txt > $WD/tmp && mv $WD/tmp $WD/byebye.txt;
			cat $WD/byebye.txt >> cumulative.txt;
		fi

		if [[ $(wc -w <$WD/hello.txt) -gt 0 ]];then
			cat $WD/hello.txt >> $WD/rolling.txt; sort $WD/rolling.txt > $WD/tmp && mv $WD/tmp $WD/rolling.txt;
			awk -v var="~$fulldate CONNECTED: " '{print var$0}' $WD/hello.txt > $WD/tmp && mv $WD/tmp $WD/hello.txt;
			cat $WD/hello.txt >> cumulative.txt;
		fi
	else
		tar -cvf "$(cat cumulative.txt | grep "Log Generated: " | awk '{print $3,$4,$5}')_archive.tar" cumulative.txt;
		rm -f $WD/rolling.txt cumulative.txt;
	fi
	rm -f $WD/fini.txt;
else
	mv $WD/fini.txt $WD/rolling.txt;
	echo -e "Log Generated: $fulldate\n" > cumulative.txt;
	echo -e "INITIAL SCAN:\n" >> cumulative.txt; cat $WD/rolling.txt >> cumulative.txt;
	echo -e "\n" >> cumulative.txt;
fi
