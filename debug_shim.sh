#! /bin/sh

cat << "EOF" |sudo -sE |gzip > debug.log.gz 2>&1
uname -a
echo
python --version
ls -al /etc/sudoers.d/
grep userify /etc/passwd
ls -al /home/*/.ssh/
    
for fn in /var/log/userify-shim.log /var/log/shim.log /opt/userify/creds.py /opt/userify/userify_config.py /opt/userify/shim.sh /etc/rc.local \
    $(ls -1 /home/*/.ssh/authorized_keys) $(ls -1 /etc/sudoers.d/)
do
    if [ -f "$fn" ]; then
        echo
        echo
        echo "======================="
        echo $fn
        echo "======================="
        echo
        tail -n 250 $fn | grep -hRv api_key
        echo
        echo
    else
        echo $fn not found.
    fi
done
EOF

echo "Please use scp or sftp to retrieve debug.log.gz and attach to your bug report."

