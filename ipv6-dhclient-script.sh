#!/bin/bash
# ipv6-dhclient-script - https://github.com/outime/ipv6-dhclient-script/

INTERFACE=$1
BLOCK_ADDR=$2
BLOCK_SUBNET=$3
BLOCK_DUID=$4

if [[ "$USER" != "root" ]]; then
        echo "Sorry, you need to run this as root"
        exit 1
fi

if [[ -e /etc/debian_version ]]; then
    DISTRO="Debian"
    DEFAULT_INTERFACE="eth0"
elif [[ -f /etc/redhat-release ]]; then
    DISTRO="Redhat"
    DEFAULT_INTERFACE="enp2s0"
else
    echo "This distribution is not supported"
    exit 1
fi

while :
do
clear
    echo "WARNING: Network will restart at the end of this script so any existing connections will be dropped!"
    
    while [[ $INTERFACE = "" ]]; do
        read -e -p "Interface where IPv6 will be enabled: " -i $DEFAULT_INTERFACE INTERFACE
    done
    
    CURRENT_IPV6=$(ip addr show dev $INTERFACE | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d')
    if [[ $? -eq 0 ]]; then
        echo "You have the following IPv6 addreses configured for $INTERFACE:"
        echo "$CURRENT_IPV6"
        read -e -p "Continue? [Y/n]: " -i "Y" SKIP
        if ! [[ $SKIP =~ ^([yY][eE][sS]|[yY])$ ]]; then
            exit 1
        fi
    fi
    
    while [[ $BLOCK_ADDR = "" ]]; do # to be replaced with regex
        read -p "Your IPv6 block address (e.g. 2001:bb8:3e23:200::): " BLOCK_ADDR
    done
    
    while ! [[ $BLOCK_SUBNET =~ ^[0-9]+$ ]]; do
        read -p "Subnet for your block (e.g. if it's /56, input 56): " BLOCK_SUBNET
    done

    while [[ $BLOCK_DUID = "" ]]; do # to be replaced with regex
        read -p "Associated DUID (e.g. 00:03:00:00:34:b0:0c:47:4a:0e): " BLOCK_DUID
    done

    if [[ $DISTRO = "Debian" ]]; then
        INTERFACES_FILE="/etc/network/interfaces"
        echo "" >> $INTERFACES_FILE
        echo "iface $INTERFACE inet6 static" >> $INTERFACES_FILE
        echo "address $BLOCK_ADDR" >> $INTERFACES_FILE
        echo "netmask $BLOCK_SUBNET" >> $INTERFACES_FILE
        echo "accept_ra 1" >> $INTERFACES_FILE
        echo "pre-up dhclient -cf /etc/dhcp/dhclient6.conf -pf /run/dhclient6.$INTERFACE.pid -6 -P $INTERFACE" >> $INTERFACES_FILE
        echo "pre-down dhclient -x -pf /run/dhclient6.$INTERFACE.pid" >> $INTERFACES_FILE
    elif [[ $DISTRO = "Redhat" ]]; then
        INTERFACES_FILE="/etc/systemd/system/ipv6-dhclient.service"
        echo "[Unit]" >> $INTERFACES_FILE
        echo "Description=$INTERFACE IPv6" >> $INTERFACES_FILE
        echo "After=network.target" >> $INTERFACES_FILE
        echo "" >> $INTERFACES_FILE
        echo "[Service]" >> $INTERFACES_FILE
        echo "Type=oneshot" >> $INTERFACES_FILE
        echo "RemainAfterExit=yes" >> $INTERFACES_FILE
        echo "ExecStart=/usr/sbin/dhclient -cf /etc/dhcp/dhclient6.conf -pf /run/dhclient6.$INTERFACE.pid -6 -P $INTERFACE" >> $INTERFACES_FILE
        echo "ExecStart=/usr/sbin/ifconfig $INTERFACE inet6 add $BLOCK_ADDR/$BLOCK_SUBNET" >> $INTERFACES_FILE
        echo "" >> $INTERFACES_FILE
        echo "ExecStop=/usr/bin/killall dhclient" >> $INTERFACES_FILE
        echo "ExecStop=/usr/sbin/ifconfig $INTERFACE inet6 del $BLOCK_ADDR/$BLOCK_SUBNET" >> $INTERFACES_FILE
        echo "" >> $INTERFACES_FILE
        echo "[Install]" >> $INTERFACES_FILE
        echo "WantedBy=multi-user.target" >> $INTERFACES_FILE
    fi

    DHCLIENT6_FILE="/etc/dhcp/dhclient6.conf"
    echo "interface \"$INTERFACE\" {" >> $DHCLIENT6_FILE
    echo "send dhcp6.client-id $BLOCK_DUID;" >> $DHCLIENT6_FILE
    echo "request;" >> $DHCLIENT6_FILE
    echo "}" >> $DHCLIENT6_FILE

    if [[ $DISTRO = "Debian" ]]; then
        sysctl -w net.ipv6.conf.$INTERFACE.autoconf=0
        echo "net.ipv6.conf.$INTERFACE.autoconf=0" >> /etc/sysctl.conf
        ifdown $INTERFACE && ifup $INTERFACE
    elif [[ $DISTRO = "Redhat" ]]; then
        systemctl enable ipv6-dhclient
        systemctl restart ipv6-dhclient
    fi

    IPV6_TEST=$(ping6 -c 4 ipv6.google.com | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')
    if [[ $IPV6_TEST > 0 ]]; then
        echo "Success!"
        exit 0
    else
        echo "Something went wrong :("
        exit 1
    fi
done
