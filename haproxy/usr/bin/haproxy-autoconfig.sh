#!/bin/bash

haproxyConfig=/etc/haproxy/haproxy.cfg
haproxyConfigTemp=/tmp/haproxy-tmp.cfg
nginxIpstmpFile=/tmp/nginxIps
logFile=/var/log/haproxy-autoconfig.log
nginxIps=()

echo -e "\n$(date) Starting Autoconfig Script" >> $logFile

# Retrieve Auto-Scaling-Group IP Addresses
for i in `aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name msosa-scaling-group --region eu-west-1 | grep -i instanceid  | awk '{ print $2}' | cut -d',' -f1| sed -e 's/"//g'`
do
nginxIps=(${nginxIps[@]} $(aws ec2 describe-instances --instance-ids $i | grep -i PublicIpAddress | awk '{ print $2 }' | cut -d "," -f1 | sed  's/"//' | sed  's/"//'))
done;


# Copy haproxy configuration to temporary location
cp $haproxyConfig $haproxyConfigTemp

# Remove Old Backend Servers
sed -i '/server nginx/d' $haproxyConfigTemp

# Generate File With New Servers Ip's
for index in ${!nginxIps[*]}
do
    echo -e "\tserver nginx$index ${nginxIps[$index]}:80 check" >> $nginxIpstmpFile
done

cat $nginxIpstmpFile >> $haproxyConfigTemp

# Check HAProxy Configuration File
/usr/sbin/haproxy -c -V -f $haproxyConfigTemp &>> $logFile && passConfigCheck=true

if [ $passConfigCheck ]
then
        echo -e "\n$(date) Applying configuration" >> $logFile
        cp $haproxyConfigTemp $haproxyConfig
        echo -e "\n$(date) Reloading configuration" >> $logFile
        /etc/init.d/haproxy reload &>> $logFile
else
        echo -e "\n$(date) Couldn't apply configuration due to some errors" >> $logFile
fi

# Delete Temp Files
rm $nginxIpstmpFile
rm $haproxyConfigTemp

