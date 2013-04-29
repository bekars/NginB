#!/bin/sh
yday=$1
today=$2
row=total_time
#row=first_screen_time
#row=download_speed


if [ "$yday" == "" ]; then
    yday=`date -d"last day" +"%Y-%m-%d"`
fi

if [ "$today" == "" ]; then
    today=`date -d"today" +"%Y-%m-%d"`
fi

echo "Analysis $yday $today data ..."

./analysis.pl $row $yday $today
cat speed_result.$yday~$today.txt | awk '{print($2,$1)}' | sort -n > speed_sort.$yday~$today.txt

