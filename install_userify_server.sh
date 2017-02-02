#!/bin/bash -ex

# Userify Server Installer Script
# Copyright (c) 2016 Userify Corporation
# Installation instructions:
# https://userify.com/docs/enterprise/installation-enterprise/

SUDO=$(which sudo)

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

# RHEL/CentOS/AMAZON PREREQUISITES
# The sudoers fix is due to a long-standing bug in RHEL that will be corrected in RHEL8:
# https://bugzilla.redhat.com/show_bug.cgi?id=1020147

#
# for Enterprise with autoscaling,
# consider offering option to replace
# full redis server with client hiredis.x86_64
#

if [[ $(uname -a |grep amzn) ]]; then
    # Error: Package: redis-2.8.19-2.el7.x86_64 (epel)
    # Requires: systemd
    cat <<- EOF
Amazon Linux does not support installation of Redis, so this script does not
support installation on Amazon Linux.  However, if you install Redis on Amazon
Linux separately, or if you are using Userify Enterprise with a non-local Redis
server, then please review this script and install separately. (Be sure to snap
an AMI afterward.) Also, if you need additional assitance, or would like a
pre-installed Userify server published to your AWS account at no additional
charge, please contact support.

EOF
    exit 1
fi

epel_release=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# RHEL/CentOS PREREQUISITES
function rhel_prereqs {
    echo "Installing RHEL/CentOS/Amazon Prerequisites"
    $SUDO pkill ntpd # this aborts next line on Amazon
    # Annoying behavior of RHEL: error status if 'nothing to do'
    set +e
    $SUDO yum install -q -y python-devel libffi-devel openssl-devel libxml2-devel \
        gcc gcc-c++ libxslt-devel openldap-devel cyrus-sasl-devel libjpeg-devel \
        ntp ntpdate ntp-doc
    $SUDO ntpdate pool.ntp.org
    set +e
    $SUDO chkconfig --add ntpd
    $SUDO chkconfig ntpd on
    set -e
    $SUDO service ntpd start
    curl -# "https://bootstrap.pypa.io/get-pip.py" | $SUDO /usr/bin/env python
    set +e
    $SUDO yum install -q -y $epel_release
    set -e

    # Redis installation fails on Amazon Linux due to missing systemd:

    $SUDO yum install -q -y --enablerepo=epel redis && \
        $SUDO chkconfig redis on && \
        $SUDO sed -i "s/Defaults requiretty/# &/" /etc/sudoers && \
        $SUDO service redis start
    set +e
    $SUDO systemctl enable redis-server

}

# DEBIAN/UBUNTU PREREQUISITES
function debian_prereqs {
    echo "Installing Debian/Ubuntu Prerequisites"
    $SUDO apt-get update
    $SUDO apt-get -qy upgrade
    $SUDO apt-get install -qqy build-essential python-dev libffi-dev zlib1g-dev \
    libjpeg-dev libssl-dev python-lxml libxml2-dev libldap2-dev libsasl2-dev \
    libxslt1-dev redis-server ntpdate curl
    # get immediate timefix
    $SUDO ntpdate pool.ntp.org
    $SUDO apt-get install -qqy ntp
    set +e
    curl -# "https://bootstrap.pypa.io/get-pip.py" | $SUDO -H /usr/bin/env python
    set -e
}


$SUDO which yum 2>/dev/null && rhel_prereqs
$SUDO which apt-get 2>/dev/null && debian_prereqs

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
$SUDO $pip install --upgrade \
    cffi \
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
    gevent \
    gevent-websocket \
    # ==1.1b4 \


# OLD Python versions (python <= 2.5) also need ssl installed:
# (it's built in on python 2.6 and later.)
# sudo pip install ssl
# However, we do not officially support distributions
# that are that old for the server.

if [[ ! -d  /opt/userify-server ]]; then
    $SUDO mkdir /opt/userify-server
    $SUDO chown "$(whoami )" /opt/userify-server/
fi

# This will always overwrite the existing userify-server file with a new copy
# A basic "update/upgrade"

if [[ -f /opt/userify-server/userify-server ]]; then
    $SUDO rm /opt/userify-server/userify-server
fi
curl -# "$URL" | gunzip > /opt/userify-server/userify-server
chmod +x  /opt/userify-server/userify-server

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

$SUDO mv userify-server-init /etc/init.d/userify-server
chmod +x /etc/init.d/userify-server
if [ -f /usr/sbin/chkconfig ]; then
    set +e
    $SUDO chkconfig --add userify-server
    $SUDO chkconfig userify-server on
    set -e
fi
[ -f /usr/sbin/update-rc.d ] && $SUDO update-rc.d userify-server defaults

cat << "EOF" > userify-start
#!/bin/bash
#
# Userify Startup
# Auto restart with 3 seconds.
#

# RECOMMENDED KERNEL SETTINGS
# for Userify:
/sbin/sysctl -w fs.file-max=1048576
ulimit -n 1048576
# recommended for local Redis:
/sbin/sysctl vm.overcommit_memory=1
echo never > /sys/kernel/mm/transparent_hugepage/enabled


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

    /opt/userify-server/userify-server server "8120" 2>&1 | tee -a /var/log/userify-server.log >(logger -t userify-server)

    sleep 3

done) &
EOF

$SUDO mv userify-start /opt/userify-server/userify-start

$SUDO chmod 755 /etc/init.d/userify-server /opt/userify-server/userify-server /opt/userify-server/userify-start

if [ -d /etc/logrotate.d ]; then
    cat <<EOF | $SUDO tee /etc/logrotate.d/userify-server >/dev/null
# Userify Server log rotation
/var/log/userify-server.log {
    daily
    rotate 7
    missingok
    create 640 userify-server root
    compress
}
EOF

else
    echo "/etc/logrotate.d not found. Please configure log rotation for /var/log/userify-server.log"
    echo "for your distribution, or email support@userify.com for assistance."
fi

[ -f /usr/sbin/update-rc.d ] && $SUDO update-rc.d userify-server defaults
set +e
# needed for docker
$SUDO $(which systemctl) && $SUDO systemctl enable redis-server
$SUDO $(which systemctl) && $SUDO systemctl enable userify-server
set -e

$SUDO /opt/userify-server/userify-start 2>&1 |$SUDO tee /var/log/userify-server.log >/dev/null &

sleep 1

cat << "EOF" | more



Welcome to Userify!       INSTALLATION COMPLETE

Next, connect to this server's IP on HTTPS (i.e., https://192.168.1.1) and
configure it.

CONFIGURE THE SERVER:

    1.  Configure where this server will store its encrypted data. You can
        choose local disk/NFS, or S3. This server should now be running Redis
        for caching and ephemeral data. You can convert this server to
        run as a Userify Enterprise cluster later if desired.

    2.  Set up the configuration user FOR THIS SERVER. This is a special user
        that\'s only used to configure the server.

    3.  Be sure to configure a mail server. This way you'll be able to send
        Invitations, password resets, event notifications, etc. We support
        Gmail, Exchange, Amazon SES, and standard SMTP servers.

    4.  Click Save to have your server restart. You can re-access that by
        clicking the Server Configuration button later.

Once your server restarts after initial configuration, create a Userify
admin user. Please note: this is a user account that is used to create your
company and can appoint other admins. It is a different user account than the
one shown above, which is only used for server configuration.

Lots more docs at https://userify.com/docs, and reach out to support@userify.com
if you have any questions.

That's it! Thanks for installing Userify!
EOF
