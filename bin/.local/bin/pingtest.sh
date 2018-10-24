#!/bin/bash

server="google.com"
logfile="/tmp/pingtest_$(date +%Y%m%d).log"
/bin/ping -i 10 "${server}" | ts | tee -a "${logfile}"