#! /bin/bash

# example usage:
# sudo curl https://raw.githubusercontent.com/userify/userify-server-tools/master/upgrade.sh | sudo bash

echo "Usage: $0 EDITION"
echo "EDITION can be 'enterprise' or 'pro'"

tmpfile=$(mktemp)
edition="$1"
if [ -z "$edition" ]; then
    edition="enterprise"
fi
curl "https://releases.userify.com/dist/userify-$edition-server.gz" | gunzip > "$tmpfile"
sudo mv -v "$tmpfile" /opt/userify-server/userify-server
