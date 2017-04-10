#!/bin/bash

echo "You Raspberry Pi 3 Will Become a Onion Router" 

sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install hostapd isc-dhcp-server -y
sudo apt-get install iptables-persistent -y

sudo sed -i 's/option domain-name "example.org";/# option domain-name "example.org";/g' /etc/dhcp/dhcpd.conf
sudo sed -i 's/option domain-name-servers ns1.example.org, ns2.example.org;/# option domain-name-servers ns1.example.org, ns2.example.org;/g' /etc/dhcp/dhcpd.conf
sudo sed -i 's/#authoritative;/authoritative;/g' /etc/dhcp/dhcpd.conf


sudo sh -c "echo 'subnet 192.168.42.0 netmask 255.255.255.0 {
	range 192.168.42.10 192.168.42.50;
	option broadcast-address 192.168.42.255;
	option routers 192.168.42.1;
	default-lease-time 600;
	max-lease-time 7200;
	option domain-name "local";
	option domain-name-servers 8.8.8.8, 8.8.4.4;

}' >> /etc/dhcp/dhcpd.conf"


sudo sed -i 's/INTERFACES=""/INTERFACES="wlan0"/g' /etc/default/isc-dhcp-server
sudo ifdown wlan0
sudo rm -r /etc/network/interfaces


sudo sh -c "echo '# interfaces(5) file used by ifup(8) and ifdown(8)


source directory /etc/network/interfaces.d
auto lo
iface lo inet loopback 
iface eth0 inet dhcp
allow-hotplug wlan0

iface wlan0 inet static
 address 192.168.42.1
 netmask 255.255.255.0' >> /etc/network/interfaces"



sudo ifconfig wlan0 192.168.42.1


echo "Name Your Onion Router:"
read SSID

echo ""

echo "Password For Your Onion Router:"
read PASS


sudo sh -c "echo '

interface=wlan0
#driver=rtl871xdrv
ssid=$SSID
country_code=US
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASS
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
wpa_group_rekey=86400
ieee80211n=1
wme_enabled=1' >> /etc/hostapd/hostapd.conf"


sudo sed -i 's/#DAEMON_CONF=""/DAEMON_CONF="/etc/hostapd/hostapd.conf"/g' /etc/default/hostapd
sudo sed -i 's/DAEMON_CONF=/DAEMON_CONF=/etc/hostapd/hostapd.conf/g' /etc/init.d/hostapd
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf



sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

sudo sh -c "iptables-save > /etc/iptables/rules.v4"
sudo timeout 2 /usr/sbin/hostapd /etc/hostapd/hostapd.conf



sudo mv /usr/share/dbus-1/system-services/fi.epitest.hostap.WPASupplicant.service ~/

sudo service hostapd start 
sudo service isc-dhcp-server start
sudo update-rc.d hostapd enable 
sudo update-rc.d isc-dhcp-server enable
sudo service isc-dhcp-server status

sudo service hostapd status



echo "Time to Install TOR"

sudo apt-get update
sudo apt-get install tor -y


sudo sed '/## https://www.torproject.org/docs/faq#torrc/Log notice file /var/log/tor/notices.log

VirtualAddrNetwork 10.192.0.0/10
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1
TransPort 9040
TransListenAddress 192.168.42.1
DNSPort 53
DNSListenAddress 192.168.42.1' /etc/tor/torrc

sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 22 -j REDIRECT --to-ports 22
sudo iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040
sudo iptables -t nat -L
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
sudo touch /var/log/tor/notices.log
sudo chown debian-tor /var/log/tor/notices.log
sudo chmod 644 /var/log/tor/notices.log
ls -l /var/log/tor
sudo service tor start
sudo service tor status
sudo update-rc.d tor enable


sudo mv reboot.sh /etc/init.d/reboot.sh
sudo chmod 775 /etc/init.d/reboot.sh
sudo update-rc.d reboot.sh defaults

echo "Your Onion Router Is Ready For Use After The Reboot"
sleep 5
sudo reboot now
