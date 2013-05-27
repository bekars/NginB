#!/bin/sh

BASE_PATH="/home/baiyu/GitHub/NginB/scripts/cesu"
TARGET_PATH="cesudb:/home/apuadmin/baiyu/"

#FILES=cron_cesu.sh
FILES='{cron_cesu.sh,analysis_daily.pl}'

scp ${BASE_PATH}/cron_cesu.sh ${TARGET_PATH}
scp ${BASE_PATH}/cesu_daily.pl ${TARGET_PATH}
scp ${BASE_PATH}/analysis_daily.pl ${TARGET_PATH}
scp ${BASE_PATH}/send_analysis_mail.pl ${TARGET_PATH}
scp ${BASE_PATH}/split_cesu_table.pl ${TARGET_PATH}

