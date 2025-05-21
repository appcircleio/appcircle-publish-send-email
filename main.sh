#!/bin/bash

set -e

echo "🔧 Email configuration:"
echo "  Host: $AC_EMAIL_HOST"
echo "  Port: $AC_EMAIL_PORT"
echo "  From: $AC_EMAIL_FROM"
echo "  To: $AC_EMAIL_TO"
echo "  Subject: $AC_EMAIL_SUBJECT"
echo "  Use TLS: $AC_EMAIL_USE_TLS"
echo "  Use SSL: $AC_EMAIL_USE_SSL"
echo "  Use Auth: $AC_EMAIL_AUTH"
echo "  Account: $AC_EMAIL_ACCOUNT"

# Load variables
HOST="$AC_EMAIL_HOST"
PORT="$AC_EMAIL_PORT"
USERNAME="$AC_EMAIL_USERNAME"
PASSWORD="$AC_EMAIL_PASSWORD"
EMAIL_FROM="$AC_EMAIL_FROM"
EMAIL_TO="$AC_EMAIL_TO"
EMAIL_SUBJECT="$AC_EMAIL_SUBJECT"
AC_EMAIL_ACCOUNT="$AC_EMAIL_ACCOUNT"
AC_EMAIL_USE_TLS="$AC_EMAIL_USE_TLS"
AC_EMAIL_USE_SSL="$AC_EMAIL_USE_SSL"
AC_EMAIL_AUTH="$AC_EMAIL_AUTH"

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

to_bool_flag() {
    local input=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    if [ "$input" == "true" ]; then
        echo "on"
    else
        echo "off"
    fi
}

TLS_FLAG=$(to_bool_flag "$AC_EMAIL_USE_TLS")
SSL_FLAG=$(to_bool_flag "$AC_EMAIL_USE_SSL")
AUTH_FLAG=$(to_bool_flag "$AC_EMAIL_AUTH")

cat <<EOF > ~/.msmtprc
defaults
auth $AUTH_FLAG
tls $TLS_FLAG
tls_starttls $TLS_FLAG
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile ~/.msmtp.log

account $AC_EMAIL_ACCOUNT
host $HOST
port $PORT
from $USERNAME
user $USERNAME
password $PASSWORD

account default: $AC_EMAIL_ACCOUNT
EOF

chmod 600 ~/.msmtprc

function cleanup {
    cat /dev/null > ~/.msmtprc
}
trap cleanup EXIT

echo -e "From: $EMAIL_FROM\nTo: $EMAIL_TO\nSubject: $EMAIL_SUBJECT\n\n$EMAIL_BODY" | msmtp --from=$USERNAME -t
