#! /bin/bash -e

# Userify Server Installer Script
# Copyright (c) 2016 Userify Corporation
# By Jamieson Becker
# curl https://raw.githubusercontent.com/userify/userify-server-tools/master/install_userify_server.sh > install_userify_server.sh
# sudo bash ./install_userify_server.sh

# PYTHON=${PYTHON:-$(which python)}
# if  [ $("$PYTHON -c 'import platform; print platform.python_version_tuple()[0]') = 3 ]; then
#     echo "Although work is progressing, some libraries that Userify relies on currently support Python 2 only."
#     exit 1
# fi


echo "Please paste the URL for your userify server installable."
read url

# RHEL/CENT/AMAZON PREREQUISITES
# The sudoers fix is due to a long-standing bug in RHEL that will be corrected in RHEL8:
# https://bugzilla.redhat.com/show_bug.cgi?id=1020147

# consider replacing full redis server with hiredis.x86_64


# RHEL/CENTOS PREREQUISITES
function rhel_prereqs {
    echo "Installing RHEL/CENT/Amazon Prerequisites"
    sudo yum install -q -y python-devel libffi-devel openssl-devel libxml2-devel \
        gcc gcc-c++ libxslt-devel openldap-devel cyrus-sasl-devel python-pip libjpeg-devel
        ntp ntpdate ntp-doc
    sudo ntpdate pool.ntp.org
    sudo chkconfig ntpd on
    sudo service ntpd start
    sudo yum install -q -y \
        http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-6.noarch.rpm
    sudo yum install -q -y --enablerepo=epel redis python-pip && \
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
    curl "https://bootstrap.pypa.io/get-pip.py" | sudo /usr/bin/python
}


sudo which yum && rhel_prereqs
sudo which apt-get && debian_prereqs

# ALL DISTRIBUTIONS

# if any required packages are missing, they will be installed automatically by
# userify-server upon first startup, but doing this first helps catch any
# first-start issues.

# pyasn1 and cryptography installs are to work around SNI issues with older
# openssl

# see also https://github.com/kennethreitz/requests/issues/2022


set -e
sudo pip install \
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
    gevent \
    gevent-websocket \
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



# OLD Python versions (python <= 2.5) also need ssl installed:
# (it's built in on python 2.6 and later.)
# sudo pip install ssl 
# However, we do not officially support distributions
# that are that old for the server.

sudo mkdir /opt/userify-server
sudo chown $(whoami ) /opt/userify-server/
curl "$url" | gunzip > /opt/userify-server/userify-server


cat << "EOF" > userify-server-init
#! /bin/bash
# /etc/rc.d/init.d/userify-server
# Userify Server startup script
# This script is designed for maximum compatibility across all distributions,
# including those that are running systemd and sysv

# chkconfig: 2345 20 80
# description: Userify Server startup script
case "$1" in
    start)
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
[ -f /usr/sbin/chkconfig ] && sudo chkconfig userify-server on
[ -f /usr/sbin/update-rc.d ] && sudo update-rc.d userify-server enable

cat << 'EOF' > userify-start
#! /bin/sh
#
# Userify Startup
# Auto restart with 3 seconds.
# 

(while true;
do

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

echo
echo The server will finish installation, set permissions, and create a
echo /opt/userify-server/web directory containing the static files used by the
echo server.

# This completes installation
sudo /opt/userify-server/userify-start &
