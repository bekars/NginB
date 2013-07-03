#!/bin/sh

BASE_PATH="/home/baiyu/GitHub/NginB/scripts/cesu"
BASE_PATH2="/home/baiyu/GitHub/NginB/scripts"
TARGET_PATH="cesudb:/home/apuadmin/baiyu"

#FILES=cron_cesu.sh
FILES='{cron_cesu.sh,analysis_daily.pl}'

scp ${BASE_PATH}/cron_cesu.sh ${TARGET_PATH}/
scp ${BASE_PATH}/cesu_daily.pl ${TARGET_PATH}/
scp ${BASE_PATH}/analysis_daily.pl ${TARGET_PATH}/
scp ${BASE_PATH}/send_analysis_mail.pl ${TARGET_PATH}/
scp ${BASE_PATH}/split_cesu_table.pl ${TARGET_PATH}/

scp ${BASE_PATH2}/Speedy/* ${TARGET_PATH}/Speedy/
scp ${BASE_PATH2}/BMD/* ${TARGET_PATH}/BMD/

