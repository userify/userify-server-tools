#! /bin/sh

sudo sed -i.backup-$(date -I) "s/debug=0/debug=1/" /opt/userify/userify_config.py
    
echo "Please change the permissions for this server or your SSH key (just add '#test1') in the dashboard within the next 30 seconds to trigger a change here."
echo "You can press control-C and restart this script if needed."

for foo in $(seq 1 30)
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

echo "Shim Execution: debug"

static_host="static.userify.com"
touch /opt/userify/userify_config.py
source /opt/userify/userify_config.py
[ "x$self_signed" == "x1" ] && SELFSIGNED='k' || SELFSIGNED=''

# kick off shim.py
[ -z "$PYTHON" ] && PYTHON="$(which python)"
echo "SELF_SIGNED: $SELF_SIGNED"
echo "PYTHON: $PYTHON"
curl -1 -f${SELFSIGNED}Ss https://$static_host/shim.py | $PYTHON -u

EOF

echo "Please use scp or sftp to retrieve debug.log.gz and attach to your bug report, or type 'zcat debug.log.gz' to copy/paste."

