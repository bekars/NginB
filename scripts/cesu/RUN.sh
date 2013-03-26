#!/bin/sh
row=total_time
#row=first_screen_time
./analysis.pl $row $1 $2
cat speed_result.$1~$2.txt | awk '{print($2,$1)}' | sort -n > speed_sort.$1~$2.txt

