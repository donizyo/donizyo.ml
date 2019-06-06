#!/bin/bash

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

domain_name=
read -p "Please input domain name: " domain_name

host_ip=
read -p "Do you want to use the external IP of the current machine in your zone file? (Y/n) " use_host_ip
if [ "$use_host_ip" == "Y" ] || [ "$use_host_ip" == "y" ]; then
    host_ip=$(get_host_ip)
else
    read -p "Please input IP: " host_ip
fi
echo "Using IP [$host_ip] ..."

file_name=db.$domain_name
today=$(date +%Y%m%d)

zone_ttl=86400
serial_number=$today"01"
refresh_interval=3h
retry_interval=30m
expiry_period=3w
negative_ttl=1h

cat > /etc/bind/zones/$file_name << EOF
\$ORIGIN $domain_name.
\$TTL $zone_ttl

; Symbol '@' is a placeholder for '\$ORIGIN'
@ IN SOA ns1.$domain_name. donizyo.$domain_name. (
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

; MX records
@       IN      MX      1       aspmx.l.google.com.
@       IN      MX      3       alt1.aspmx.l.google.com.
@       IN      MX      3       alt2.aspmx.l.google.com.
@       IN      MX      5       aspmx2.googlemail.com.
@       IN      MX      5       aspmx3.googlemail.com.
@       IN      MX      5       aspmx4.googlemail.com.
@       IN      MX      5       aspmx5.googlemail.com.
EOF
