#!/bin/bash

IP_RANGE=$1
WD=/tmp

# Create whitelist, then do it two more times, comparing the new ones with the initial one.
# Add any differences and create a FINAL_WHITELIST to be saved in the /home/scanman directory for reference.
for count in  1 2 3
do
	sudo nmap -sP -R $IP_RANGE > $WD/raw.txt;	#Raw scan output
	cat $WD/raw.txt | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | grep "MAC" | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}' | sort > $WD/parsed.$count.txt;		#Fully parsed scan
	rm -f $WD/raw.txt;
	
	# Create 9 different scans, parse them, and add any differenecs to the whitelist file.
	for scount in 1 2 3 4 5 6 7 8 9
	do
		sudo nmap -sP -R $IP_RANGE > $WD/raw.$scount.txt;
		cat $WD/raw.$scount.txt | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | grep "MAC" | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}' | sort > $WD/tmp_parsed.$scount.txt;
		comm -13 <(sort $WD/parsed.$count.txt) $WD/tmp_parsed.$scount.txt 2>/dev/null 1>$WD/weird.$scount.txt;		#Compares differences, only outputs entries unique to tmp_parsed file
		cat $WD/weird.$scount.txt >> $WD/parsed.$count.txt;	#Adds diffs to rolling whitelist
		rm -f $WD/raw.$scount.txt $WD/tmp_parsed.$scount.txt /tmp/weird.$scount.txt;	#Cleanup
		continue;
	done

	# If whitelist doesn't exist, creates it - otherwise, merges results of two whitelist files.
	if [ -e $WD/whitelist.txt ]; then
		comm -13 <(sort $WD/whitelist.txt) <(sort $WD/parsed.$count.txt) 2>/dev/null 1>$WD/weird.txt;
		cat $WD/weird.txt >> $WD/whitelist.txt;
		rm -f $WD/weird.txt $WD/parsed.$count.txt;
	else
		mv $WD/parsed.$count.txt $WD/whitelist.txt;
	fi
done

# Prepares whitelist by sorting it.
sort $WD/whitelist.txt > $WD/WHITELIST.txt; rm -f whitelist.txt;

# If FINAL exists, compares it with new FINAL and updates it with any changes.
# If it doesn't exist, copies it over to /home/scanman
if [ -e "/home/joe/FINAL_WHITELIST.txt" ]; then
	comm -13 /home/joe/FINAL_WHITELIST.txt $WD/WHITELIST.txt > $WD/weird.txt;
	cat $WD/weird.txt >> /home/joe/FINAL_WHITELIST.txt;
	sort /home/joe/FINAL_WHITELIST.txt > $WD/wl.txt && mv $WD/wl.txt /home/joe/FINAL_WHITELIST.txt;		#Sorts FINAL
else
	cp $WD/WHITELIST.txt /home/joe/FINAL_WHITELIST.txt;
fi

# Finally, clean up unneeded files
rm -f $WD/WHITELIST.txt $WD/weird.txt $WD/whitelist.txt;
