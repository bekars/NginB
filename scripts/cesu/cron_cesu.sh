#!/bin/sh
BASE_PATH=/home/apuadmin/baiyu

${BASE_PATH}/split_cesu_table.pl >/tmp/split_cesu_table.log 2>&1
${BASE_PATH}/cesu_daily.pl --do_db --do_all >/tmp/cesu_daily.log 2>&1
${BASE_PATH}/analysis_daily.pl --do_db --do_analysis >/tmp/analysis_daily.log 2>&1
${BASE_PATH}/send_analysis_mail.pl >/tmp/send_analysis_mail.log 2>&1


