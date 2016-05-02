#! /bin/bash -e

# Userify Server Installer Script
# Copyright (c) 2016 Userify Corporation
# By Jamieson Becker
# curl https://github.com/userify/userify-server-tools/blob/master/install_userify_server.sh > install_userify_server.sh
# sudo bash ./install_userify_server.sh

echo "Please paste the URL for your userify server installable."
read url

# RHEL/CENT/AMAZON PREREQUISITES
# The sudoers fix is due to a long-standing bug in RHEL that will be corrected in RHEL8:
# https://bugzilla.redhat.com/show_bug.cgi?id=1020147

sudo which yum && (
echo "Installing RHEL/CENT/Amazon Prerequisites"
sudo yum install -q -y python-devel libffi-devel openssl-devel libxml2-devel \
    gcc gcc-c++ libxslt-devel openldap-devel cyrus-sasl-devel python-pip libjpeg-devel
sudo yum install -q -y \
    http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-6.noarch.rpm
sudo yum install -q -y --enablerepo=epel redis python-pip && \
    sudo pip install pyopenssl && \
    sudo chkconfig redis on && \
    sudo sed -i "s/Defaults requiretty/# &/" /etc/sudoers && \
    sudo service redis start )

# DEBIAN/UBUNTU PREREQUISITES
sudo which apt-get && \
    (
    echo "Installing Debian/Ubuntu Prerequisites"
    sudo apt-get update
    sudo apt-get -qy upgrade
    sudo apt-get install -qyy python-pip build-essential python-dev libffi-dev zlib1g-dev \
    libjpeg-dev libssl-dev python-lxml libxml2-dev libldap2-dev libsasl2-dev redis-server
    )

# ALL DISTRIBUTIONS
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
sudo chmod 755 /etc/init.d/userify-server /opt/userify-server/userify-server
[ -f /usr/sbin/chkconfig ] && sudo chkconfig userify-server on
[ -f /usr/sbin/update-rc.d ] && sudo update-rc.d userify-server enable


echo
echo The server will finish installation, set permissions, and create a
echo /opt/userify-server/web directory containing the static files used by the
echo server.

sudo /opt/userify-server/userify-server
sudo /opt/userify-server/userify-start &
