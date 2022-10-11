#!/bin/sh

if [ -z "$DOMAIN_NAME" ];then
    echo "need env: DOMAIN_NAME"
    exit 1
fi

if [ -z "$SELECTOR_NAME" ];then
    echo "need env: SELECTOR_NAME"
    exit 1
fi

if [ -z "$DKIMDOMAIN" ];then
    DKIMDOMAIN='mail'
fi

# dkim config

DKIMKEY_PATH=/etc/dkimkeys/$SELECTOR_NAME
mkdir -p $DKIMKEY_PATH
if [ ! -f $DKIMKEY_PATH/$SELECTOR_NAME.private ];then
    opendkim-genkey --directory=$DKIMKEY_PATH --domain=$DOMAIN_NAME --selector=$SELECTOR_NAME --nosubdomains
fi

tee -a /etc/opendkim.conf <<EOF
UserID opendkim

Domain   $DOMAIN_NAME
Selector $SELECTOR_NAME
KeyFile  $DKIMKEY_PATH/$SELECTOR_NAME.private

Socket   inet:8891@localhost

# Specify the list of keys
KeyTable file:$DKIMKEY_PATH/keytable
# Match keys and domains. To use regular expressions in the file, use refile: instead of file:
SigningTable refile:$DKIMKEY_PATH/signingtable
# Match a list of hosts whose messages will be signed. By default, only localhost is considered as internal host.
InternalHosts refile:$DKIMKEY_PATH/trustedhosts
EOF

tee $DKIMKEY_PATH/keytable <<EOF
$DKIMDOMAIN._domainkey.$DOMAIN_NAME $DOMAIN_NAME:$DKIMDOMAIN:$DKIMKEY_PATH/$SELECTOR_NAME.private
EOF

tee $DKIMKEY_PATH/signingtable <<EOF
# Domain $DOMAIN_NAME
*@$DOMAIN_NAME $DKIMDOMAIN._domainkey.$DOMAIN_NAME
# You can specify multiple domains
# Example.net www._domainkey.example.net
EOF

tee $DKIMKEY_PATH/trustedhosts <<EOF
127.0.0.1
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
[::ffff:127.0.0.0]/104
[::1]/128
fc00::/7
fec0::/10
$DOMAIN_NAME
*.$DOMAIN_NAME
EOF

chown -R opendkim:opendkim $DKIMKEY_PATH

# postfix config
sed -i '/^mynetworks/d' /etc/postfix/main.cf

tee -a /etc/postfix/main.cf<<-EOF
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 fec0::/10
smtpd_milters           = inet:127.0.0.1:8891
non_smtpd_milters       = $smtpd_milters
milter_default_action   = accept
milter_protocol         = 2
EOF

# start server
rsyslogd
/etc/init.d/opendkim start

/etc/init.d/postfix start

# set color
TC="\033[0;32m"
NC="\033[0m" # No Color
SPFDOMAIN=selfspf
# set DNS
echo -n "set dkim DNS: ${TC}$DKIMDOMAIN._domainkey.$DOMAIN_NAME  TXT  $(tr '\n' ' ' <$DKIMKEY_PATH/$SELECTOR_NAME.txt | grep -o ' \".*\" ' | sed 's|\".\s.\s\"||g' | sed 's|\"||g')${NC} \n"
echo -n "set spf DNS: ${TC}$SPFDOMAIN.$DOMAIN_NAME A $(curl -L -s -4 ip.sb)${NC} \n"
SPF_IPV6=$(curl -s -L -6 ip.sb)
if [ -n "$SPF_IPV6" ];then
    echo -n "set spf DNS: ${TC}$SPFDOMAIN.$DOMAIN_NAME AAAA $(curl -L -s -6 ip.sb)${NC} \n"
fi
echo -n "set spf DNS: ${TC}$DOMAIN_NAME TXT v=spf1 include:$SPFDOMAIN.$DOMAIN_NAME ~all${NC} \n"

# test
echo -n "test dkim command: ${TC}opendkim-testkey -v -v${NC} \n"

echo -n "test email command: ${TC}sendemail -o message-charset=utf-8 -t youemail@email.com -f test@$DOMAIN_NAME -m 'from test@$DOMAIN_NAME test email.' -u 'test email:\$(date)' ${NC} \n"

# for run
tail -n 0 -f /var/log/mail.log 2>/dev/null
