#!/usr/bin/env bash

# redirect our output into a logfile
exec &> /root/bootstrap.log

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=1"
# allow pubkey login from these hosts
echo "Adding public keys to authorized_keys file..."
mkdir /root/.ssh 2>/dev/null
cat <<EOF >/root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnjjx8LAnHxL6mbRb/sWPsFJXAR7ZJEbpSXmNR78QYkGzH8QK1vg+fP9/RzMKSxNOsbASNIhX1wRCQf9zHQmrJVZz2NMfphW5J4952BGKJUr3ozUcf+DD6OEf8V7J9Ps/lFJpZrhxH5hqWWHFRq52We4vJrnTwAESx80YHpxRa4foAxhNaQUFqqleyBzj6c+bJWR8NNBAZ7EC/w2dRDXsULEpOfhNJWcey2MVLUl7hHJalbuveMuUzpqzCErkYUNhDA+MEKzlfsq0qMmBRb0VxIk03Y704Nt5wrQl2msXgM01U//yZbP15hXbQkd3NkRyAQk+MkWKCAp/XJ9IY/JYj root@esdm-xen1-16
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAqWov1i1l4LpHx/PlvNjMBP1ZTa3exSaIf9akdUC1d2tL70SR9nG0TMVIvFn19jQLrja459mg4NeF/Nab+3cN3k+NVbt7H/NgCRxv6JSJ2962ZLlUTGa+VcYy/372CGSPncrQQiXGB2y76yMDEY2SlMzOXLx7793AHWs49gHxzJuOjJT7ioO6wKHKTaIDs9lg3SkIZ8qrmZvw2XrI3uPxeNg1Bz1Y1ltY4dirdY/xkXxDMpIUVZVR6Ui83GA11npwnS+xnnLEqoOLV52t91/A80slCxrLPpvcZJ8+0oK+xQt0JPDYlPdMB/46qdMbe+wXd04fDy6Om8sb9W6uB8E3Aw== root@esdm-xen1.esdm.co.uk
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0n12uWH3NwP0QRXd3K7PG2NIPmwyn97meXT4/N2M86lXr8dPlTvRI7hsOydL+u9YRAP/oK6u/Gu3APrzUUENBWM5oA7uMf8WO9NyGR1LV+pc3ok5RLTnj1Rto0IQDJhB2Avtn4cpZ80prR/GPlscIXNN8uQttYTU4w3pXpgyBFznOhwjAHjbK+7bzTFrGaafATC5oEbzi2d3wni9K13A8DAm00CWNXRxWhXc34UK7Q3G8mo1SmM3DzDYP682BzilR5v07ZNn1kd0HCy5DPSQoAeJZFAQpvf+vE7LjJVFd1AoMkxMTV7/pED3k847isMfJHQkpem3q8ijZTDadWPBp root@host3-16
EOF
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=2"
# now create some storage users
echo "Creating Users..."
for u in 1 2 3; do
  useradd -m -c "Storage User${u}" storage${u} -s /bin/bash
  mkdir /home/storage${u}/.ssh
  chmod 700 /home/storage${u}/.ssh
  chown storage${u}:storage${u} /home/storage${u}/.ssh
  cp -f /root/.ssh/authorized_keys /home/storage${u}/.ssh/authorized_keys
  chmod 600 /home/storage${u}/.ssh/authorized_keys
  chown storage${u}:storage${u} /home/storage${u}/.ssh/authorized_keys
done

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=3"
# update
apt update
apt -y upgrade

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=4"
# install some required packages
apt -y install joe npm git libvhdi-utils shorewall build-essential redis-server libpng-dev python-minimal tmux wget debconf rsyslog

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=5"
# create a preseed config for exim4
cat <<EOF >/root/preseed.txt
exim4-config exim4/dc_relay_nets string
exim4-config exim4/dc_minimaldns select false
exim4-config exim4/use_split_config select false
exim4-config exim4/dc_smarthost string
exim4-config exim4/dc_local_interfaces string  127.0.0.1 ; ::1
exim4-config exim4/dc_eximconfig_configtype select internet site; mail is sent and received directly using SMTP
exim4-config exim4/dc_localdelivery select mbox format in /var/mail/
exim4-config exim4/dc_relay_domains string
EOF
debconf-set-selections /root/preseed.txt

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=6"
apt -y install exim4

systemctl enable exim4
systemctl start exim4

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=7"
# setup shorewall
cat <<EOF >/etc/shorewall/interfaces
###############################################################################
?FORMAT 2
###############################################################################
#ZONE           INTERFACE               OPTIONS
NET             eth0
EOF

cat <<EOF >/etc/shorewall/zones
###############################################################################
#ZONE   TYPE            OPTIONS         IN                      OUT
#                                       OPTIONS                 OPTIONS
FW      firewall
NET     ipv4
EOF

cat <<EOF >/etc/shorewall/policy
###############################################################################
#SOURCE DEST    POLICY          LOG     LIMIT:          CONNLIMIT:
#                               LEVEL   BURST           MASK
NET     FW     DROP
FW     NET     ACCEPT
EOF

cat <<EOF >/etc/shorewall/rules
######################################################################################################################################################################################
#ACTION         SOURCE          DEST            PROTO   DEST    SOURCE          ORIGINAL        RATE            USER/   MARK    CONNLIMIT       TIME         HEADERS         SWITCH
#                                                       PORT    PORT(S)         DEST            LIMIT           GROUP
#SECTION ALL
#SECTION ESTABLISHED
#SECTION RELATED
?SECTION NEW

