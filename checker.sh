#!/bin/bash

while getopts ":r:z:" opt; do
  case $opt in
    r) opt_r="$OPTARG"
    ;;
    z) opt_z="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

referral_code=${VACCINATION_REFERRAL_CODE:-$opt_r}
if [ -z "$referral_code" ]; then
  echo "Referral code not set!"
  echo "Pass it as argument -r or set it as environment variable VACCINATION_REFERRAL_CODE"
  exit 1
fi

zip_code=${ZIP_CODE:-$opt_z}
if [ -z "$zip_code" ]; then
  echo "ZIP code not set!"
  echo "Pass it as argument -z or set it as environment variable ZIP_CODE"
  exit 1
fi

#TODO: find the request that gets the set-cookie header in the response and use it for the request
#       otherwise this will only work for a limited time

auth_string=($(echo -n ":$referral_code" | base64))
http_response=$(curl -s -o response.json -w '%{http_code}' "https://003-iz.impfterminservice.de/rest/suche/terminpaare?plz=$zip_code" -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:86.0) Gecko/20100101 Firefox/86.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H "Referer: https://003-iz.impfterminservice.de/impftermine/suche/$referral_code/$zip_code" -H 'Content-Type: application/json' -H 'Cache-Control: no-cache' -H "Authorization: Basic $auth_string" -H 'Connection: keep-alive' -H 'Cookie: TODO')


if [ $http_response != "200" ]; then
  echo "Error requesting appointment! Status Code:"
  echo $http_respoonse
else
  echo "Received response for appointment request. Checking availability..."
  appointment_options=($(jq -r '.terminpaare | length' response.json))
  if [ $appointment_options -eq 0 ]; then
    echo "No appointments available"
  else
    echo "Received appointment options! Notifying..."
    zenity --warning --text 'IMPFTERMIN VERFÜGBAR!!!'
  fi
fi
