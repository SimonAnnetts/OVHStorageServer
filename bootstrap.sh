#!/usr/bin/env bash

# redirect our output into a logfile
exec &> /root/bootstrap.log

# update
apt update
apt -y upgrade

# install some required packages
apt -y install joe npm git exim4 libvhdi-utils shorewall build-essential redis-server libpng-dev python-minimal tmux wget

systemctl enable exim4

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

ACCEPT          NET:82.69.43.209        FW     tcp     22,80,443
ACCEPT          NET:esdm-xen1.esdm.co.uk FW    tcp     22
ACCEPT          NET:esdm-xen1-16.esdm.co.uk FW tcp     22
EOF

shorewall try /etc/shorewall
systemctl enable shorewall

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

# install lts version of node
echo "Installing node LTS..."
npm install n -g
n 6.11.4
apt remove npm
apt -y autoremove
ln -s /usr/local/n/versions/node/6.11.4/bin/node /usr/bin/node
ln -s /usr/local/n/versions/node/6.11.4/bin/npm /usr/bin/npm
npm install yarn -g

cd /opt
wget https://raw.githubusercontent.com/SimonAnnetts/OVHStorageServer/master/xo-server.tar.bz2
tar -jxf xo-server.tar.bz2

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

systemctl enable xo-server
systemctl start xo-server

# now create some storage users
for u in 1 2 3; do
  useradd -m -c "Storage User${u}" storage${u} -s /bin/bash
  mkdir /home/storage${u}/.ssh
  chmod 700 /home/storage${u}/.ssh
  chown storage${u}:storage${u} /home/storage${u}/.ssh
  touch /home/storage${u}/.ssh/authorized_keys
  chmod 600 /home/storage${u}/.ssh/authorized_keys
  chown storage${u}:storage${u} /home/storage${u}/.ssh/authorized_keys
done









