#!/bin/bash
#
# Generated iptables firewall script for the Linux 2.4 kernel
# Script generated by Easy Firewall Generator for IPTables 1.15
# copyright 2002 Timothy Scott Morizot
#
# Redhat chkconfig comments - firewall applied early,
#                             removed late
# chkconfig: 2345 08 92
# description: This script applies or removes iptables firewall rules
#
# This generator is primarily designed for RedHat installations,
# although it should be adaptable for others.
#
# It can be executed with the typical start and stop arguments.
# If used with stop, it will stop after flushing the firewall.
# The save and restore arguments will save or restore the rules
# from the /etc/sysconfig/iptables file.  The save and restore
# arguments are included to preserve compatibility with
# Redhat's or Fedora's init.d script if you prefer to use it.

# Redhat/Fedora installation instructions
#
# 1. Have the system link the iptables init.d startup script into run states
#    2, 3, and 5.
#    chkconfig --level 235 iptables on
#
# 2. Save this script and execute it to load the ruleset from this file.
#    You may need to run the dos2unix command on it to remove carraige returns.
#
# 3. To have it applied at startup, copy this script to
#    /etc/init.d/iptables.  It accepts stop, start, save, and restore
#    arguments.  (You may wish to save the existing one first.)
#    Alternatively, if you issue the 'service iptables save' command
#    the init.d script should save the rules and reload them at runtime.
#
# 4. For non-Redhat systems (or Redhat systems if you have a problem), you
#    may want to append the command to execute this script to rc.local.
#    rc.local is typically located in /etc and /etc/rc.d and is usually
#    the last thing executed on startup.  Simply add /path/to/script/script_name
#    on its own line in the rc.local file.

