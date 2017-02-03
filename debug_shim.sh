#! /bin/sh

cat << "EOF" |sudo -sE |gzip > debug.log.gz 2>&1
uname -a
echo
python --version
ls -al /etc/sudoers.d/
grep userify /etc/passwd
ls -al /home/*/.ssh/

sed -i.backup-$(date -I) "s/debug=0/debug=1/" /opt/userify/userify_config.py
    
for fn in /var/log/userify-shim.log /var/log/shim.log /etc/rc.local \
    $(ls -1 /home/*/.ssh/authorized_keys) $(ls -1 /etc/sudoers.d/) $(ls -1 /opt/userify/)
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

