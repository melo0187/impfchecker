#!/bin/bash

while getopts ":r:z:x:m:" opt; do
  case $opt in
    r) opt_r="$OPTARG"
    ;;
    z) opt_z="$OPTARG"
    ;;
    x) opt_x="$OPTARG"
    ;;
    m) opt_m="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

mockResponse=${MOCK:-$opt_m}

onAppointment=${MOCK:-$opt_x}

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

if [ -z "$mockResponse" ]; then
 http_response="200"
else
	http_response=$(curl -c cookie-jar.txt -s -o /dev/null -w '%{http_code}' "https://003-iz.impfterminservice.de/impftermine/suche/$referral_code/$zip_code" -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:86.0) Gecko/20100101 Firefox/86.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Connection: keep-alive')

	if [ $http_response != "200" ]; then
	  echo "Error requesting required cookies! Status Code: $http_response"
	else
	  echo "Successfully fetched required cookies"
	fi

	auth_string=($(echo -n ":$referral_code" | base64))
	http_response=$(curl -b cookie-jar.txt -s -o response.json -w '%{http_code}' "https://003-iz.impfterminservice.de/rest/suche/terminpaare?plz=$zip_code" -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:86.0) Gecko/20100101 Firefox/86.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H "Referer: https://003-iz.impfterminservice.de/impftermine/suche/$referral_code/$zip_code" -H 'Content-Type: application/json' -H 'Cache-Control: no-cache' -H "Authorization: Basic $auth_string" -H 'Connection: keep-alive')
fi

if [ $http_response != "200" ]; then
  echo "Error requesting appointment! Status Code: $http_response"
else
  echo "Received response for appointment request. Checking availability..."
  appointment_options=($(jq -r '.terminpaare | length' response.json))
  if [ $appointment_options -eq 0 ]; then
    echo "No appointments available"
  else
    if [ -z "$onAppointment" ]; then
     echo "Received appointment options! Notifying..."
     zenity --warning --text 'IMPFTERMIN VERFÜGBAR!!!'
    else
       $onAppointment
    fi
  fi
fi
