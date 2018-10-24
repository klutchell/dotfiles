#!/bin/bash

while :
do
	server="google.com"
	logfile="/tmp/traceroute_$(date +%Y%m%d).log"
	/usr/sbin/traceroute "${server}" | ts | tee -a "${logfile}"
	sleep 60
done
