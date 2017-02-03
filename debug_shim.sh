#! /bin/sh

sudo sed -i.backup-$(date -I) "s/debug=0/debug=1/" /opt/userify/userify_config.py
    
echo "Please make a change in the dashboard within the next 90 seconds."
echo "You can control-C and restart this script if needed."

for foo in $(seq 1 90)
do
    echo -n "$foo "
    sleep 1
done
echo Gathering data into debug.log.gz...

cat << "EOF" |sudo -sE |gzip > debug.log.gz 2>&1
uname -a
echo
python --version 2>&1
echo
uptime
echo
ps axfg |grep shim
echo
grep userify /etc/passwd
echo
ls -al /home/*/.ssh/
echo

for fn in /var/log/userify-shim.log /var/log/shim.log /etc/rc.local \
    $(ls -1 /home/*/.ssh/authorized_keys) \
    $(find /etc/sudoers.d/ -maxdepth 1 -type f) \
    $(find /opt/userify/ -maxdepth 1 -type f |grep -ve ".pyc$")
do
    echo
    echo
    echo "======================="
    echo $fn
    echo "======================="
    echo
    if [ -f "$fn" ]; then
        echo
        grep -hRv api_key "$fn"
        echo
    else
        echo $fn not found.
    fi
    echo
    echo
done
EOF

echo "Please use scp or sftp to retrieve debug.log.gz and attach to your bug report."

