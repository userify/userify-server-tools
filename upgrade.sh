#! /bin/bash

# example usage:
# curl https://usrfy.io/upgrade.sh  |sudo bash

echo "Usage: $0 EDITION"
echo "EDITION can be 'enterprise' or 'pro'"

tmpfile=$(mktemp)
edition="$1"
if [ -z "$edition" ]; then
    edition="enterprise"
fi
curl "https://releases.userify.com/dist/userify-$edition-server.gz" | gunzip > "$tmpfile"
sudo mv -v "$tmpfile" /opt/userify-server/userify-server
