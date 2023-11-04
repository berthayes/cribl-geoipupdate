#!/bin/sh

GEOIPUPDATE_BIN=/opt/homebrew/bin/geoipupdate

while getopts ":d" opt; do
	case $opt in
		d ) DEBUG=1 ;;
	esac
done

if [ -n "$DEBUG" ]; then
	echo "DEBUG is ON, BABY!"
fi

UPDATE_OUTPUT=$($GEOIPUPDATE_BIN -o)
if [ $DEBUG ]; then echo "UPDATE_OUTPUT is " $UPDATE_OUTPUT && echo; fi

# cat update.json| jq '[.[] | select(.modified_at) | .edition_id]'
EDITION=$(echo $UPDATE_OUTPUT | jq '[.[] | select(.modified_at) | .edition_id]')

if [ $DEBUG ]; then echo "EDITION IS " $EDITION && echo; fi

if (echo $EDITION | grep "ASN"); then 
    ./geoip_update.sh -a; 
fi

if (echo $EDITION | grep "City"); then
    ./geoip_update.sh -c;
fi