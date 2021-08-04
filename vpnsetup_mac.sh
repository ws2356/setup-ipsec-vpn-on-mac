#!/bin/sh
#
# Script for automatic setup of an IPsec VPN server on Mac OS.

# DO NOT RUN THIS SCRIPT ON YOUR PC OR Linux!
#
# The latest version of this script is available at:
#
# Copyright (C) 2014-2018 Neeson <neesonqk@gmail.com>
# Based on the work of StrongSwan & Lin Song's 'setup-ipsec-vpn' project

# =====================================================

# Define your own values for these variables
# - IPsec pre-shared key, VPN username and password
# - All values MUST be placed inside 'single quotes'
# - DO NOT use these special characters within values: \ " '

YOUR_IPSEC_PSK=''
YOUR_USERNAME=''
YOUR_PASSWORD=''
YOUR_SERVER_ADDR=''

# Important notes:   https://git.io/vpnnotes
# Setup VPN clients: https://git.io/vpnclients

# =====================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SYS_DT="$(date +%F-%T)"
unameOut="$(uname -s)"

exiterr()  { echo "Error: $1" >&2; exit 1; }
exiterr2() { exiterr "'apt-get install' failed."; }
conf_bk() { /bin/cp -f "$1" "$1.old-$SYS_DT" 2>/dev/null; }
bigecho() { echo; echo "## $1"; echo; }

cat <<EOF

================================================

Before starting, you should be noted below term(s):

1) Homebrew is required for this setup, it will be auto installed if yet installed.

================================================

EOF

read -p "Ok, I'm well noted. (Y/n)" agreed
agreed=${agreed:-Y}
agreed=`echo "${agreed}" | tr '[a-z]' '[A-Z]'`
echo "$agreed"

if [ "$agreed" != "Y" ] ; then
    printf "You disagreed the terms, exiting now."
    exit 0;
fi

printf "You've agreed all terms \n\n"

check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

vpnsetup() {

case "${unameOut}" in
    Darwin*)    os_type=Mac;;
    *)          os_type="NONMACOS:${unameOut}"
esac

if [ "$os_type" != "Mac" ] ; then
    printf "\n"
    printf "### You're not running on a MacOS! ### \n"
    printf "If you want to install on a linux like system, please take a look: \n\nhttps://github.com/hwdsl2/setup-ipsec-vpn\n"
    printf "\n"
    exiterr "This script only supports MacOS";
fi

if [ "$(id -u)" != 0 ]; then
  exiterr "Script must be run as root. Try 'sudo sh $0'"
fi

read -p "Enter your IPSEC_PSK (Shared Secret):" YOUR_IPSEC_PSK
read -p "Enter your username:" YOUR_USERNAME
read -p "Enter your password:" YOUR_PASSWORD
read -p "Enter your prefered ip/domain:" YOUR_SERVER_ADDR

VPN_IPSEC_PSK="$YOUR_IPSEC_PSK"
VPN_USER="$YOUR_USERNAME"
VPN_PASSWORD="$YOUR_PASSWORD"
VPN_SERVER_ADDR="$YOUR_SERVER_ADDR"
# Used as generating pkcs12 key's export password
VPN_PKCS12_EXPORT_PWD="$(LC_CTYPE=C tr -dc 'A-HJ-NPR-Za-km-z2-9' < /dev/urandom | base64 | head -c 16)"

if [ -z "$VPN_IPSEC_PSK" ] && [ -z "$VPN_USER" ] && [ -z "$VPN_PASSWORD" ]; then
  bigecho "VPN credentials not all set by user. re-generating random PSK, password and server address..."
  VPN_IPSEC_PSK="$(LC_CTYPE=C tr -dc 'A-HJ-NPR-Za-km-z2-9' < /dev/urandom | head -c 16)"
  VPN_USER=vpnuser
  VPN_PASSWORD="$(LC_CTYPE=C tr -dc 'A-HJ-NPR-Za-km-z2-9' < /dev/urandom | head -c 16)"
fi

if [ -z "$VPN_SERVER_ADDR" ]; then  
  bigecho "Trying to auto discover IP of this server..."
  cat <<'EOF'
  In case the script hangs here for more than a few minutes,
  press Ctrl-C to abort. Then manually enter your IP/domain.
EOF
  VPN_SERVER_ADDR=`dig +short myip.opendns.com @resolver1.opendns.com`
  bigecho "IP of this server is successfully detected."
fi

if [ -z "$VPN_IPSEC_PSK" ] || [ -z "$VPN_USER" ] || [ -z "$VPN_PASSWORD" ]; then
  exiterr "All VPN credentials must be specified. Edit the script and re-enter them."
fi

if printf '%s' "$VPN_IPSEC_PSK $VPN_USER $VPN_PASSWORD" | LC_ALL=C grep -q '[^ -~]\+'; then
  exiterr "VPN credentials must not contain non-ASCII characters."
fi

