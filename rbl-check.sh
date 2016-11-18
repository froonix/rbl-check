#!/bin/bash
###
#
# Überprüft mehrere Domains mit der RBL-CHECK.ORG API.
# Die E-Mail Benachrichtigung übernimmt der Cron-Daemon.
# Version 1.0.1 vom 10.09.2014 von Christian Schrötter.
#
# TODO: BT-Kategorie & Wikiseite anlegen und im HAPPYTEC-Blog veröffentlichen!
#
# Als Positivtest kann 127.0.0.1 (localhost) verwendet werden.
# Zumindestens CYMRU-BOGON listete diese Adresse am 29.04.2014.
# Seit 10.09.2014 werden auch DNS-Fehlermeldungen korrekt erkannt.
#
# Hinweis: Aktuell werden nur IPv4-Adressen unterstützt!
#
#   IPS    = Liste von IPv4-Adressen
#   HOSTS  = Liste mit Hostnamen (A-Records)
#   SIMPLE = Hostnamen exklusive $SUFFIX
#
###

IPS=""
HOSTS=""
SIMPLE=""
SUFFIX=""

if [[ "$1" == "dbg" ]]
then
	dbg=1
else
	dbg=0
fi

function RBLcheck
{
	ip="$1"
	host=${2:-$ip}
	if [[ "${dbg}" == "1" ]]; then echo "Debug: Checking ${ip} (${host}) …" 1>&2; fi
	result=`wget -q -O - "http://rbl-check.org/rbl_api.php?ipaddress=${ip}" | grep -v "notlisted"`
	status="$?"

	if [[ "${status}" == "0" ]]
	then
		while read -r line
		do
			if [[ "${line}" != "" ]]
			then
				rblname=`cut -d";" -f1 <<< "${line}"`
				rblstatus=`cut -d";" -f4 <<< "${line}"`

				# EDIS-DE false positive...
				if [[ "${rblname}" != "RATS" ]]
				then
					echo "IP ${ip} (${host}) is ${rblstatus} at ${rblname}"'!'
				fi
			fi
		done <<< "${result}"
	else
		echo "[  ERR  ] ${host} (${status})" 1>&2
	fi
}

for i in $IPS
do
	RBLcheck "${i}"
done

for i in $SIMPLE
do
	HOSTS="${HOSTS} ${i}${SUFFIX}"
done

for i in $HOSTS
do
	file=`mktemp` # <-- seit 10.09.2014!
	dig A "${i}" +short 1>"${file}" 2>/dev/null
	status=$?; ip=`cat "${file}"`; rm "${file}"

	if [[ "${status}" == 0 && "${ip}" != "" ]]
	then
		for h in $ip
		do
			RBLcheck "${h}" "${i}"
		done
	else
		echo "[ NO IP ] ${i}" 1>&2
	fi
done
