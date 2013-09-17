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


usage="Usage:\n\
$0 hosts|dns <remote_src_path> <local_dest_path>\n\
$0 test [<ip_address>]"

if [ "$#" -lt 3 ]; then
	if [ "$1" != "test" ]; then
		echo -e $usage
		exit 1
	fi
fi

# Zone file of BIND server (original file for the symbolic link)
zone_file="$user_home/Documents/named/$hostname.zone"

# Get updated IP address
ip_address=$(arp -a | grep $mac_address | cut -d' ' -f2 | tr -d '()')
if [ -z "$ip_address" ]; then
	if [ "$1" != "test" ]; then
		echo "No IP address of host $hostname with MAC $mac_address on the LAN is detected."
		echo "The host may be down or not accessible at this time."
		echo "Please run the following command if you know the IP address of $hostname:"
		echo "$0 test <ip_address>"
		exit 1
	fi
fi
sed_cmd="/$hostname/d"

# Update hostname to /etc/hosts
if [ "$1" == "hosts" ]; then
	echo "Updating /etc/hosts"
	sudo bash -c "sed $sed_cmd /etc/hosts > $user_home/tmp/hosts && cat \
	$user_home/tmp/hosts > /etc/hosts"
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
	if [ ! -d "$user_home/tmp" ]; then
		mkdir $user_home/tmp
	fi
	if [ -n "$2" ]; then
		ip_address="$2"
	elif [ -z "$ip_address" ]; then
		echo "No IP address of $hostname is retrieved."
		echo "Please specifiy IP address for test: $0 test <ip_address>"
		exit 1
	fi
	echo "Pinging $ip_address..."
	ping -c 4 $ip_address > /dev/null
	echo "Hostname $hostname can be mapped to IP address $ip_address ($mac_address)."
	echo "Ready to sync."
	exit 0

else
	echo "Invalid argument $1. Must be 'hosts', 'dns' or 'test'."
	exit 1
fi

# Remote path to be synced
src_path="$2"

# Local backup path
dest_path="$3"

# Use rsync over SSH
rsync -avz -e ssh $username@$hostname:$src_path $dest_path
