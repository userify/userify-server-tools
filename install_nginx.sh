#! /bin/bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

echo "Please wait while reconfiguring NGINX."
echo "Showing you each command as it's run."
echo "The new or upgraded files are: "
echo "   /etc/init.d/userify-server"
echo "   /etc/nginx/nginx.conf/etc/nginx/nginx.conf"
echo "   /opt/userify-server/userify-start"
set -x

# Update the Userify start/stop script
cat << "EOF" | sudo tee /etc/init.d/userify-server >/dev/null
#!/bin/bash
# /etc/rc.d/init.d/userify-server
# Userify Server startup script
# This script is designed for maximum compatibility across all distributions,
# including those that are running systemd and sysv

# Add $redis-server below if needed.

### BEGIN INIT INFO
# Provides:          userify-server
# Required-Start:    $network $syslog
# Required-Stop:     $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start userify-server at boot time
# Description:       Starts the Userify Server https://userify.com from /opt/userify-server.
### END INIT INFO

# chkconfig: 2345 20 80
# description: Userify Server startup script

case "$1" in
    start)
        # removed stop
        echo -n "Starting Userify Server: "
        /opt/userify-server/userify-start &
        ;;
    stop)
        echo -n "Shutting down Userify Server: "
        pkill userify-s
        pkill -9 userify-s
        ;;
    status)
        pgrep userify-server
        ;;
    restart)
        $0 stop; $0 start
        ;;
    reload)
        $0 stop; $0 start
        ;;
    *)
        echo "Usage: userify-server {start|stop|status|reload|restart}"
        exit 1
        ;;
esac
EOF

set +e

sudo chmod +x /etc/init.d/userify-server
if [ -f /usr/sbin/chkconfig ]; then
    sudo chkconfig --add userify-server
    sudo chkconfig userify-server on
fi
[ -f /usr/sbin/update-rc.d ] && sudo update-rc.d userify-server defaults
sudo systemctl daemon-reload
sudo systemctl enable userify-server

# NGINX first startup will fail if Userify isn't stopped first.
sudo systemctl stop userify-server
sudo pkill userify-s
sudo pkill -9 userify-s

pgrep userify-s
set -e

which yum 2>/dev/null && YUM="TRUE"
which apt-get 2>/dev/null && APT="TRUE"

if [ ! -d /etc/nginx ]; then
    if [ -n "$APT" ]; then
        sudo apt-get -qqy install nginx
    elif [ -n "$YUM" ]; then
        sudo yum -q -y install nginx
    else
        echo "Unable to install nginx. Please install nginx manually and re-run."
        exit 99
    fi
fi

set +e
sudo mkdir -p /var/log/nginx
sudo useradd -s /bin/false nobody
sudo groupadd nobody
sudo usermod -G nobody nobody
set -e

cat << "EOF" | sudo tee /etc/nginx/nginx.conf >/dev/null
user nobody;
worker_processes 6;
pid /var/run/nginx.pid;
# error_log /dev/null crit;
error_log /var/log/nginx/error.log info;

events {
    worker_connections 768;
    multi_accept on;
}

http {

    upstream proxybackend {
        server 127.0.0.1:8120;
        server 127.0.0.1:8121;
        server 127.0.0.1:8122;
        server 127.0.0.1:8123;
        # uncomment these on higher cores.
        # don't forget to modify
        # /opt/userify-server/userify-start
        # server 127.0.0.1:8124;
        # server 127.0.0.1:8125;
        # server 127.0.0.1:8126;
        # server 127.0.0.1:8127;
    }
    proxy_buffers 256 8k;
    client_max_body_size 16M;
    access_log off;
    # expires 1m;
    open_file_cache off;
    sendfile_max_chunk 32k;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    # server_tokens off;
    # server_names_hash_bucket_size 64;
    # server_name_in_redirect off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    server {
       listen 80 default_server;
       return 301 https://$host$request_uri;
    }

    server {
        server_name _;
        listen 443 ssl;
        ssl_certificate_key /opt/userify-server/host.pem;
        ssl_certificate /opt/userify-server/host.pem;
        # recommended to enable across all accounts:
        # add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;
        root /opt/userify-server/web/;
        index index.html;
        proxy_connect_timeout 10;
        proxy_read_timeout 10;
        proxy_next_upstream error timeout;
        location / {
            try_files $uri $uri/ index.html;
        }
        location /installer.sh {
            root /opt/userify-server/web/shim/;
        }
        location /shim.py {
            root /opt/userify-server/web/shim/;
        }
        location /api {
            proxy_redirect off;
            # proxy_set_header        Host            $host;
            proxy_set_header        X-Real-IP       $remote_addr;
            # Please comment this out when using an ELB or another load balancer
            # as well in front of NGINX.
            proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_pass http://proxybackend;
        }
    }
}

EOF

sudo systemctl enable nginx
sudo systemctl stop nginx
sleep 1
sudo systemctl start nginx || (sudo tail -n 100 /var/log/nginx/error.log; exit 99)


cat << "EOF" | sudo tee /opt/userify-server/userify-start >/dev/null
#! /bin/bash
# 
# Userify Startup
# This is a PRODUCTION startup script.
# Each process auto restarts with 4 second delay.
# Please change false to true in the following 'if' statements
# if you have more virtual processors available.


# let redis start up
while "x$(redis-cli get foo)" != "xbar"
do
    # redis still starting
    sleep 1
done

# Redis settings (if single-server Userify with local Redis)
echo 1 > /proc/sys/vm/overcommit_memory
echo 511 > /proc/sys/net/core/somaxconn
echo never > /sys/kernel/mm/transparent_hugepage/enabled

# increase available open filenames for production usage
/sbin/sysctl -w fs.file-max=1048576
ulimit -n 1048576

cd /opt/userify-server

if true; then
    (
    while true
    do
        PORTNUM=8120
        sudo /opt/userify-server/userify-server $PORTNUM 2>&1 |logger -t userify-server
        sleep 4
    done
    ) &
fi

if true; then
    (
    while true
    do
        PORTNUM=8121
        sudo /opt/userify-server/userify-server $PORTNUM 2>&1 |logger -t userify-server
        sleep 4
    done
    ) &
fi

if true; then
    (
    while true
    do
        PORTNUM=8122
        sudo /opt/userify-server/userify-server $PORTNUM 2>&1 |logger -t userify-server
        sleep 4
    done
    ) &
fi

if true; then
    (
    while true
    do
        PORTNUM=8123
        sudo /opt/userify-server/userify-server $PORTNUM 2>&1 |logger -t userify-server
        sleep 4
    done
    ) &
fi

if false; then
    (
    while false
    do
        PORTNUM=8124
        sudo /opt/userify-server/userify-server $PORTNUM 2>&1 |logger -t userify-server
        sleep 4
    done
    ) &
fi

if false; then
    (
    while false
    do
        PORTNUM=8125
        sudo /opt/userify-server/userify-server $PORTNUM 2>&1 |logger -t userify-server
        sleep 4
    done
    ) &
fi

if false; then
    (
    while false
    do
        PORTNUM=8126
        sudo /opt/userify-server/userify-server $PORTNUM 2>&1 |logger -t userify-server
        sleep 4
    done
    ) &
fi

if false; then
    (
    while false
    do
        PORTNUM=8127
        sudo /opt/userify-server/userify-server $PORTNUM 2>&1 |logger -t userify-server
        sleep 4
    done
    ) &
fi

exit 0

EOF

sudo chmod +x /opt/userify-server/userify-start
sudo systemctl start userify-server
