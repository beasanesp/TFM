#!/bin/bash

#
# This script assumes that the model server is already hosted locally on port 8080
# Change manually if this is not the case
# 


METADIR=$1
OUTPUTDIR=$2


echo "Converting metadata table into JSON request"
for m in $METADIR/*.meta
do
	METAFILE=$m
	f="$(basename -- $METAFILE)"
	if [ ! -d $OUTPUTDIR ]
	then
		echo "Creating output directory"
		mkdir $OUTPUTDIR
		mkdir $OUTPUTDIR/requests/ # For JSON formatted metatables
		mkdir $OUTPUTDIR/responses/ # For predictions made by the model server
		mkdir $OUTPUTDIR/predictions/ # For dataframes with predictions concatenated
	fi

	echo "Converting to JSON"
	python3 meta2json.py $METAFILE $OUTPUTDIR/requests/

	echo "Making predictions"
	curl -X POST --data @$OUTPUTDIR/requests/$f.json http://localhost:8080/predict > $OUTPUTDIR/responses/$f.response

	#echo "Append predictions to metadata"
	python3 combineMetaPred.py $METAFILE $OUTPUTDIR/responses/$f.response $OUTPUTDIR/predictions/
	#python combineMetaPredMulti.py $METAFILE $OUTPUTDIR/responses/$f.response $OUTPUTDIR/predictions/

done
