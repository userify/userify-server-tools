#! /bin/bash -e

# example usage:
# curl -# https://deploy.userify.com/upgrade.sh | EDITION=enterprise sudo -sE

tmpfile=$(mktemp)
if [ -z "$EDITION" ]; then
    EDITION="enterprise"
    echo "Usage:"
    echo "export EDITION=enterprise"
    echo "$0"
    echo "EDITION defaults to enterprise and can be 'enterprise' or 'pro'. If you are on pro, please press control-C now."
    echo "Otherwise, press Enter."
    read x
fi

curl -# "https://releases.userify.com/dist/userify-$EDITION-server.gz" | gunzip > "$tmpfile"

echo "One moment.. you can cancel now by pressing control-C."
# sleep for a few seconds to allow control-C
sleep 3

sudo chmod +x "$tmpfile"
sudo chown userify-server:userify-server "$tmpfile"
sudo mv -v "$tmpfile" /opt/userify-server/userify-server
sudo chown -R userify-server:userify-server /opt/userify-server/

echo 'Success! You do not need to do anything else.. Userify will automatically notice the update and restart.'
