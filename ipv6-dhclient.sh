#!/bin/bash
# ipv6-dhclient - https://github.com/outime/ipv6-dhclient/

if [[ "$USER" != "root" ]]; then
        echo "Sorry, you need to run this as root"
        exit 1
fi

if [[ ! -e /etc/debian_version ]]; then
        echo "This script only runs under Debian-based distros"
        exit 1
fi

while :
do
clear
    echo "WARNING: Network will restart at the end of this script so any existing connections will be dropped!"
    
    while [[ $INTERFACE = "" ]]; do
        read -e -p "Your interface (eth0 by default): " -i "eth0" INTERFACE
    done
    
    if grep -lq "iface $INTERFACE inet6 static" /etc/network/interfaces; then
        echo "Looks like you have IPv6 already enabled for that interface"
        exit 1
    fi
    
    while [[ $BLOCK_ADDR = "" ]]; do # to be replaced with regex
        read -p "Your IPv6 block address (e.g. 2001:bb8:3e23:200::): " BLOCK_ADDR
    done
    
    while ! [[ $BLOCK_SUBNET =~ ^[0-9]+$ ]]; do
        read -p "Subnet for your block (e.g. if it's /56, input 56):" BLOCK_SUBNET
    done

    while [[ $BLOCK_DUID = "" ]]; do # to be replaced with regex
        read -p "Associated DUID (e.g. 00:03:00:00:34:b0:0c:47:4a:0e): " BLOCK_DUID
    done

    INTERFACES_FILE="/etc/network/interfaces"
    echo "iface $INTERFACE inet6 static" >> $INTERFACES_FILE
    echo "address $BLOCK_ADDR" >> $INTERFACES_FILE
    echo "netmask $BLOCK_SUBNET" >> $INTERFACES_FILE
    echo "accept_ra 1" >> $INTERFACES_FILE
    echo "pre-up dhclient -cf /etc/dhcp/dhclient6.conf -pf /run/dhclient6.$INTERFACE.pid -6 -P $INTERFACE" >> $INTERFACES_FILE
    echo "pre-down dhclient -x -pf /run/dhclient6.$INTERFACE.pid" >> $INTERFACES_FILE

    DHCLIENT6_FILE="/etc/dhcp/dhclient6.conf"
    echo "interface \"$INTERFACE\" {" >> $DHCLIENT6_FILE
    echo "send dhcp6.client-id $BLOCK_DUID;" >> $DHCLIENT6_FILE
    echo "request;" >> $DHCLIENT6_FILE
    echo "}" >> $DHCLIENT6_FILE

    sysctl -w net.ipv6.conf.$INTERFACE.autoconf=0
    echo "net.ipv6.conf.$INTERFACE.autoconf=0" >> /etc/sysctl.conf

    ifdown $INTERFACE && ifup $INTERFACE

    ping6 -c 4 ipv6.google.com
    if [ $? -eq 0 ]; then
        echo "Success!"
        exit 0
    else
        echo "Something went wrong :("
        exit 1
    fi
done
