#!/bin/bash

echo "Preparing the instance to be ready to run with Heat..."
echo "######################################################"
echo ""
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -f -y -q install git python-setuptools ipcalc wget
apt-get -f -y -q install python-argparse cloud-init python-psutil python-pip
pip install 'boto==2.5.2' heat-cfntools
cfn-create-aws-symlinks -s /usr/local/bin/

echo "Installing and configuring OpenVPN..."
echo "###################################"
echo ""
apt-get -f -y -q install openvpn easy-rsa
# TODO: get the floating IP from heat and avoid the following HACK
# when http://docs.openstack.org/developer/heat/template_guide/
# will be a little bit more readable.
export FLOATING_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
# OpenVPN CIDR. It has to be unique and must not overlap the CIDR of your private_net_id, public_net_id, and neither of your clients connecting to the VPN.
export VPN_CIDR=192.168.222.0/24
export OVPN_IP=$(ipcalc -nb $VPN_CIDR | grep ^Address | awk '{print $2}')
export OVPN_MASK=$(ipcalc -nb $VPN_CIDR | grep ^Netmask | awk '{print $2}')
export PRIVATE_IP_CIDR=$(ip addr show dev eth0 | grep 'inet .*$' | awk '{print $2}')
export PRIVATE_NETWORK_CIDR=$(ipcalc -nb $PRIVATE_IP_CIDR | grep ^Network | awk '{print $2}')
export PRIVATE_NETWORK_IP=$(ipcalc -nb $PRIVATE_NETWORK_CIDR | grep ^Address | awk '{print $2}')
export PRIVATE_NETWORK_MASK=$(ipcalc -nb $PRIVATE_NETWORK_CIDR | grep ^Netmask | awk '{print $2}')


cat > /etc/openvpn/route-up.sh <<EOF
#!/bin/bash
/sbin/sysctl -n net.ipv4.conf.all.forwarding > /var/log/openvpn/net.ipv4.conf.all.forwarding.bak
/sbin/sysctl net.ipv4.conf.all.forwarding=1
/sbin/iptables-save > /var/log/openvpn/iptables.save
/sbin/iptables -t nat -F
/sbin/iptables -t nat -A POSTROUTING -s $VPN_CIDR -j MASQUERADE
EOF

# Down script
cat > /etc/openvpn/down.sh <<EOF
#!/bin/bash
FORWARDING=\$(cat /var/log/openvpn/net.ipv4.conf.all.forwarding.bak)
echo "restoring net.ipv4.conf.all.forwarding=\$FORWARDING"
/sbin/sysctl net.ipv4.conf.all.forwarding=\$FORWARDING
/etc/openvpn/fw.stop
echo "Restoring iptables"
/sbin/iptables-restore < /var/log/openvpn/iptables.save
EOF

# Firewall stop script
cat > /etc/openvpn/fw.stop <<EOF
#!/bin/sh
echo "Stopping firewall and allowing everyone..."
/sbin/iptables -F
/sbin/iptables -X
/sbin/iptables -t nat -F
/sbin/iptables -t nat -X
/sbin/iptables -t mangle -F
/sbin/iptables -t mangle -X
/sbin/iptables -P INPUT ACCEPT
/sbin/iptables -P FORWARD ACCEPT
/sbin/iptables -P OUTPUT ACCEPT
EOF
chmod 755 /etc/openvpn/down.sh /etc/openvpn/route-up.sh /etc/openvpn/fw.stop

# OpenVPN server configuration
cat > /etc/openvpn/server.conf <<EOF
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
crl-verify /etc/openvpn/crl.pem
dh /etc/openvpn/dh2048.pem
server $OVPN_IP $OVPN_MASK
ifconfig-pool-persist ipp.txt
push "route $PRIVATE_NETWORK_IP $PRIVATE_NETWORK_MASK"
keepalive 10 120
tls-auth ta.key 0 # This file is secret
comp-lzo
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log /var/log/openvpn/openvpn.log
verb 3
script-security 2
duplicate-cn
route-up /etc/openvpn/route-up.sh
down /etc/openvpn/down.sh
EOF

# Sample configuration for client
cat > /tmp/openvpn.template <<EOF
client
dev tun
proto tcp
mss-fix 1300
remote $FLOATING_IP 1194
resolv-retry infinite
nobind
; user nobody
; group nogroup
persist-key
persist-tun
ns-cert-type server
comp-lzo
verb 3
ca [inline]
cert [inline]
key [inline]
tls-auth [inline] 1
EOF

mkdir /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa /etc/openvpn/
cd /etc/openvpn/easy-rsa
ln -s openssl-1.0.0.cnf openssl.cnf
source vars
./clean-all
./build-dh
KEY_EMAIL=ca@openvpn ./pkitool --initca
KEY_EMAIL=server@pilgrim ./pkitool --server server
KEY_EMAIL=client@pilgrim ./pkitool client
KEY_EMAIL=revoked@pilgrim ./pkitool revoked
./revoke-full revoked  # Generates a crl.pem revocation list
openvpn --genkey --secret keys/ta.key
ln keys/{ca.crt,server.crt,server.key,dh2048.pem,crl.pem,ta.key} /etc/openvpn/

mv /tmp/openvpn.template ./client.conf
echo "<ca>" >> client.conf
cat keys/ca.crt >> client.conf
echo "</ca>" >> client.conf
echo "<cert>" >> client.conf
cat keys/client.crt >> client.conf
echo "</cert>" >> client.conf
echo "<key>" >> client.conf
cat keys/client.key >> client.conf
echo "</key>" >> client.conf
echo "<tls-auth>" >> client.conf
cat keys/ta.key >> client.conf
echo "</tls-auth>" >> client.conf

echo "Created client config in $(pwd)/client.conf"
cat client.conf

# tar -cvjpf vpnaccess.tar.bz2 client.conf keys/ca.crt keys/client.key keys/client.crt keys/ta.key
# cp vpnaccess.tar.bz2 /tmp/
mkdir -p /var/log/openvpn
service openvpn start
