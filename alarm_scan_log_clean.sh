#!/bin/bash

tar cfv "alarms_$(date | awk '{print $2,$3,$6}').tar" alarm*.txt && rm -f alarm_scan*.txt
