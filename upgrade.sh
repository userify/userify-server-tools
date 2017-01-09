#! /bin/bash -e

# example usage:
# curl -# https://usrfy.io/upgrade.sh enterprise |sudo bash

tmpfile=$(mktemp)
edition="$1"
if [ -z "$edition" ]; then
    edition="enterprise"
    echo "Usage: $0 EDITION"
    echo "EDITION defaults to enterprise and can be 'enterprise' or 'pro'. If you are on pro, please press control-C now."
fi

curl -# "https://releases.userify.com/dist/userify-$edition-server.gz" | gunzip > "$tmpfile"

echo "One moment.. you can cancel now by pressing control-C."
# sleep for a few seconds to allow control-C
sleep 3

sudo mv -v "$tmpfile" /opt/userify-server/userify-server

echo 'Success! You do not need to do anything else.. Userify will automatically notice the update and restart.'
