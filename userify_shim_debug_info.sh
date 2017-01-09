#! /bin/sh

cat << "EOF" |sudo -sE > debug.log 2>&1
uname -a
echo
python --version
    
for fn in /var/log/userify-shim.log /var/log/shim.log /opt/userify/creds.py /opt/userify/userify_config.py /opt/userify/shim.sh /etc/rc.local
do
    echo
    echo
    echo "======================="
    echo $fn
    echo "======================="
    echo
    grep -hRv api_key $fn
    echo
    echo
done
EOF

echo "Please download debug.log and attach to your bug report."

