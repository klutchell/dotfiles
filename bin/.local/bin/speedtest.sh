#!/bin/bash

while :
do
	logfile="/tmp/speedtest_$(date +%Y%m%d).csv"
	[ -e "${logfile}" ] || /usr/bin/speedtest --csv-header | tee "${logfile}"
	/usr/bin/speedtest --csv | tee -a "${logfile}"
	sleep 30
done
