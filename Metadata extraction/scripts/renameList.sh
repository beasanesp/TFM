#!/bin/bash

DIRECTORY=$1

if [ -z "$2" ] # check if user supplies appendix to be removed from folders
then
	  PATTERN='_upload'
else
	  PATTERN=$2
fi

# Remove the appendix of all directories
rename -v "s/$PATTERN//" $DIRECTORY/*

#Generate list
ls -dl $DIRECTORY/*_1* | awk '{print $9}' |  awk -F'/' '{print $NF}' > ./individuals.txt