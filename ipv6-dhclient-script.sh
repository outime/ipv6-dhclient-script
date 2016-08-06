#!/bin/bash
# ipv6-dhclient-script - https://github.com/outime/ipv6-dhclient-script/

INTERFACE=$1
BLOCK_ADDR=$2
BLOCK_SUBNET=$3
BLOCK_DUID=$4

DEFAULT_INTERFACE=`ip route get 8.8.8.8 | awk '{print $5; exit}'`

write_from_template () {
    sed -e "s/{{INTERFACE}}/$INTERFACE/g" -e "s/{{BLOCK_ADDR}}/$BLOCK_ADDR/g" -e "s/{{BLOCK_SUBNET}}/$BLOCK_SUBNET/g" -e "s/{{BLOCK_DUID}}/$BLOCK_DUID/g" templates/$1 >> $2
}

if [[ "$(id -u)" != 0 ]]; then
    echo "Sorry, you need to run this as root"
    exit 1
fi

if [[ -e /etc/debian_version ]]; then
    DISTRO="Debian"
elif [[ -f /etc/centos-release ]]; then
    RELEASE=$(rpm -q --queryformat '%{VERSION}' centos-release)
    DISTRO="CentOS${RELEASE}"
else
    echo "This distribution type/version is not supported"
    exit 1
fi

while :
do
clear
    if ! [[ -f /proc/net/if_inet6 ]]; then
        echo "Seems that IPv6 is not supported by your kernel or the module is not loaded (is it blacklisted?)"
        exit 1
    fi

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

    echo "Working..."

    if [[ $DISTRO = "Debian" ]]; then
        write_from_template Debian/etc_network_interfaces /etc/network/interfaces
    elif [[ $DISTRO = "CentOS6" ]]; then
        write_from_template CentOS6/etc_init.d_ipv6-dhclient /etc/init.d/ipv6-dhclient
        chmod +x /etc/init.d/ipv6-dhclient
    elif [[ $DISTRO = "CentOS7" ]]; then
        write_from_template CentOS7/etc_systemd_system_ipv6-dhclient.service /etc/systemd/system/ipv6-dhclient.service
    fi

    write_from_template etc_dhcp_dhclient6.conf /etc/dhcp/dhclient6.conf

    if [[ $DISTRO = "Debian" ]]; then
        sysctl -w net.ipv6.conf.$INTERFACE.autoconf=0
        write_from_template Debian/etc_sysctl.conf /etc/sysctl.conf
        ifdown $INTERFACE && ifup $INTERFACE
    elif [[ $DISTRO = "CentOS6" ]]; then
        chkconfig --add ipv6-dhclient
        service ipv6-dhclient start
    elif [[ $DISTRO = "CentOS7" ]]; then
        systemctl enable ipv6-dhclient
        systemctl restart ipv6-dhclient
    fi

    echo "Testing IPv6 connectivity..."
    IPV6_TEST=$(ping6 -c 8 ipv6.google.com | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')
    if [[ $IPV6_TEST > 0 ]]; then
        echo "Success!"
        exit 0
    else
        echo "Something went wrong :("
        exit 1
    fi
done
