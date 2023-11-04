#!/bin/sh

## Set environment variables
source ./config.conf

## Check options, set variables for flow control
while getopts ":dac" opt; do
	case $opt in
		d ) DEBUG=1 ;;
		a ) ASN=1 ;;
		c ) CITY=1 ;;
	esac
done

if [ -n "$DEBUG" ]; then echo "DEBUG is ON, BABY!" && echo; fi
if [ -n "$ASN" ]; then echo "Called to upload new ASN lookup file" && echo; fi
if [ -n "$CITY" ]; then echo "Called to upload new City lookup file" && echo; fi

## Define functions to be called by flow control portion below
function GET_AUTH_TOKEN {
	## Create JSON body to send via curl to retrieve auth token
	echo "Creating a JSON data object for auth token request"
	echo
	DATA=$(jq -n \
	--arg grant_type grant_type \
	--arg type client_credentials \
	--arg client_id client_id \
	--arg id "$CLIENT_ID" \
	--arg client_secret client_secret \
	--arg secret "$CLIENT_SECRET" \
	--arg audience audience \
	--arg api_audience "https://api.cribl.cloud" \
	'{($grant_type):$type,($client_id):$id,($client_secret):$secret,($audience):$api_audience}')
	if [ $DEBUG ]; then echo "DATA is $DATA" && echo; fi

	## Make curl POST for a Bearer token and capture it
	echo "Making a curl POST with JSON data object for Bearer toekn"
	echo
	TOKEN_RESPONSE=$(curl -s --request POST \
	--url https://login.cribl.cloud/oauth/token \
	--header "content-type: application/json" \
	--data "$DATA")
	if [ $DEBUG ]; then echo "TOKEN_RESPONSE is " $TOKEN_RESPONSE; fi

	## Parse out the actual token from the response
	TOKEN=$(echo $TOKEN_RESPONSE | jq -r .access_token)
	if [ $DEBUG ]; then echo "TOKEN is " $TOKEN && echo; fi
}
function UPLOAD_ASN_MMDB {
	## Make API call to upload new mmdb file and capture temp filename
	echo "Uploading new ASN mmbdb file and capturing temp filename"
	echo
	TEMP_FILENAME=$(curl -s -X PUT \
	https://main-$INSTANCE_ID.cribl.cloud/api/v1/m/defaultHybrid/system/lookups?filename=GeoLite2-ASN.mmdb \
	-H "Authorization: Bearer $TOKEN" \
	-H 'accept: application/json' \
	-H "Content-Type: text/csv" \
	--data-binary @$ASN_PATH)
	if [ $DEBUG ]; then echo "TEMP_FILENAME IS "$TEMP_FILENAME && echo; fi

	## Parse out the fileinfo
	FILENAME=$(echo $TEMP_FILENAME | jq -r .filename)
	if [ $DEBUG ]; then echo "FILENAME IS " $FILENAME && echo; fi

	## Create nested JSON body to send via curl PATCH to update lookup file
	echo "Creating nested JSON to send via curl PATCH to update lookup file"
	echo
	INFO=$(jq -n \
	--arg filename filename \
	--arg mmdb "$FILENAME" \
	'{($filename):$mmdb}' | jq -c )
	if [ $DEBUG ]; then echo "INFO is " $INFO && echo; fi
	PATCH_DATA=$(jq -n \
	--arg id id \
	--arg file_id 'GeoLite2-ASN.mmdb' \
	--arg fileInfo fileInfo \
	--argjson info $INFO \
	'{($id):$file_id,($fileInfo):$info}' | jq -c )
	if [ $DEBUG ]; then echo "PATCH_DATA IS " $PATCH_DATA && echo; fi

	## Make curl PATCH to update the existing file with the new temp file
	echo "Updating lookup file with curl PATCH"
	echo
	FILE_UPDATE=$(curl -s -X PATCH \
	https://main-$INSTANCE_ID.cribl.cloud/api/v1/m/defaultHybrid/system/lookups/GeoLite2-ASN.mmdb \
	-H "Authorization: Bearer $TOKEN" \
	-H 'accept: application/json' \
	-H "Content-Type: application/json" \
	-d "$PATCH_DATA")
	if [ $DEBUG ]; then echo "FILE_UPDATE output is " $FILE_UPDATE && echo; fi

	## Make a nested JSON body to send via curl PATCH for commit
	echo "Creating nested JSON to send for commit"
	echo
	FILES=$(jq -n \
	--arg files files \
	--arg file1 'groups/defaultHybrid/data/lookups/GeoLite2-ASN.mmdb' \
	--arg file2 'groups/defaultHybrid/data/lookups/GeoLite2-ASN.yml' \
	'{($files):[$file1,$file2]}' | jq -c .files)
	if [ $DEBUG ]; then echo "FILES IS " $FILES && echo; fi
	COMMIT_DATA=$(jq -n \
	--arg message message \
	--arg whodat 'automation@cribl:commit' \
	--arg group group \
	--arg groupname defaultHybrid \
	--arg files files \
	--argjson filelist $FILES \
	'{($message):$whodat,($group):$groupname,($files):$filelist}' | jq -c)
	if [ $DEBUG ]; then echo "COMMIT_DATA is " $COMMIT_DATA && echo; fi

	## Make a commit
	echo "Making a commit with curl POST and nested JSON"
	echo
	COMMIT_RESPONSE=$(curl -s -X POST \
	https://main-$INSTANCE_ID.cribl.cloud/api/v1/version/commit \
	-H "Authorization: Bearer $TOKEN" \
	-H "accept: application/json" \
	-H "Content-Type: application/json" \
	-d "$COMMIT_DATA")
	if [ $DEBUG ]; then echo "COMMIT_RESPONSE IS "$COMMIT_RESPONSE && echo; fi

	## Parse a string ID from the response above
	COMMIT_ID=$(echo $COMMIT_RESPONSE | jq -r .items[0].commit)
	if [ $DEBUG ]; then echo "COMMIT_ID is " $COMMIT_ID; fi

	if [ -n "$COMMIT_ID" ]; then
		echo "We have a commit ID!  Making a commit"
		echo "Making json data object"
		DEPLOY_DATA=$(jq -n \
		--arg version version \
		--arg c_id $COMMIT_ID \
		'{($version):$c_id}' | jq -c)
		if [ $DEBUG ]; then echo "DEPLOY_DATA is " $DEPLOY_DATA && echo; fi
		echo "curl PATCH to deply"
		curl -s -X PATCH \
		https://main-$INSTANCE_ID.cribl.cloud/api/v1/master/groups/defaultHybrid/deploy \
		-H "Authorization: Bearer $TOKEN" \
		-H "accept: application/json" \
		-H "Content-Type: application/json" \
		-d "$DEPLOY_DATA"
	else
		echo "No commit to deploy"
	fi
}
function UPLOAD_CITY_MMDB {
	## Make API call to upload new mmdb file and capture temp filename
	echo "Uploading new mmbdb file and capturing temp filename"
	echo
	TEMP_FILENAME=$(curl -s -X PUT \
	https://main-$INSTANCE_ID.cribl.cloud/api/v1/m/defaultHybrid/system/lookups?filename=GeoLite2-City.mmdb \
	-H "Authorization: Bearer $TOKEN" \
	-H 'accept: application/json' \
	-H "Content-Type: text/csv" \
	--data-binary @$CITY_PATH)
	if [ $DEBUG ]; then echo "TEMP_FILENAME IS "$TEMP_FILENAME && echo; fi

	## Parse out the fileinfo
	FILENAME=$(echo $TEMP_FILENAME | jq -r .filename)
	if [ $DEBUG ]; then echo "FILENAME IS " $FILENAME && echo; fi

	## Create nested JSON body to send via curl PATCH to update lookup file
	echo "Creating nested JSON to send via curl PATCH to update lookup file"
	echo
	INFO=$(jq -n \
	--arg filename filename \
	--arg mmdb "$FILENAME" \
	'{($filename):$mmdb}' | jq -c )
	if [ $DEBUG ]; then echo "INFO is " $INFO && echo; fi
	PATCH_DATA=$(jq -n \
	--arg id id \
	--arg file_id 'GeoLite2-City.mmdb' \
	--arg fileInfo fileInfo \
	--argjson info $INFO \
	'{($id):$file_id,($fileInfo):$info}' | jq -c )
	if [ $DEBUG ]; then echo "PATCH_DATA IS " $PATCH_DATA && echo; fi

	## Make curl PATCH to update the existing file with the new temp file
	echo "Updating lookup file with curl PATCH"
	echo
	FILE_UPDATE=$(curl -s -X PATCH \
	https://main-$INSTANCE_ID.cribl.cloud/api/v1/m/defaultHybrid/system/lookups/GeoLite2-City.mmdb \
	-H "Authorization: Bearer $TOKEN" \
	-H 'accept: application/json' \
	-H "Content-Type: application/json" \
	-d "$PATCH_DATA")
	if [ $DEBUG ]; then echo "FILE_UPDATE output is " $FILE_UPDATE && echo; fi

	## Make a nested JSON body to send via curl PATCH for commit
	echo "Creating nested JSON to send for commit"
	echo
	FILES=$(jq -n \
	--arg files files \
	--arg file1 'groups/defaultHybrid/data/lookups/GeoLite2-City.mmdb' \
	--arg file2 'groups/defaultHybrid/data/lookups/GeoLite2-City.yml' \
	'{($files):[$file1,$file2]}' | jq -c .files)
	if [ $DEBUG ]; then echo "FILES IS " $FILES && echo; fi
	COMMIT_DATA=$(jq -n \
	--arg message message \
	--arg whodat 'automation@cribl:commit' \
	--arg group group \
	--arg groupname defaultHybrid \
	--arg files files \
	--argjson filelist $FILES \
	'{($message):$whodat,($group):$groupname,($files):$filelist}' | jq -c)
	if [ $DEBUG ]; then echo "COMMIT_DATA is " $COMMIT_DATA && echo; fi

	## Make a commit
	echo "Making a commit with curl POST and nested JSON"
	echo
	COMMIT_RESPONSE=$(curl -s -X POST \
	https://main-$INSTANCE_ID.cribl.cloud/api/v1/version/commit \
	-H "Authorization: Bearer $TOKEN" \
	-H "accept: application/json" \
	-H "Content-Type: application/json" \
	-d "$COMMIT_DATA")
	if [ $DEBUG ]; then echo "COMMIT_RESPONSE IS "$COMMIT_RESPONSE && echo; fi

	## Parse a string ID from the response above
	COMMIT_ID=$(echo $COMMIT_RESPONSE | jq -r .items[0].commit)
	if [ $DEBUG ]; then echo "COMMIT_ID is " $COMMIT_ID; fi

	if [ -n "$COMMIT_ID" ]; then
		echo "We have a commit ID!  Making a commit"
		echo "Making json data object"
		DEPLOY_DATA=$(jq -n \
		--arg version version \
		--arg c_id $COMMIT_ID \
		'{($version):$c_id}' | jq -c)
		if [ $DEBUG ]; then echo "DEPLOY_DATA is " $DEPLOY_DATA && echo; fi
		echo "curl PATCH to deply"
		curl -s -X PATCH \
		https://main-$INSTANCE_ID.cribl.cloud/api/v1/master/groups/defaultHybrid/deploy \
		-H "Authorization: Bearer $TOKEN" \
		-H "accept: application/json" \
		-H "Content-Type: application/json" \
		-d "$DEPLOY_DATA"
	else
		echo "No commit to deploy"
	fi
}

function VERSION_CONTROL_COMMIT {
	## Make a commit to the master branch in version control
	echo "Making a JSON data objet"
	PUSH_DATA=$(jq -n \
	--arg message message \
	--arg text "Making a commit here" \
	'{($message):$text}' | jq -c)
	echo $PUSH_DATA
	echo "Making a commit to master branch in version control"
	echo
	VS_COMMIT=$(curl -s -X POST \
	https://main-$INSTANCE_ID.cribl.cloud/api/v1/version/commit \
	-H "Authorization: Bearer $TOKEN" \
	-H "accept: application/json" \
	-H "Content-Type: application/json" \
	-d "$PUSH_DATA"
	)
	echo $VS_COMMIT
}

## Flow Control - don't let it all happen at once
GET_AUTH_TOKEN

if [ $ASN ]; then
	UPLOAD_ASN_MMDB
fi

if [ $CITY ]; then
	UPLOAD_CITY_MMDB
fi

VERSION_CONTROL_COMMIT