#!/bin/bash

export PATH_CERTBOT_INI=/opt/certbot/rfc2136.ini

if [ "$DEBIAN_FRONTEND" != "noninteractive" ] && [ -z "$admin_name" ];
then
    read -p "Please input admin name (default: admin): " admin_name
else
    echo "Using default admin name: 'admin'!"
fi
if [ -z "$admin_name" ];
then
    admin_name=admin
fi

if [ "$DEBIAN_FRONTEND" != "noninteractive" ] && [ -z "$domain_name" ];
then
    read -p "Please input domain name: " domain_name
fi
if [ -n "$domain_name" ];
then
    echo "$domain_name" > /opt/domain
else
    echo "No '\$domain_name' is specified!"
    exit 1
fi

get_host_ip() {
    adapters=$(ip -4 a | awk '/inet/{print $2}' | cut -d'/' -f1)
    for adapter in $adapters;
    do
        if [ "$adapter" == 127.0.0.1 ] || [ "$adapter" == 224.0.0.1 ];
        then
            continue
        fi
        part1=$(echo $adapter | cut -d'.' -f1)
        part2=$(echo $adapter | cut -d'.' -f2)
        case "$part1" in
            10)
            continue
            ;;

            172)
            case "$part2" in
                16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)
                continue
                ;;

                *)
                echo "$adapter"
                return 0
                ;;
            esac
            ;;

            192)
            case "$part2" in
                168)
                continue
                ;;

                *)
                echo "$adapter"
                return 0
                ;;
            esac
            ;;

            *)
            echo "$adapter"
            return 0
            ;;
        esac
    done
    return 1
}

if [ "$DEBIAN_FRONTEND" != "noninteractive" ] && [ -z "$host_ip" ];
then
    read -p "Do you want to use the external IP of the current machine in your zone file? (Y/n) " use_host_ip
    if [ "$use_host_ip" == "Y" ] || [ "$use_host_ip" == "y" ];
    then
        host_ip=$(get_host_ip)
    else
        read -p "Please input IP: " host_ip
    fi
fi
if [ -z "$host_ip" ]; then
    host_ip=$(get_host_ip)
fi
echo "Using IP [$host_ip] ..."
# transform ip such as '1.2.3.4' into '4.3.2.1.'
# @see: https://stackoverflow.com/a/5257398/4927212
# @see: https://unix.stackexchange.com/a/412874/244069
host_ip_rev=$(printf "%s\n" ${host_ip//./ } | tac | tr '\n' '.')
# append 'in-addr.arpa.'
host_ip_rev=$host_ip_rev"in-addr.arpa."

file_name=db.$domain_name
today=$(date +%Y%m%d)

zone_ttl=86400
serial_number=$today"01"
refresh_interval=3h
retry_interval=30m
expiry_period=3w
negative_ttl=1h

file_path=/etc/bind/zones/$file_name
cat > $file_path << EOF
\$ORIGIN $domain_name.
\$TTL $zone_ttl

; Symbol '@' is a placeholder for '\$ORIGIN'
@ IN SOA ns1.$domain_name. $admin_name.$domain_name. (
  ; Serial number,
  ; change this value each time you modify this file
  $serial_number

  ; Refresh interval,
  ; this is the amount of time that
  ; the slave will wait before
  ; polling the master
  ; for zone file changes
  $refresh_interval

  ; Retry interval,
  ; if the slave cannot connect to
  ; the master when the refresh period is up,
  ; it will wait this amount of time and
  ; retry to poll the master
  $retry_interval

  ; Expiry period,
  ; if a slave name server has not been able to
  ; contact the master for this amount of time,
  ; it no longer returns responses as
  ; an authoritative source for this zone
  $expiry_period

  ; Negative TTL,
  ; this is the amount of time that
  ; the name server will cache a name error
  ; if it cannot find the requested name in this file
  $negative_ttl )

; Nameservers
        IN      NS      ns1.$domain_name.
        IN      NS      ns2.$domain_name.

; Root site
        IN      A       $host_ip

; Hostname records
ns1     IN      A       $host_ip
ns2     IN      A       $host_ip
@       IN      A       $host_ip

; Aliases
www     IN      CNAME   $domain_name.

; PTR records
$host_ip_rev IN PTR     $domain_name.

; MX records
@       IN      MX      1       aspmx.l.google.com.
@       IN      MX      3       alt1.aspmx.l.google.com.
@       IN      MX      3       alt2.aspmx.l.google.com.
@       IN      MX      5       aspmx2.googlemail.com.
@       IN      MX      5       aspmx3.googlemail.com.
@       IN      MX      5       aspmx4.googlemail.com.
@       IN      MX      5       aspmx5.googlemail.com.
EOF

# @see: https://unix.stackexchange.com/q/523565/244069
# @see: https://certbot-dns-rfc2136.readthedocs.io/en/stable/
# @see: https://ftp.isc.org/isc/bind9/9.14.2/doc/arm/Bv9ARM.ch05.html#zone_statement_grammar
algorithm=hmac-sha512
keyname=tsig-key
tsig_key_path=/etc/bind/tsig.key
# You should protect this TSIG key material
# as it can be used to potentially add, update,
# or delete any record in the target DNS server.
# Users who can read this file can use these credentials
# to issue arbitrary API calls on your behalf.
# Users who can cause Certbot to run using these credentials
# can complete a `dns-01` challenge to acquire
# new certificates or revoke existing certificates
# for associated domains, even if
# those domains aren’t being managed by this server.
tsig-keygen -a $algorithm $keyname > $tsig_key_path
# Certbot will emit a warning if it detects
# that the credentials file can be accessed
# by other users on your system.
# The warning reads “Unsafe permissions
# on credentials configuration file”,
# followed by the path to the credentials file.
# This warning will be emitted each time
# Certbot uses the credentials file,
# including for renewal, and cannot be silenced
# except by addressing the issue
# (e.g., by using a command like chmod 600 to restrict access to the file).
chown root:root $tsig_key_path
chmod 400 $tsig_key_path
secret=$(cat $tsig_key_path | awk '/secret/' | cut -d'"' -f2)
url_challenge=https://acme-v02.api.letsencrypt.org/directory

cat >> /etc/bind/named.conf.local << EOF
include "$tsig_key_path";

zone "$domain_name" {
    type master;
    file "$file_path";

    // limits the scope of the TSIG key to just be able to
    // add and remove TXT records for one specific host
    // for the purpose of completing the dns-01 challenge
    update-policy {
        grant $keyname name $url_challenge txt;
    };
};
EOF

cat > $PATH_CERTBOT_INI << EOF
# Target DNS server
dns_rfc2136_server = 127.0.0.1
# Target DNS port
dns_rfc2136_port = 53
# Authorative domain (optional, will try to auto-detect if missing)
dns_rfc2136_base_domain = $domain_name
# TSIG key name
dns_rfc2136_name = $keyname
# TSIG key secret
dns_rfc2136_secret = $secret
# TSIG key algorithm
dns_rfc2136_algorithm = $algorithm
EOF
