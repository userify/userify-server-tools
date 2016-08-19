#! /bin/sh

cat << "EOF" |sudo -sE > debug.log 2>&1
uname -a
echo
python --version
echo
echo "======================="
echo /var/log/userify-shim.log 
cat /var/log/userify-shim.log 
echo
echo

for fn in creds.py userify_config.py shim.sh
do
    echo
    echo
    echo "======================="
    echo /opt/userify/$fn
    echo "======================="
    echo
    grep -hRv api_key /opt/userify/$fn
    echo
    echo
done
EOF

echo "Please download debug.log and attach to your bug report."