# OVH monitoring:
ACCEPT:info     NET:37.187.231.251      FW     icmp
ACCEPT:info     NET:151.80.231.244      FW     icmp
ACCEPT:info     NET:151.80.231.245      FW     icmp
ACCEPT:info     NET:151.80.231.246      FW     icmp
ACCEPT:info     NET:151.80.231.247      FW     icmp
ACCEPT:info     NET:213.186.33.62       FW     icmp
ACCEPT:info     NET:92.222.184.0/24     FW     icmp
ACCEPT:info     NET:92.222.185.0/24     FW     icmp
ACCEPT:info     NET:92.222.186.0/24     FW     icmp
ACCEPT:info     NET:167.114.37.0/24     FW     icmp
ACCEPT:info     NET:213.186.45.4        FW     icmp
ACCEPT:info     NET:213.251.184.9       FW     icmp
ACCEPT:info     NET:37.59.0.235         FW     icmp
ACCEPT:info     NET:8.33.137.2          FW     icmp
ACCEPT:info     NET:213.186.33.13       FW     icmp
ACCEPT:info     NET:213.186.50.98       FW     icmp
ACCEPT:info     NET:213.32.0.250        FW     icmp
ACCEPT:info     NET:213.32.0.251        FW     icmp

ACCEPT:info     NET:37.187.231.251      FW     udp     6100:6200
ACCEPT:info     NET:151.80.231.244      FW     udp     6100:6200
ACCEPT:info     NET:151.80.231.245      FW     udp     6100:6200
ACCEPT:info     NET:151.80.231.246      FW     udp     6100:6200
ACCEPT:info     NET:151.80.231.247      FW     udp     6100:6200

ACCEPT:info     NET:hengwm.ateb.co.uk   FW     icmp
ACCEPT          NET:hengwm.ateb.co.uk   FW     tcp     22,80,443
ACCEPT          NET:host3-16.ateb.co.uk FW     tcp     22

ACCEPT          NET:82.69.43.209        FW     tcp     22,80,443
ACCEPT          NET:esdm-xen1.esdm.co.uk FW    tcp     22
ACCEPT          NET:esdm-xen1-16.esdm.co.uk FW tcp     22
EOF

shorewall try /etc/shorewall
systemctl enable shorewall

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=8"
# create a self signed cert...
echo "Creating a self signed cert..."
openssl req \
    -new \
    -newkey rsa:4096 \
    -days 3650 \
    -nodes \
    -x509 \
    -subj "/C=GB/ST=Powys/L=Talgarth/O=ESDM/CN=xo-server" \
    -keyout /etc/ssl/private/xo-server.key \
    -out /etc/ssl/private/xo-server.crt

chmod 600 /etc/ssl/private/xo-server.key

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=9"
# install lts version of node
echo "Installing node LTS..."
npm install n -g
n 6.11.4
apt -y remove npm
apt -y autoremove
ln -s /usr/local/n/versions/node/6.11.4/bin/node /usr/bin/node
ln -s /usr/local/n/versions/node/6.11.4/bin/npm /usr/bin/npm
npm install yarn -g

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=10"
echo "Installing XO-Server..."
cd /opt
wget https://raw.githubusercontent.com/SimonAnnetts/OVHStorageServer/master/xo-server-x64.tar.bz2
tar -jxf xo-server-x64.tar.bz2
wget https://raw.githubusercontent.com/SimonAnnetts/OVHStorageServer/master/xo-web-x64.tar.bz2
tar -jxf xo-web-x64.tar.bz2

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=11"
echo "Creating xo-server configs..."
cat <<EOF >/opt/xo-server/config.yaml
# Configuration of the embedded HTTP server.
http:
  listen:
    -
      # hostname: '192.168.54.16'
      port: 80
    -
      #hostname: '127.0.0.1'
      port: 443
      cert: '/etc/ssl/private/xo-server.crt'
      key: '/etc/ssl/private/xo-server.key'

  redirectToHttps: true
  mounts:
    '/': '/opt/xo-web/dist/'

  # List of proxied URLs (HTTP & WebSockets).
  proxies:
    # '/any/url': 'http://localhost:54722'

# Connection to the Redis server.
redis:
    #socket: /var/run/redis/redis.sock
    #uri: redis://redis.company.lan/42
    #renameCommands:
    #  del: '3dda29ad-3015-44f9-b13b-fa570de92489'
    #  srem: '3fd758c9-5610-4e9d-a058-dbf4cb6d8bf0'

datadir: '/opt/xo-server/data'

plugins:
  xo-server-transport-email:
  xo-server-backup-reports:

EOF

cat <<EOF >/etc/systemd/system/xo-server.service
# systemd service for XO-Server.

[Unit]
Description= XO Server
After=network-online.target

[Service]
Environment="DEBUG=xo:main"
ExecStart=/opt/xo-server/bin/xo-server
Restart=always
SyslogIdentifier=xo-server

[Install]
WantedBy=multi-user.target
EOF

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=12"
systemctl enable xo-server
systemctl start xo-server

wget -O /dev/null -o /dev/null "http://esdm-xen1-06.esdm.co.uk/OVH/?stage=13"
exit 0
