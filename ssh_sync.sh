#!/bin/bash

# ----------------------------
# Set the following variable
user_home="/Users/yourname"
# Remote hostname (LAN) and MAC address
hostname="machine-a"
# User name on the remote host
username="yourname"
mac_address="11:11:11:11:11:11"

# -----------------------------


usage="Usage: $0 hosts|dns|test <remote_src_path> <local_dest_path>"

if [ "$#" -lt 3 ]; then
	if [ "$1" != "test" ]; then
		echo $usage
		exit 1
	fi
fi


# Zone file of BIND server (original file for the symbolic link)
zone_file="$user_home/Documents/named/$hostname.zone"

# Get updated IP address
ip_address=$(arp -a | grep $mac_address | cut -d' ' -f2 | tr -d '()')
if [ -z "$ip_address" ]; then
	echo "No IP address of host $hostname with MAC $mac_address on the LAN is detected."
	echo "The host may be down or not accessible at this time."
	exit 1
fi
sed_cmd="/$hostname/d"

# Update hostname to /etc/hosts
if [ "$1" == "hosts" ]; then
	echo "Updating /etc/hosts"
	sudo bash -c "sed $sed_cmd /etc/hosts > $user_home/tmp/hosts && cat $user_home/tmp/hosts > /etc/hosts"
	sudo bash -c "echo $ip_address $hostname >> /etc/hosts"

# Update zone file
elif [ "$1" == "dns" ]; then
	echo "Updating zone file for BIND server..."
	sed '/; lan-sync/d' $zone_file > $user_home/tmp/$hostname.zone \
	&& cat $user_home/tmp/$hostname.zone > $zone_file
	echo "		IN		A		$ip_address	; lan-sync" >> $zone_file

	# This is equivalent to restart and flush BIND server
	rndc stop

elif [ "$1" == "test" ]; then
	mdkir $user_home/tmp
	echo "Hostname $hostname can be mapped to IP address $ip_address ($mac_address)."
	echo "Pinging $ip_address..."
	ping -c 4 $ip_address
	echo "Ready to sync."
	exit 0

else
	echo "Invalid argument $1. Must be 'hosts' or 'dns'"
	exit 1
fi

# Remote path to be synced
src_path="$2"

# Local backup path
dest_path="$3"

# Use rsync over SSH
rsync -avz -e ssh $username@$hostname:$src_path $dest_path
