#!/bin/bash

# The script needs IP range and time delay arguments
# Time delay examples: 10m for 10 minutes, 1h for 1 hour, etc.

IP_RANGE=$1
DELAY_TIME=$2
WD=/tmp
WHITELIST=/home/joe/FINAL_WHITELIST.txt

# Since the script is written to work with cron, the lock file ensures that cron will not run the script before the previous run is finished.

# If the lock file exists, the script just ends.
if [ -e $WD/alarm_scan.lock ]; then
        return;
else
        touch $WD/alarm_scan.lock;      #Create lock file to run for the duration of the script's runtime
        sudo nmap -sP -R $IP_RANGE | grep -v "Host" | tr '\n' ' ' | sed 's|Nmap|\nNmap|g' | grep "MAC" | cut -d " " -f5,8-15 | awk '{gsub("Address: ", "");print}' | sort > $WD/alarm_scan_parsed.txt;          #Scan and parse
        comm -13 $WHITELIST $WD/alarm_scan_parsed.txt > $WD/diffs.txt;          #Compares with whitelist and creates diffs file
        # Uncomment the following line to test the alarm emailing....
        #echo "TEST" >> $WD/diffs.txt;

        # If the diffs file contains ANY data, send the report - otherwise, end the script.
        if [[ $(wc -w <$WD/diffs.txt) -gt 0 ]]; then
                # The following lines create the report file.
                echo -e "UNRECOGNIZED SYSTEMS CONNECTED TO THE NETWORK\n" > $WD/alarm_report.txt;
                echo -e "Investigate the following unauthorized or otherwise unexpected connections to the network visible to $(uname -a | awk '{print $2}'):\n" >> $WD/alarm_report.txt;
                cat $WD/diffs.txt >> $WD/alarm_report.txt;      #Attach unrecognized systems to report
                echo -e "\nEND REPORT, $(date)" >> $WD/alarm_report.txt;
                cat $WD/alarm_report.txt | sed 's|)|)\n|g' > $WD/alarm_report_final.txt;        #Add newlines to list entries
                mail -s "Scanner ALARM" jlignelli@mrwsystems.com < $WD/alarm_report_final.txt;          #Send email
                sleep 3s;       #Give postfix/mail client time to think, (result of troubleshooting unreliable sending)
                sudo systemctl restart postfix;         #Ensures mail is sent every run of the script
                sleep $DELAY_TIME;      #Ensures we don't get bombarded with alerts if there are no new alarms to send
                rm -f $WD/alarm_scan.lock $WD/alarm_scan_parsed.txt $WD/diffs.txt $WD/alarm_report*.txt;        #Remove lock and clean /tmp
        else
                rm -f $WD/alarm_scan_parsed.txt $WD/diffs.txt $WD/alarm_report*.txt;
        fi

        rm -f $WD/alarm_scan.lock;      #Ensure that lock file is removed after script ends
fi
