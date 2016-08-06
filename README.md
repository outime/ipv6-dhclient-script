# ipv6-dhclient-script
Simple IPv6 configuration script for Debian (Ubuntu...) and RedHat (CentOS, Fedora...) based distros, mainly for [Online.net](http://www.online.net/) servers but valid for any network that provides IPv6 access through prefix delegation i.e. the static address is configured by the client and an identifier (DUID) is sent to the DHCP server in order to get functional routes.

Servers provided by [Online.net](http://www.online.net/) won't come with IPv6 enabled by default so this makes things a bit easier specially when owning multiple servers and IPv6 needs to be enabled by hand in each one.

The script has been successfully tested under:

* Ubuntu Server 16.04 & 14.04
* Debian 7 & 8
* CentOS 6 & 7
* Some Proxmox VE setups (see issue [#1](https://github.com/outime/ipv6-dhclient-script/issues/1) and [#2](https://github.com/outime/ipv6-dhclient-script/issues/2))

Just run the script and follow the instructions:

`$ ./ipv6-dhclient-script.sh`

You can also pass parameters straight away:

`$ ./ipv6-dhclient-script.sh <interface> <address block> <subnet> <duid>`

Some questions were answered [in a LowEndTalk thread](http://www.lowendtalk.com/discussion/40695/ipv6-dhclient-auto-configuration-script-online-net) although I really encourage you to open an issue [here](https://github.com/outime/ipv6-dhclient-script/issues/new) instead of posting there.
