#!/bin/bash

set -e

HOST="$AC_EMAIL_HOST"
PORT="$AC_EMAIL_PORT"
USERNAME="$AC_EMAIL_USERNAME"
PASSWORD="$AC_EMAIL_PASSWORD"
EMAIL_FROM="$AC_EMAIL_FROM"
EMAIL_TO="$AC_EMAIL_TO"
EMAIL_SUBJECT="$AC_EMAIL_SUBJECT"

# Check for required tools
if ! command -v envsubst >/dev/null; then
    echo "envsubst is required but not installed."
    exit 1
fi

EMAIL_BODY="$(echo "$AC_EMAIL_BODY" | sed 's/\\\$/ESCAPED_DOLLAR/g' | envsubst | sed 's/ESCAPED_DOLLAR/\$/g')"

# Detect OS
os=""
if uname -a | grep -iq "darwin"; then
    os="darwin"
elif uname -a | grep -iq "linux"; then
    os="linux"
else
    echo "Unsupported OS"
    exit 1
fi

if ! command -v msmtp >/dev/null; then
    if [ "$os" == "darwin" ]; then
        if ! command -v brew >/dev/null; then
            echo "Homebrew is not installed. Install Homebrew first."
            exit 1
        fi
        brew install msmtp
    elif [ "$os" == "linux" ]; then
        if ! command -v apt >/dev/null; then
            echo "apt is not available. Install msmtp manually."
            exit 1
        fi
        apt-get update
        apt-get install -y msmtp msmtp-mta mailutils gettext
    fi
fi

cat <<EOF > ~/.msmtprc
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile ~/.msmtp.log

account default
host $HOST
port $PORT
from $USERNAME
user $USERNAME
password $PASSWORD

account default: default
EOF

chmod 600 ~/.msmtprc

function cleanup {
    cat /dev/null > ~/.msmtprc
}
trap cleanup EXIT

echo -e "From: $EMAIL_FROM\nTo: $EMAIL_TO\nSubject: $EMAIL_SUBJECT\n\n$EMAIL_BODY" | msmtp --from=$USERNAME -t
