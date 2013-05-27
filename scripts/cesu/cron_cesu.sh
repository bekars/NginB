#!/bin/sh
BASE_PATH=/home/apuadmin/baiyu

${BASE_PATH}/split_cesu_table.pl
${BASE_PATH}/cesu_daily.pl --do_db
${BASE_PATH}/analysis_daily.pl --do_db --do_analysis
${BASE_PATH}/send_analysis_mail.pl