case "$VPN_IPSEC_PSK $VPN_USER $VPN_PASSWORD" in
  *[\\\"\']*)
    exiterr "VPN credentials must not contain these special characters: \\ \" '"
    ;;
esac

bigecho "VPN setup is in progress... Please be patient."

bigecho "Checking homebrew status..."

# Check Homebrew
homebrewInstalled=`sudo -u $SUDO_USER brew -v`;
if [ -z "$homebrewInstalled" ]; then
    bigecho "Homebrew has not been installed yet, now trying to install Homebrew."
    echo `sudo -u $SUDO_USER /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`
else
    bigecho "Homebrew looks good, now installing packages required for setup..."
fi

bigecho "Installing packages required for the VPN..."

echo `sudo -u $SUDO_USER brew install strongswan`

bigecho "Configurating certifications..."

# Create and change to working dir
mkdir -p ~/vpn
cd ~/vpn || exiterr "Cannot enter ~/vpn"

bigecho "Generating CA pem..."
echo `ipsec pki --gen --outform pem > ca.pem`

bigecho "Signing private key via CA pem..."
echo `ipsec pki --self --in ca.pem --dn "C=com, O=myvpn, CN=VPN CA" --ca --outform pem >ca.cert.pem`

bigecho "Generating server pem"
echo `ipsec pki --gen --outform pem > server.pem`

bigecho "Signing server key via CA pem..."
echo `ipsec pki --pub --in server.pem | ipsec pki --issue --cacert ca.cert.pem --cakey ca.pem --dn "C=com, O=myvpn, CN=$VPN_SERVER_ADDR" --san="$VPN_SERVER_ADDR" --flag serverAuth --flag ikeIntermediate --outform pem > server.cert.pem`

bigecho "Generating client key..."
echo `ipsec pki --gen --outform pem > client.pem`

bigecho "Signing client key via CA..."
echo `ipsec pki --pub --in client.pem | ipsec pki --issue --cacert ca.cert.pem --cakey ca.pem --dn "C=com, O=myvpn, CN=VPN Client" --outform pem > client.cert.pem`

bigecho "Generating pkcs12 certification..."
echo `openssl pkcs12 -export -inkey client.pem -in client.cert.pem -name "client" -certfile ca.cert.pem -caname "VPN CA" -out client.cert.p12 -password pass:$VPN_PKCS12_EXPORT_PWD`

bigecho "Installing certifications..."
echo `cp -r ca.cert.pem /usr/local/etc/ipsec.d/cacerts/`
echo `cp -r server.cert.pem /usr/local/etc/ipsec.d/certs/`
echo `cp -r server.pem /usr/local/etc/ipsec.d/private/`
echo `cp -r client.cert.pem /usr/local/etc/ipsec.d/certs/`
echo `cp -r client.pem  /usr/local/etc/ipsec.d/private/`

bigecho "Creating VPN configuration..."

# Create IPsec (Libreswan) config
conf_bk "/usr/local/etc/ipsec.conf"
cat > /usr/local/etc/ipsec.conf <<EOF
# ipsec.conf - strongSwan IPsec configuration file

# basic configuration

config setup
	uniqueids=no

conn mac-os-cert
    keyexchange=ikev1
    fragmentation=yes
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn android-xauth-psk
    keyexchange=ikev1
    left=%defaultroute
    leftauth=psk
    leftsubnet=0.0.0.0/0
    right=%any
    rightauth=psk
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    auto=add

conn networkmanager-strongswan
    keyexchange=ikev2
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn windows7
    keyexchange=ikev2
    ike=aes256-sha1-modp1024!
    rekey=no
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    auto=add

conn sample-self-signed
     leftsubnet=10.1.0.0/16
     leftcert=selfCert.der
     leftsendcert=never
     right=192.168.0.2
     rightsubnet=10.2.0.0/16
     rightcert=peerCert.der
     auto=start

conn sample-with-ca-cert
     leftsubnet=10.1.0.0/16
     leftcert=myCert.pem
     right=192.168.0.2
     rightsubnet=10.2.0.0/16
     rightid="C=CH, O=Linux strongSwan CN=peer name"
     auto=start

EOF

# Specify IPsec PSK
conf_bk "/usr/local/etc/ipsec.secrets"
cat > /usr/local/etc/ipsec.secrets <<EOF
# ipsec.secrets - strongSwan IPsec secrets file
: RSA server.pem
: PSK "$VPN_IPSEC_PSK"
: XAUTH "VPN_IPSEC_PSK"
VPN_USER %any : EAP "$VPN_PASSWORD"
EOF

bigecho "Updating Firewall rules..."

# TODO: replace to dynamic ipsec version number
echo `/usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/Cellar/strongswan/5.6.2/libexec/ipsec/charon`

bigecho "Starting services..."
echo `ipsec start`

cat <<EOF

================================================

IPsec VPN server is now ready for use!

Connect to your new VPN with these details:

Server IP: $VPN_SERVER_ADDR
IPsec PSK: $VPN_IPSEC_PSK
Username: $VPN_USER
Password: $VPN_PASSWORD
Certification Path: ~/vpn
Pksc12 Export Pass: $VPN_PKCS12_EXPORT_PWD

Write these down. You'll need them to connect!

Important notes:   https://git.io/vpnnotes
Setup VPN clients: https://git.io/vpnclients

================================================

EOF

}

## Defer setup until we have the complete script
vpnsetup "$@"

exit 0
