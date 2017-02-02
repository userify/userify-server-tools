#! /bin/sh

cat << "EOF" |sudo -sE > debug.log.gz 2>&1
uname -a
echo
python --version

ls -al /etc/sudoers.d/
grep userify /etc/passwd
ls -al /home/*/.ssh/
cat /home/*/.ssh/authorized_keys
    
for fn in /var/log/userify-shim.log /var/log/shim.log /opt/userify/creds.py /opt/userify/userify_config.py /opt/userify/shim.sh /etc/rc.local
do
    if [ -f "$fn" ]; then
        echo
        echo
        echo "======================="
        echo $fn
        echo "======================="
        echo
        grep -hRv api_key $fn
        echo
        echo
    else
        echo $fn not found.
    fi
done
EOF

echo "Please use scp or sftp to retrieve debug.log.gz and attach to your bug report."