set -Ee
failure() {
    local lineno=$1
    local msg=$2
    echo -e "\e[91mFailed\e[0m at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR
trybash() {
    command=$(cat -)
    echo -e "\e[93mTrying to execute:\e[0m\n$command"
    echo "$command" | bash
}

###############################################################################
#
# Local Settings
#

# sysctl location.  If set, it will use sysctl to adjust the kernel parameters.
# If this is set to the empty string (or is unset), the use of sysctl
# is disabled.

SYSCTL="/sbin/sysctl -w"

# To echo the value directly to the /proc file instead
# SYSCTL=""

# IPTables Location - adjust if needed

IPT="/sbin/iptables"
IPTS="/sbin/iptables-save"
IPTR="/sbin/iptables-restore"

# Save and Restore arguments handled here
mkdir -p /etc/sysconfig
if [ "$1" = "save" ]
then
    echo -n "Saving firewall to /etc/sysconfig/iptables ... "
    $IPTS > /etc/sysconfig/iptables
    echo "done"
    exit 0
elif [ "$1" = "restore" ]
then
    echo -n "Restoring firewall from /etc/sysconfig/iptables ... "
    $IPTR < /etc/sysconfig/iptables
    echo "done"
    exit 0
fi

# Internet Interface
echo "Finding external interface ..."
if [ -z "$INET_ADDRESS" ]; then
    INET_ADDRESS=$(./get_ext_ip.sh)
fi
if [ -z "$INET_ADDRESS" ]; then exit 1; fi
INET_IFACE=$(ip -4 a | grep -B1 "$INET_ADDRESS" | awk 'NR==1{print $2}' | cut -d: -f1)
if [ -z "$INET_IFACE" ]; then exit 1; fi
echo "External interface: $INET_IFACE $INET_ADDRESS"

# Localhost Interface

LO_IP="127.0.0.1"
LO_IFACE=$(ip -4 a | grep -B1 "$LO_IP" | awk 'NR==1{print $2}' | cut -d: -f1)
if [ -z "$LO_IFACE" ]; then exit 1; fi

# there is no need to publish SSH on port 22
PORT_SSH=22
# try to parse sshd config and figure out true port on which sshd listens
path_sshd_config=/etc/ssh/sshd_config
echo "Parse '$path_sshd_config' to retrieve SSH port ..."
if [ -f "$path_sshd_config" ];
then
    sshd_listen_addr=$(cat $path_sshd_config | awk '/^\s*ListenAddress/{print $2}')
    sshd_default_port=$(cat $path_sshd_config | awk '/^\s*Port/{print $2}')
    if [ -n "$sshd_listen_addr" ];
    then
        sshd_ext_if_port=$(echo $sshd_listen_addr | grep -Po "$INET_ADDRESS:\K\d+")
        sshd_all_if_port=$(echo $sshd_listen_addr | grep -Po '0\.0\.0\.0:\K\d+')
        PORT_SSH=$sshd_ext_if_port
    else
        PORT_SSH=
    fi
    if [ -z "$PORT_SSH" ]; then PORT_SSH=$sshd_all_if_port; fi
    if [ -z "$PORT_SSH" ]; then PORT_SSH=$sshd_default_port; fi
    if [ -z "$PORT_SSH" ]; then PORT_SSH=22; fi
fi
echo "SSH port: $PORT_SSH"

# utils

printerr() { echo "$@" 1>&2; }

###############################################################################
#
# Load Modules
#

echo "Loading kernel modules ..."

# You should uncomment the line below and run it the first time just to
# ensure all kernel module dependencies are OK.  There is no need to run
# every time, however.

# /sbin/depmod -a

# Unless you have kernel module auto-loading disabled, you should not
# need to manually load each of these modules.  Other than ip_tables,
# ip_conntrack, and some of the optional modules, I've left these
# commented by default.  Uncomment if you have any problems or if
# you have disabled module autoload.  Note that some modules must
# be loaded by another kernel module.

# core netfilter module
/sbin/modprobe ip_tables

# the stateful connection tracking module
/sbin/modprobe ip_conntrack

# filter table module
# /sbin/modprobe iptable_filter

# mangle table module
# /sbin/modprobe iptable_mangle

# nat table module
# /sbin/modprobe iptable_nat

# LOG target module
# /sbin/modprobe ipt_LOG

# This is used to limit the number of packets per sec/min/hr
# /sbin/modprobe ipt_limit

# masquerade target module
# /sbin/modprobe ipt_MASQUERADE

# filter using owner as part of the match
# /sbin/modprobe ipt_owner

# REJECT target drops the packet and returns an ICMP response.
# The response is configurable.  By default, connection refused.
# /sbin/modprobe ipt_REJECT

# This target allows packets to be marked in the mangle table
# /sbin/modprobe ipt_mark

# This target affects the TCP MSS
# /sbin/modprobe ipt_tcpmss

# This match allows multiple ports instead of a single port or range
# /sbin/modprobe multiport

# This match checks against the TCP flags
# /sbin/modprobe ipt_state

# This match catches packets with invalid flags
# /sbin/modprobe ipt_unclean

# The ftp nat module is required for non-PASV ftp support
/sbin/modprobe ip_nat_ftp

# the module for full ftp connection tracking
/sbin/modprobe ip_conntrack_ftp

# the module for full irc connection tracking
/sbin/modprobe ip_conntrack_irc


###############################################################################
#
# Kernel Parameter Configuration
#
# See http://ipsysctl-tutorial.frozentux.net/chunkyhtml/index.html
# for a detailed tutorial on sysctl and the various settings
# available.

# Required to enable IPv4 forwarding.
# Redhat users can try setting FORWARD_IPV4 in /etc/sysconfig/network to true
# Alternatively, it can be set in /etc/sysctl.conf
#if [ "$SYSCTL" = "" ]
#then
#    echo "1" > /proc/sys/net/ipv4/ip_forward
#else
#    $SYSCTL net.ipv4.ip_forward="1"
#fi

# This enables dynamic address hacking.
# This may help if you have a dynamic IP address \(e.g. slip, ppp, dhcp\).
#if [ "$SYSCTL" = "" ]
#then
#    echo "1" > /proc/sys/net/ipv4/ip_dynaddr
#else
#    $SYSCTL net.ipv4.ip_dynaddr="1"
#fi

# This enables SYN flood protection.
# The SYN cookies activation allows your system to accept an unlimited
# number of TCP connections while still trying to give reasonable
# service during a denial of service attack.
if [ "$SYSCTL" = "" ]
then
    echo "1" > /proc/sys/net/ipv4/tcp_syncookies
else
    $SYSCTL net.ipv4.tcp_syncookies="1"
fi

# This enables source validation by reversed path according to RFC1812.
# In other words, did the response packet originate from the same interface
# through which the source packet was sent?  It's recommended for single-homed
# systems and routers on stub networks.  Since those are the configurations
# this firewall is designed to support, I turn it on by default.
# Turn it off if you use multiple NICs connected to the same network.
if [ "$SYSCTL" = "" ]
then
    echo "1" > /proc/sys/net/ipv4/conf/all/rp_filter
else
    $SYSCTL net.ipv4.conf.all.rp_filter="1"
fi

# This option allows a subnet to be firewalled with a single IP address.
# It's used to build a DMZ.  Since that's not a focus of this firewall
# script, it's not enabled by default, but is included for reference.
# See: http://www.sjdjweis.com/linux/proxyarp/
#if [ "$SYSCTL" = "" ]
#then
#    echo "1" > /proc/sys/net/ipv4/conf/all/proxy_arp
#else
#    $SYSCTL net.ipv4.conf.all.proxy_arp="1"
#fi

# The following kernel settings were suggested by Alex Weeks. Thanks!

# This kernel parameter instructs the kernel to ignore all ICMP
# echo requests sent to the broadcast address.  This prevents
# a number of smurfs and similar DoS nasty attacks.
if [ "$SYSCTL" = "" ]
then
    echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
else
    $SYSCTL net.ipv4.icmp_echo_ignore_broadcasts="1"
fi

# This option can be used to accept or refuse source routed
# packets.  It is usually on by default, but is generally
# considered a security risk.  This option turns it off.
if [ "$SYSCTL" = "" ]
then
    echo "0" > /proc/sys/net/ipv4/conf/all/accept_source_route
else
    $SYSCTL net.ipv4.conf.all.accept_source_route="0"
fi

# This option can disable ICMP redirects.  ICMP redirects
# are generally considered a security risk and shouldn't be
# needed by most systems using this generator.
#if [ "$SYSCTL" = "" ]
#then
#    echo "0" > /proc/sys/net/ipv4/conf/all/accept_redirects
#else
#    $SYSCTL net.ipv4.conf.all.accept_redirects="0"
#fi

# However, we'll ensure the secure_redirects option is on instead.
# This option accepts only from gateways in the default gateways list.
if [ "$SYSCTL" = "" ]
then
    echo "1" > /proc/sys/net/ipv4/conf/all/secure_redirects
else
    $SYSCTL net.ipv4.conf.all.secure_redirects="1"
fi

# This option logs packets from impossible addresses.
if [ "$SYSCTL" = "" ]
then
    echo "1" > /proc/sys/net/ipv4/conf/all/log_martians
else
    $SYSCTL net.ipv4.conf.all.log_martians="1"
fi

###############################################################################
#
# Docker
#

# Detect if Docker is installed
IS_DOCKER_INSTALLED=$(which docker)

if [ -n "$IS_DOCKER_INSTALLED" ];
then

    echo "Docker is installed on this system. The firewall would be tempered correspondingly."

    # by default, `$iface_iprange_bridge` should be '172.17.0.0/16'
    # and `$iface_name_bridge` should be 'docker0'
    # hereby we replace it with variable just in case docker or user changes it
    iface_iprange_bridge=$(docker network inspect bridge | awk '/Subnet/{print $2}' | cut -d'"' -f2)
    iface_name_bridge=$(docker network inspect bridge | awk '/com.docker.network.bridge.name/{print $2}' | cut -d'"' -f2)

    # assign a default value, in case the retrieved value of `iface_iprange_bridge` or `iface_name_bridge` is empty
    if [ -z "$iface_iprange_bridge" ];
    then
        iface_iprange_bridge=172.17.0.0/16
        ip addr show | grep $iface_iprange_bridge || exit 1
    fi
    if [ -z "$iface_name_bridge" ];
    then
        iface_name_bridge=docker0
        ip addr show | grep $iface_name_bridge || exit 1
    fi

    dir_log_docker=/tmp/docker
    mkdir -p $dir_log_docker

    list_docker_networks() {
        path_log_docker_networks=$dir_log_docker/networks.txt
        rm -f $path_log_docker_networks
        touch $path_log_docker_networks

        # list all user-defined networks for docker
        networks=$(docker network ls | awk 'NR>1{print $2}' | sed -e '/bridge/d' -e '/host/d' -e '/none/d')
        if [ -n "$networks" ];
        then
            for network in $networks;
            do
                network_id=$(docker network inspect $network | awk '/"Id"/{print $2}' | cut -d'"' -f2)
                if [ -n "$network_id" ];
                then
                    network_short_id=${network_id:0:12}
                    iface_name="br-"$network_short_id
                    iface_iprange=$(docker network inspect $network | awk '/Subnet/{print $2}' | cut -d'"' -f2)

                    echo "$iface_name $iface_iprange" >> $path_log_docker_networks
                else
                    printerr "Exception: Docker network ID too short ($network_id)!"
                fi
            done
        fi
    }

    list_docker_networks

    # Running network-active containers:
    # filter running containers with network enabled
    # remove 'running containers connected to network `none`'
    # from 'all running containers'
    # @see: https://stackoverflow.com/a/10218881/4927212
    dp_all=$(docker ps -aq -f status=running | sed "$(docker ps -aq -f status=running -f network=none | awk '{printf("-e /^%s$/d ", $1)}')")

    # get exposed ports
    for container in $dp_all;
    do
        # get list of networks this container connects
        python docker.py container networks $container | \
            awk -v container="$container" \
                '{print container ": " $0}' > $dir_log_docker/container-network.txt
        # result would look like this:
        # c52c7c5aba21 bridge docker0 172.17.0.1 172.17.0.2

        # get list of ports exposed by this container
        docker port $container | \
            awk '{print $3 " " $1}' | \
            sed '/^127\.0\.0\.1:/!d' | \
            awk '{gsub("127.0.0.1:",""); \
                gsub("[0-9]+/",""); \
                print}' | \
            awk '!a[$0]++' | \
            awk -v container="$container" \
                '{print container ": " $0}' > $dir_log_docker/container-port.txt
        # result would look like this:
        # c52c7c5aba21 80 tcp
    done
fi

###############################################################################
#
# Flush Any Existing Rules or Chains
#

echo "Flushing Tables ..."

# Reset Default Policies
$IPT -P INPUT ACCEPT
$IPT -P FORWARD ACCEPT
$IPT -P OUTPUT ACCEPT

$IPT -t nat -P PREROUTING ACCEPT
$IPT -t nat -P INPUT ACCEPT
$IPT -t nat -P OUTPUT ACCEPT
$IPT -t nat -P POSTROUTING ACCEPT

$IPT -t mangle -P PREROUTING ACCEPT
$IPT -t mangle -P INPUT ACCEPT
$IPT -t mangle -P FORWARD ACCEPT
$IPT -t mangle -P OUTPUT ACCEPT
$IPT -t mangle -P POSTROUTING ACCEPT

# Flush all rules
$IPT -F
$IPT -t nat -F
$IPT -t mangle -F

# Erase all non-default chains
$IPT -X
$IPT -t nat -X
$IPT -t mangle -X

# Zero the packet and byte counters in all chains
$IPT -Z
$IPT -t nat -Z
$IPT -t mangle -Z

if [ "$1" = "stop" ]
then
	echo "Firewall completely flushed!  Now running with no firewall."
	exit 0
fi

enabled_misc_ports=
if [ "$DEBIAN_FRONTEND" != "noninteractive" ];
then
    # detect other active ports on all interface(0.0.0.0)
    echo "Unknown active ports detected:"
    unknown_active_ports=$(netstat -tulnp | \
        awk 'NR>2{gsub("LISTEN", "");print $1 "\t" $4 "\t" $6}' | \
        sed '/0\.0\.0\.0/!d' | \
        awk '{gsub("0.0.0.0:","");gsub("[0-9]+/","",$3);print $2 "\t" $1 "\t" $3}' | \
        sed -e /^$PORT_SSH\\b/d \
            -e /^80\\b/d \
            -e /^443\\b/d)
    [ -n "$unknown_active_ports" ] && \
        echo $unknown_active_ports || \
        echo "<none>"
    read -p "Please input port number(s) to allow inbound/outbound tcp/udp packets through: " enabled_misc_ports
fi

###############################################################################
#
# Rules Configuration
#

###############################################################################
#
# Filter Table
#
###############################################################################

# Set Policies

$IPT -P INPUT DROP
$IPT -P OUTPUT DROP
$IPT -P FORWARD DROP

###############################################################################
#
# User-Specified Chains
#
# Create user chains to reduce the number of rules each packet
# must traverse.

echo "Create and populate custom rule chains ..."

# Create a chain to filter INVALID packets

$IPT -N bad_packets

# Create another chain to filter bad tcp packets

$IPT -N bad_tcp_packets

# Create separate chains for icmp, tcp (incoming and outgoing),
# and incoming udp packets.

$IPT -N icmp_packets

# Used for UDP packets inbound from the Internet
$IPT -N udp_inbound

# Used to block outbound UDP services from internal network
# Default to allow all
$IPT -N udp_outbound

# Used to allow inbound services if desired
# Default fail except for established sessions
$IPT -N tcp_inbound

# User specified TCP inbound rules
$IPT -N userspec_tcp_inbound

# Used to block outbound services from internal network
# Default to allow all
$IPT -N tcp_outbound

# User specified UDP inbound rules
$IPT -N userspec_udp_inbound

###############################################################################
#
# Populate User Chains
#

# bad_packets chain
#

# Drop INVALID packets immediately
$IPT -A bad_packets -p ALL -m state --state INVALID -j LOG \
    --log-prefix "fp=bad_packets:1 a=DROP "

$IPT -A bad_packets -p ALL -m state --state INVALID -j DROP

# Then check the tcp packets for additional problems
$IPT -A bad_packets -p tcp -j bad_tcp_packets

# All good, so return
$IPT -A bad_packets -p ALL -j RETURN

# bad_tcp_packets chain
#
# All tcp packets will traverse this chain.
# Every new connection attempt should begin with
# a syn packet.  If it doesn't, it is likely a
# port scan.  This drops packets in state
# NEW that are not flagged as syn packets.


$IPT -A bad_tcp_packets -p tcp ! --syn -m state --state NEW -j LOG \
    --log-prefix "fp=bad_tcp_packets:1 a=DROP "
$IPT -A bad_tcp_packets -p tcp ! --syn -m state --state NEW -j DROP

$IPT -A bad_tcp_packets -p tcp --tcp-flags ALL NONE -j LOG \
    --log-prefix "fp=bad_tcp_packets:2 a=DROP "
$IPT -A bad_tcp_packets -p tcp --tcp-flags ALL NONE -j DROP

$IPT -A bad_tcp_packets -p tcp --tcp-flags ALL ALL -j LOG \
    --log-prefix "fp=bad_tcp_packets:3 a=DROP "
$IPT -A bad_tcp_packets -p tcp --tcp-flags ALL ALL -j DROP

$IPT -A bad_tcp_packets -p tcp --tcp-flags ALL FIN,URG,PSH -j LOG \
    --log-prefix "fp=bad_tcp_packets:4 a=DROP "
$IPT -A bad_tcp_packets -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP

$IPT -A bad_tcp_packets -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG \
    --log-prefix "fp=bad_tcp_packets:5 a=DROP "
$IPT -A bad_tcp_packets -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

$IPT -A bad_tcp_packets -p tcp --tcp-flags SYN,RST SYN,RST -j LOG \
    --log-prefix "fp=bad_tcp_packets:6 a=DROP "
$IPT -A bad_tcp_packets -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

$IPT -A bad_tcp_packets -p tcp --tcp-flags SYN,FIN SYN,FIN -j LOG \
    --log-prefix "fp=bad_tcp_packets:7 a=DROP "
$IPT -A bad_tcp_packets -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP

# All good, so return
$IPT -A bad_tcp_packets -p tcp -j RETURN

# icmp_packets chain
#
# This chain is for inbound (from the Internet) icmp packets only.
# Type 8 (Echo Request) is not accepted by default
# Enable it if you want remote hosts to be able to reach you.
# 11 (Time Exceeded) is the only one accepted
# that would not already be covered by the established
# connection rule.  Applied to INPUT on the external interface.
#
# See: http://www.ee.siue.edu/~rwalden/networking/icmp.html
# for more info on ICMP types.
#
# Note that the stateful settings allow replies to ICMP packets.
# These rules allow new packets of the specified types.

# ICMP packets should fit in a Layer 2 frame, thus they should
# never be fragmented.  Fragmented ICMP packets are a typical sign
# of a denial of service attack.
$IPT -A icmp_packets --fragment -p ICMP -j LOG \
    --log-prefix "fp=icmp_packets:1 a=DROP "
$IPT -A icmp_packets --fragment -p ICMP -j DROP

# Echo - uncomment to allow your system to be pinged.
# Uncomment the LOG command if you also want to log PING attempts
#
# $IPT -A icmp_packets -p ICMP -s 0/0 --icmp-type 8 -j LOG \
#    --log-prefix "fp=icmp_packets:2 a=ACCEPT "
# $IPT -A icmp_packets -p ICMP -s 0/0 --icmp-type 8 -j ACCEPT

# By default, however, drop pings without logging. Blaster
# and other worms have infected systems blasting pings.
# Comment the line below if you want pings logged, but it
# will likely fill your logs.
$IPT -A icmp_packets -p ICMP -s 0/0 --icmp-type 8 -j DROP

# Time Exceeded
$IPT -A icmp_packets -p ICMP -s 0/0 --icmp-type 11 -j ACCEPT

# Not matched, so return so it will be logged
$IPT -A icmp_packets -p ICMP -j RETURN

# TCP & UDP
# Identify ports at:
#    http://www.chebucto.ns.ca/~rakerman/port-table.html
#    http://www.iana.org/assignments/port-numbers

# udp_inbound chain
#
# This chain describes the inbound UDP packets it will accept.
# It's applied to INPUT on the external or Internet interface.
# Note that the stateful settings allow replies.
# These rules are for new requests.
# It drops netbios packets (windows) immediately without logging.

# Drop netbios calls
# Please note that these rules do not really change the way the firewall
# treats netbios connections.  Connections from the localhost and
# internal interface (if one exists) are accepted by default.
# Responses from the Internet to requests initiated by or through
# the firewall are also accepted by default.  To get here, the
# packets would have to be part of a new request received by the
# Internet interface.  You would have to manually add rules to
# accept these.  I added these rules because some network connections,
# such as those via cable modems, tend to be filled with noise from
# unprotected Windows machines.  These rules drop those packets
# quickly and without logging them.  This prevents them from traversing
# the whole chain and keeps the log from getting cluttered with
# chatter from Windows systems.
$IPT -A udp_inbound -p UDP -s 0/0 --dport 137 -j DROP
$IPT -A udp_inbound -p UDP -s 0/0 --dport 138 -j DROP

# DNS Server
# Configure the server to use port 53 as the source port for requests
# Note, if you run a caching-only name server that only accepts queries
# from the private network or localhost, you can comment out this line.
$IPT -A udp_inbound -p UDP -s 0/0 --dport 53 -j ACCEPT

# If you don't query-source the server to port 53 and you have problems,
# uncomment this rule.  It specifically allows responses to queries
# initiated to another server from a high UDP port.  The stateful
# connection rules should handle this situation, though.
# $IPT -A udp_inbound -p UDP -s 0/0 --source-port 53 -j ACCEPT

# User specified allowed UDP protocol
$IPT -A udp_inbound -p UDP -s 0/0 -j userspec_udp_inbound

# Not matched, so return for logging
$IPT -A udp_inbound -p UDP -j RETURN

# udp_outbound chain
#
# This chain is used with a private network to prevent forwarding for
# UDP requests on specific protocols.  Applied to the FORWARD rule from
# the internal network.  Ends with an ACCEPT


# No match, so ACCEPT
$IPT -A udp_outbound -p UDP -s 0/0 -j ACCEPT

# tcp_inbound chain
#
# This chain is used to allow inbound connections to the
# system/gateway.  Use with care.  It defaults to none.
# It's applied on INPUT from the external or Internet interface.

# DNS Server - Allow TCP connections (zone transfers and large requests)
# This is disabled by default.  DNS Zone transfers occur via TCP.
# If you need to allow transfers over the net you need to uncomment this line.
# If you allow queries from the 'net, you also need to be aware that although
# DNS queries use UDP by default, a truncated UDP query can legally be
# submitted via TCP instead.  You probably will never need it, but should
# be aware of the fact.
# $IPT -A tcp_inbound -p TCP -s 0/0 --dport 53 -j ACCEPT

# Web Server

# HTTP
$IPT -A tcp_inbound -p TCP -s 0/0 --dport 80 -j ACCEPT

# HTTPS (Secure Web Server)
$IPT -A tcp_inbound -p TCP -s 0/0 --dport 443 -j ACCEPT

# sshd
$IPT -A tcp_inbound -p TCP -s 0/0 --dport $PORT_SSH -j LOG \
    --log-prefix "fp=ssh:1 a=ACCEPT "
$IPT -A tcp_inbound -p TCP -s 0/0 --dport $PORT_SSH -j ACCEPT

# User specified allowed TCP protocol
$IPT -A tcp_inbound -p TCP -s 0/0 -j userspec_tcp_inbound

# Not matched, so return so it will be logged
$IPT -A tcp_inbound -p TCP -j RETURN

# tcp_outbound chain
#
# This chain is used with a private network to prevent forwarding for
# requests on specific protocols.  Applied to the FORWARD rule from
# the internal network.  Ends with an ACCEPT


# No match, so ACCEPT
$IPT -A tcp_outbound -p TCP -s 0/0 -j ACCEPT


# User specified allowed TCP/UDP protocol
for port in $enabled_misc_ports;
do
    if echo "$port" | grep -P '^\d+(/((tcp)|(udp)))?$' > /dev/null;
    then
        # valid port spec string
        protocol=$(echo $port | cut -d'/' -f2)
        port=$(echo $port | cut -d'/' -f1)
        if [ "$protocol" == "tcp" ]; then
            $IPT -A userspec_tcp_inbound -p TCP -s 0/0 --dport $port -j ACCEPT
        elif [ "$protocol" == "udp" ]; then
            $IPT -A userspec_udp_inbound -p TCP -s 0/0 --dport $port -j ACCEPT
        else
            $IPT -A userspec_udp_inbound -p TCP -s 0/0 --dport $port -j ACCEPT
            $IPT -A userspec_tcp_inbound -p TCP -s 0/0 --dport $port -j ACCEPT
        fi
    else
        # invalid port spec string
        printerr "Invalid port spec string ($port)!"
    fi
done

$IPT -A userspec_udp_inbound -j RETURN
$IPT -A userspec_tcp_inbound -j RETURN

###############################################################################
#
# INPUT Chain
#

echo "Process INPUT chain ..."

# Allow all on localhost interface
$IPT -A INPUT -p ALL -i $LO_IFACE -j ACCEPT

# Drop bad packets
$IPT -A INPUT -p ALL -j bad_packets

# DOCSIS compliant cable modems
# Some DOCSIS compliant cable modems send IGMP multicasts to find
# connected PCs.  The multicast packets have the destination address
# 224.0.0.1.  You can accept them.  If you choose to do so,
# Uncomment the rule to ACCEPT them and comment the rule to DROP
# them  The firewall will drop them here by default to avoid
# cluttering the log.  The firewall will drop all multicasts
# to the entire subnet (224.0.0.1) by default.  To only affect
# IGMP multicasts, change '-p ALL' to '-p 2'.  Of course,
# if they aren't accepted elsewhere, it will only ensure that
# multicasts on other protocols are logged.
# Drop them without logging.
$IPT -A INPUT -p ALL -d 224.0.0.1 -j DROP
# The rule to accept the packets.
# $IPT -A INPUT -p ALL -d 224.0.0.1 -j ACCEPT


# Inbound Internet Packet Rules

# Accept Established Connections
$IPT -A INPUT -p ALL -i $INET_IFACE -m state --state ESTABLISHED,RELATED \
     -j ACCEPT

# Route the rest to the appropriate user chain
$IPT -A INPUT -p TCP -i $INET_IFACE -j tcp_inbound
$IPT -A INPUT -p UDP -i $INET_IFACE -j udp_inbound
$IPT -A INPUT -p ICMP -i $INET_IFACE -j icmp_packets

# Drop without logging broadcasts that get this far.
# Cuts down on log clutter.
# Comment this line if testing new rules that impact
# broadcast protocols.
$IPT -A INPUT -m pkttype --pkt-type broadcast -j DROP

# Log packets that still don't match
$IPT -A INPUT -j LOG --log-prefix "fp=INPUT:99 a=DROP "


# Docker
#if [ -n "$IS_DOCKER_INSTALLED" ];
#then
#    # block inbound packets destined to ports of containers that is not exposed
#
#    $IPT -N docker_container_input
#
#    # redirect all packets from default bridge
#    # and user-specified network gateway
#    # to chain `docker_container_input`
#    $IPT -A INPUT -i $iface_name_bridge -j docker_container_input
#    cat $path_log_docker_networks | awk -v run_ipt="$IPT" '{print \
#        run_ipt " -A INPUT -i "$1" -j docker_container_input"}' | trybash
#
#    # running containers not connected to network `none`
#    dp_none=$(docker ps -aq -f status=running -f network=none)
#    # all running containers
#    dp_all=$(docker ps -aq -f status=running)
#    # filter running containers with network enabled
#    for container in $dp_none;
#    do
#        dp_all=$(printf "%s\n" $dp_all | sed "/^$container$/d")
#    done
#
#    # get exposed ports
#    for container in $dp_all;
#    do
#        # get list of ports exposed by this container
#        docker port $container | \
#            awk '{print $3 " " $1}' | \
#            sed '/^127\.0\.0\.1:/!d' | \
#            awk -v run_ipt="$IPT" '{ \
#                gsub("127.0.0.1:",""); \
#                gsub("[0-9]+/",""); \
#                print run_ipt " -A docker_container_input -p "$2" --dport "$1" -j ACCEPT"}' | \
#            awk '!a[$0]++' | \
#            bash
#    done
#
#    # drop all non-matching packets
#    $IPT -A docker_container_input -j DROP
#fi

###############################################################################
#
# FORWARD Chain
#

echo "Process FORWARD chain ..."

# Used if forwarding for a private network

# Docker
if [ -n "$IS_DOCKER_INSTALLED" ];
then
    $IPT -N DOCKER
    $IPT -N DOCKER-ISOLATION-STAGE-1
    $IPT -N DOCKER-ISOLATION-STAGE-2
    $IPT -N DOCKER-USER

    $IPT -A FORWARD -j DOCKER-USER
    $IPT -A FORWARD -j DOCKER-ISOLATION-STAGE-1

    #$IPT -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    $IPT -A FORWARD -o $iface_name_bridge -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    #$IPT -A FORWARD -o docker0 -j DOCKER
    $IPT -A FORWARD -o $iface_name_bridge -j DOCKER
    #$IPT -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
    $IPT -A FORWARD -i $iface_name_bridge ! -o $iface_name_bridge -j ACCEPT
    #$IPT -A FORWARD -i docker0 -o docker0 -j ACCEPT
    $IPT -A FORWARD -i $iface_name_bridge -o $iface_name_bridge -j ACCEPT

    cat $path_log_docker_networks | awk -v run_ipt="$IPT" '{print \
        run_ipt " -A FORWARD -o "$1" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT" "\n" \
        run_ipt " -A FORWARD -o "$1" -j DOCKER" "\n" \
        run_ipt " -A FORWARD -i "$1" ! -o "$1" -j ACCEPT" "\n" \
        run_ipt " -A FORWARD -i "$1" -o "$1" -j ACCEPT"}' | trybash

    # allow packets according to the ports exposed by each container
    # TODO
    #$IPT -A DOCKER -d 172.17.0.2/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport 80 -j ACCEPT
    for container in $dp_all;
    do
        # i'm done with considering one-container-multiple-networks architecture
        # now i'll only take one line from each file as follows
        seg1=$(cat $dir_log_docker/container-network.txt | \
            grep "^$container:" | \
            awk 'NR==1' | \
            awk '{print " -A DOCKER -d "$5"/32 ! -i "$3" -o "$3}')
        seg2=$(cat $dir_log_docker/container-port.txt | \
            grep "^$container:" | \
            awk 'NR==1' | \
            awk '{print " -p "$3" -m "$3" --dport "$2" -j ACCEPT"}')
        echo "$IPT$seg1$seg2" | trybash
    done

    # packets destined to docker gateways,
    # but not originated from them,
    # goes to chain DOCKER-ISOLATION-STAGE-2
    #$IPT -A DOCKER-ISOLATION-STAGE-1 -i docker0 ! -o docker0 -j DOCKER-ISOLATION-STAGE-2
    $IPT -A DOCKER-ISOLATION-STAGE-1 -i $iface_name_bridge ! -o $iface_name_bridge -j DOCKER-ISOLATION-STAGE-2
    cat $path_log_docker_networks | awk -v run_ipt="$IPT" '{print \
        run_ipt " -A DOCKER-ISOLATION-STAGE-1 -i "$1" ! -o "$1" -j DOCKER-ISOLATION-STAGE-2"}' | trybash

    $IPT -A DOCKER-ISOLATION-STAGE-1 -j RETURN

    # packets originated from docker gateways will be dropped
    #$IPT -A DOCKER-ISOLATION-STAGE-2 -o docker0 -j DROP
    $IPT -A DOCKER-ISOLATION-STAGE-2 -o $iface_name_bridge -j DROP
    cat $path_log_docker_networks | awk -v run_ipt="$IPT" '{print \
        run_ipt " -A DOCKER-ISOLATION-STAGE-2 -o "$1" -j DROP"}' | trybash

    $IPT -A DOCKER-ISOLATION-STAGE-2 -j RETURN

    $IPT -A DOCKER-USER -j RETURN
fi


###############################################################################
#
# OUTPUT Chain
#

echo "Process OUTPUT chain ..."

# Generally trust the firewall on output

# However, invalid icmp packets need to be dropped
# to prevent a possible exploit.
$IPT -A OUTPUT -m state -p icmp --state INVALID -j DROP

# Localhost
$IPT -A OUTPUT -p ALL -s $LO_IP -j ACCEPT
$IPT -A OUTPUT -p ALL -o $LO_IFACE -j ACCEPT

# To internet
$IPT -A OUTPUT -p ALL -o $INET_IFACE -j ACCEPT

# Log packets that still don't match
$IPT -A OUTPUT -j LOG --log-prefix "fp=OUTPUT:99 a=DROP "

###############################################################################
#
# nat table
#
###############################################################################

# The nat table is where network address translation occurs if there
# is a private network.  If the gateway is connected to the Internet
# with a static IP, snat is used.  If the gateway has a dynamic address,
# masquerade must be used instead.  There is more overhead associated
# with masquerade, so snat is better when it can be used.
# The nat table has a builtin chain, PREROUTING, for dnat and redirects.
# Another, POSTROUTING, handles snat and masquerade.

echo "Load rules for nat table ..."


if [ -n "$IS_DOCKER_INSTALLED" ];
then
    $IPT -t nat -N DOCKER

    # PREROUTING chain

    # all incoming packets destined to local address(es) will be directed to chain DOCKER
    # `LOCAL` refers to any address assigned to an interface
    # try `ip addr show | awk '/inet/{print $2}' | cut -d'/' -f1`

    $IPT -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j LOG \
        --log-prefix "fp=NAT:DOCKER:1 a=DOCKER "
    $IPT -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER

    # OUTPUT chain

    # all locally-generated packets destined to local address(es) will be directed to chain DOCKER
    $IPT -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j LOG \
        --log-prefix "fp=NAT:DOCKER:2 a=DOCKER "
    $IPT -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER

    # POSTROUTING chain

    # all packets from internal address(es) behind gateway `docker0` presumably will be masqueraded
    #$IPT -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
    $IPT -t nat -A POSTROUTING -s $iface_iprange_bridge ! -o $iface_name_bridge -j LOG \
        --log-prefix "fp=NAT:DOCKER:3 a=MASQUERADE "
    $IPT -t nat -A POSTROUTING -s $iface_iprange_bridge ! -o $iface_name_bridge -j MASQUERADE

    # Docker networks

    # all packets from internal address(es) behind gateway of user-defined network will be masqueraded
    cat $path_log_docker_networks | \
        awk -v run_ipt="$IPT" '{print \
            run_ipt " -t nat -A POSTROUTING -s "$2" ! -o "$1" -j LOG \
                --log-prefix \"fp=NAT:DOCKER:4 a=MASQUERADE \"" "\n" \
            run_ipt " -t nat -A POSTROUTING -s "$2" ! -o "$1" -j MASQUERADE"}' | trybash

    # TODO
    #$IPT -t nat -A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p tcp -m tcp --dport 80 -j MASQUERADE
    for container in $dp_all;
    do
        # i'm done with considering one-container-multiple-networks architecture
        # now i'll only take one line from each file as follows
        seg1=$(cat $dir_log_docker/container-network.txt | \
            grep "^$container:" | \
            awk 'NR==1' | \
            awk '{print " -t nat -A POSTROUTING -s "$5"/32 -d "$5"/32"}')
        seg2=$(cat $dir_log_docker/container-port.txt | \
            grep "^$container:" | \
            awk 'NR==1' | \
            awk '{print " -p "$3" -m "$3" --dport "$2" -j MASQUERADE"}')
        echo $IPT$seg1$seg2 | trybash
    done

    # all packets coming in through interface `docker0` presumably will be accepted
    #$IPT -t nat -A DOCKER -i docker0 -j RETURN
    $IPT -t nat -A DOCKER -i $iface_name_bridge -j RETURN

    # all packets coming in through interface of user-defined network will be accepted
    cat $path_log_docker_networks | \
        awk -v run_ipt="$IPT" '{print \
            run_ipt " -t nat -A DOCKER -i "$1" -j RETURN"}' | trybash

    # TODO
    #$IPT -t nat -A DOCKER -d 127.0.0.1/32 ! -i docker0 -p tcp -m tcp --dport 80 -j DNAT --to-destination 172.17.0.2:80
    for container in $dp_all;
    do
        # i'm done with considering one-container-multiple-networks architecture
        # now i'll only take one line from each file as follows
        seg1=$(cat $dir_log_docker/container-network.txt | \
            grep "^$container:" | \
            awk 'NR==1' | \
            awk '{print "-t nat -A DOCKER -d 127.0.0.1/32 ! -i "$3" | -j DNAT --to-destination "$5":"}')
        seg2=$(cat $dir_log_docker/container-port.txt | \
            grep "^$container:" | \
            awk 'NR==1' | \
            awk '{print "-p "$3" -m "$3" --dport "$2"|"$2}')
        echo "$IPT $(echo $seg1 | cut -d'|' -f1)$(echo $seg2 | cut -d'|' -f1)$(echo $seg1 | cut -d'|' -f2)$(echo $seg2 | cut -d'|' -f2)" | trybash
    done
fi

###############################################################################
#
# PREROUTING chain
#


###############################################################################
#
# INPUT chain
#


###############################################################################
#
# OUTPUT chain
#


###############################################################################
#
# POSTROUTING chain
#


###############################################################################
#
# mangle table
#
###############################################################################

# The mangle table is used to alter packets.  It can alter or mangle them in
# several ways.  For the purposes of this generator, we only use its ability
# to alter the TTL in packets.  However, it can be used to set netfilter
# mark values on specific packets.  Those marks could then be used in another
# table like filter, to limit activities associated with a specific host, for
# instance.  The TOS target can be used to set the Type of Service field in
# the IP header.  Note that the TTL target might not be included in the
# distribution on your system.  If it is not and you require it, you will
# have to add it.  That may require that you build from source.

echo "Load rules for mangle table ..."
