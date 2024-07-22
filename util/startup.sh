#!/bin/bash

if [ -z "$1" ]; then
  SCENARIO="1"
else
  SCENARIO="$1"
fi

source /opt/xilinx/xcdr/setup.sh
export HOME=/root
apt-get update
rm /opt/xilinx/ffmpeg/bin/ffmpeg
wget -O /usr/local/bin/ffmpeg https://lostshadow.s3.amazonaws.com/augmented-hardware-transcoding/transcode/ffmpeg
chmod +x /usr/local/bin/ffmpeg


NEW_DIR="/opt/xilinx/xrt/lib"
if ! grep -q "^${NEW_DIR}$" /etc/ld.so.conf; then
  echo "Adding ${NEW_DIR} to /etc/ld.so.conf"
  echo "${NEW_DIR}" >> /etc/ld.so.conf
else
  echo "${NEW_DIR} is already present in /etc/ld.so.conf"
fi
ldconfig

# Variables
NGINX_VERSION=1.21.3
NGINX_SRC_DIR=/usr/local/src/nginx-$NGINX_VERSION
RTMP_MODULE_DIR=/usr/local/src/nginx-rtmp-module-master

# Update package lists and install dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g zlib1g-dev wget unzip

# Download and extract Nginx
cd /usr/local/src
wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
tar -zxvf nginx-$NGINX_VERSION.tar.gz

# Download and extract the RTMP module
wget https://github.com/arut/nginx-rtmp-module/archive/master.zip
unzip master.zip

# Compile and install Nginx with the RTMP module
cd $NGINX_SRC_DIR
./configure --with-http_ssl_module --add-module=$RTMP_MODULE_DIR
make -j
make install

# Configure Nginx for RTMP
wget -O "/usr/local/nginx/conf/nginx.conf" "https://lostshadow.s3.amazonaws.com/augmented-hardware-transcoding/nginx/nginx.conf.${SCENARIO}"
wget -O /usr/local/nginx/html/player.html https://lostshadow.s3.amazonaws.com/augmented-hardware-transcoding/nginx/player.html

tee /etc/systemd/system/nginx.service > /dev/null <<EOL
[Unit]
Description=A high performance web server and a reverse proxy server
After=network.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s stop

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd to apply the new service
systemctl daemon-reload

# Enable Nginx to start on boot
systemctl enable nginx

# Start Nginx service
systemctl start nginx

# Display Nginx version to confirm installation
/usr/local/nginx/sbin/nginx -v

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

npm install -g pm2

mkdir /opt/transcode
wget -O "/opt/transcode/index.js" "https://lostshadow.s3.amazonaws.com/augmented-hardware-transcoding/transcode/index.js.${SCENARIO}"
wget -O /opt/transcode/package.json https://lostshadow.s3.amazonaws.com/augmented-hardware-transcoding/transcode/package.json
wget -O /opt/transcode/ecosystem.config.js https://lostshadow.s3.amazonaws.com/augmented-hardware-transcoding/transcode/ecosystem.config.js
cd /opt/transcode
npm install
pm2 start
pm2 save
pm2 startup