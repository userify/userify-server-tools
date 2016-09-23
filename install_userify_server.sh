#!/bin/bash -ex

# Userify Server Installer Script
# Copyright (c) 2016 Userify Corporation
# Installation instructions:
# https://userify.com/docs/enterprise/installation-enterprise/

if [[ ! $URL ]]; then
cat <<- EOF
PLEASE NOTE: AUTOMATIC REDIS INSTALLATION

This script will automatically install Redis Server Database for a
single-server installation.

For a multi-server or using third-party redis (Elasticache, RedisLabs, etc)
support, remove the local Redis server after installation completes, as
Redis is no longer required for all installations.

Now, please paste the required URL for your userify server installation.
EOF
read -r URL
fi

# RHEL/CENT/AMAZON PREREQUISITES
# The sudoers fix is due to a long-standing bug in RHEL that will be corrected in RHEL8:
# https://bugzilla.redhat.com/show_bug.cgi?id=1020147

#
# for Enterprise with autoscaling,
# consider offering option to replace
# full redis server with client hiredis.x86_64
#

epel_release=http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm

# RHEL/CENTOS PREREQUISITES
function rhel_prereqs {
    echo "Installing RHEL/CENT/Amazon Prerequisites"
    sudo yum install -q -y python-devel libffi-devel openssl-devel libxml2-devel \
        gcc gcc-c++ libxslt-devel openldap-devel cyrus-sasl-devel libjpeg-devel \
        ntp ntpdate ntp-doc
    sudo ntpdate pool.ntp.org
    set +e
    sudo chkconfig --add ntpd
    sudo chkconfig ntpd on
    set -e
    sudo service ntpd start
    curl "https://bootstrap.pypa.io/get-pip.py" | sudo /usr/bin/env python
    sudo yum install -q -y $epel_release

    # Redis installation fails on Amazon Linux due to missing systemd:

    sudo yum install -q -y --enablerepo=epel redis && \
        sudo chkconfig redis on && \
        sudo sed -i "s/Defaults requiretty/# &/" /etc/sudoers && \
        sudo service redis start

}

# DEBIAN/UBUNTU PREREQUISITES
function debian_prereqs {
    echo "Installing Debian/Ubuntu Prerequisites"
    sudo apt-get update
    sudo apt-get -qy upgrade
    sudo apt-get install -qqy build-essential python-dev libffi-dev zlib1g-dev \
    libjpeg-dev libssl-dev python-lxml libxml2-dev libldap2-dev libsasl2-dev \
    libxslt1-dev redis-server ntpdate
    # get immediate timefix
    sudo ntpdate pool.ntp.org
    sudo apt-get install -qqy ntp
    set +e
    curl "https://bootstrap.pypa.io/get-pip.py" | sudo -H /usr/bin/env python
    set -e
}


sudo which yum 2>/dev/null && rhel_prereqs
sudo which apt-get 2>/dev/null && debian_prereqs

# ALL DISTRIBUTIONS

# if any required packages are missing, they will be installed automatically by
# userify-server upon first startup, but doing this first helps catch any
# first-start issues.

# pyasn1 and cryptography installs are to work around SNI issues with older
# openssl

# see also https://github.com/kennethreitz/requests/issues/2022

set -e
PATH="/usr/local/bin/:/usr/local/sbin/:$PATH"
pip=$(which pip)
sudo $pip install --upgrade \
    ndg-httpsclient \
    pyasn1 \
    requests \
    python-ldap \
    python-slugify \
    jinja2 \
    shortuuid \
    bottle \
    otpauth \
    qrcode \
    ipwhois \
    netaddr \
    setproctitle \
    py-bcrypt \
    termcolor \
    tomorrow \
    addict \
    pynacl \
    rq \
    boto \
    pyindent \
    spooky \
    redis \
    pillow \
    emails \
    html2text \
    pyopenssl \
    cryptography \
    paste \
    python-digitalocean \
    # gevent==1.1b4 \
    # gevent-websocket \


# OLD Python versions (python <= 2.5) also need ssl installed:
# (it's built in on python 2.6 and later.)
# sudo pip install ssl
# However, we do not officially support distributions
# that are that old for the server.

if [[ ! -d  /opt/userify-server ]]; then
    sudo mkdir /opt/userify-server
    sudo chown "$(whoami )" /opt/userify-server/
fi

# This will always overwrite the existing userify-server file with a new copy
# A basic "update/upgrade"

if [[ -f /opt/userify-server/userify-server ]]; then
    sudo rm /opt/userify-server/userify-server
fi
curl "$URL" | gunzip > /opt/userify-server/userify-server

cat << "EOF" > userify-server-init
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
        pkill userify-start
        pkill userify-server
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

sudo mv userify-server-init /etc/init.d/userify-server
if [ -f /usr/sbin/chkconfig ]; then
    set +e
    sudo chkconfig --add userify-server
    sudo chkconfig userify-server on
    set -e
fi
[ -f /usr/sbin/update-rc.d ] && sudo update-rc.d userify-server defaults

cat << "EOF" > userify-start
#!/bin/sh
#
# Userify Startup
# Auto restart with 3 seconds.
#

(while true;
do

    chmod +x /opt/userify-server/userify-server

    # userify automatically attempts to bind to 443 and 80
    # (dropping permissions after startup)
    # but will not produce an error unless it cannot bind
    # HTTP to localhost:8120 or the port number specified here.

    # For additional performance, use HA Proxy or nginx to:
    #   proxy to localhost for /api/
    #   static files to /opt/userify-server/web/

    /opt/userify-server/userify-server server "8120"
    sleep 3

done) &
EOF

sudo mv userify-start /opt/userify-server/userify-start

sudo chmod 755 /etc/init.d/userify-server /opt/userify-server/userify-server /opt/userify-server/userify-start

echo ""
echo "The server will finish installation, set permissions, and create a "
echo "/opt/userify-server/web directory containing the static files used by the"
echo "server."
echo ""

# This completes installation
sudo /opt/userify-server/userify-start &
