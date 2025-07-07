#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y openvpn easy-rsa jq curl

# Set up IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Create OpenVPN directory structure
mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/

# Set up Easy-RSA variables
cd /etc/openvpn/easy-rsa
cat > vars << 'EOF'
export KEY_COUNTRY="GB"
export KEY_PROVINCE="London"
export KEY_CITY="London"
export KEY_ORG="VPN-Server"
export KEY_EMAIL="admin@vpn-server.local"
export KEY_CN="VPN-Server"
export KEY_NAME="VPN-Server"
export KEY_OU="VPN-Server"
export PKCS11_MODULE_PATH="dummy"
export PKCS11_PIN="dummy"
EOF

# Initialize PKI with proper environment
export EASYRSA_BATCH=1
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa build-client-full client nopass
./easyrsa gen-dh
openvpn --genkey secret ta.key

# Copy certificates to OpenVPN directory
cp pki/ca.crt /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/private/server.key /etc/openvpn/
cp pki/dh.pem /etc/openvpn/
cp ta.key /etc/openvpn/

# Create OpenVPN server configuration
cat > /etc/openvpn/server.conf << 'EOF'
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 60
tls-auth ta.key 0
cipher AES-256-GCM
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

# Wait for network interface to be ready
sleep 30

# Get the primary network interface name
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# Configure iptables for NAT with correct interface
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $PRIMARY_INTERFACE -j MASQUERADE
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT
iptables -A FORWARD -d 10.8.0.0/24 -j ACCEPT

# Install and configure iptables-persistent
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
iptables-save > /etc/iptables/rules.v4

# Enable and start OpenVPN
systemctl enable openvpn@server
systemctl start openvpn@server

# Create client configuration directory
mkdir -p /root/client-configs/files
chmod 755 /root/client-configs

# Create client configuration template
cat > /root/client-configs/base.conf << 'EOF'
client
dev tun
proto udp
remote YOUR_VPN_SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
keepalive 10 60
ping-restart 30
cipher AES-256-GCM
auth SHA256
verb 3
EOF

# Create script to generate client config
cat > /root/client-configs/make_config.sh << 'EOF'
#!/bin/bash

KEY_DIR=/etc/openvpn/easy-rsa/pki
OUTPUT_DIR=/root/client-configs/files
BASE_CONFIG=/root/client-configs/base.conf

mkdir -p ${OUTPUT_DIR}

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/issued/client.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/private/client.key \
    <(echo -e '</key>\n<tls-auth>') \
    /etc/openvpn/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/client.ovpn

echo "key-direction 1" >> ${OUTPUT_DIR}/client.ovpn
EOF

chmod +x /root/client-configs/make_config.sh

# Generate client config
sleep 10
/root/client-configs/make_config.sh

# Log completion
echo "Lightsail OpenVPN setup completed at $(date)" >> /var/log/openvpn-setup.log