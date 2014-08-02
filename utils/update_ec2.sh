#!/bin/sh
git push
ssh ec2 'cd /home/baiyu/GitHub/NginB/ && git pull'
