#!/bin/sh
#===============================================================================
#            FILE: openvpn.sh
#
#           USAGE: ./openvpn.sh
#
#     DESCRIPTION: Entrypoint for openvpn docker container
#
# ORIGINAL AUTHOR: David Personette (dperson@gmail.com)
#      UPDATED BY: t3kka
#===============================================================================

set -o nounset                              # Treat unset variables as an error

dir="/PIA_CONFIG"
file="$dir/.firewall"


### firewall: firewall all output not DNS/VPN that's not over the VPN connection
# Arguments:
#   none)
# Return: configured firewall
firewall() { local network docker_network=$(ip -o addr show dev eth0 |
                awk '$3 == "inet" {print $4}')

    iptables -F OUTPUT
    iptables -P OUTPUT DROP
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -o tap0 -j ACCEPT
    iptables -A OUTPUT -o tun0 -j ACCEPT
    iptables -A OUTPUT -d ${docker_network} -j ACCEPT
    iptables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp -m owner --gid-owner vpn -j ACCEPT 2>/dev/null &&
    iptables -A OUTPUT -p udp -m owner --gid-owner vpn -j ACCEPT || {
        iptables -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
        iptables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT; }
    [ -s $file ] && for network in $(cat $file); do return_route $network;done
}

### return_route: add a route back to your network, so that return traffic works
# Arguments:
#   network) a CIDR specified network range
# Return: configured return route
return_route() { local gw network="$1"
    gw=$(ip route | awk '/default/ {print $3}')
    ip route | grep -q "$network" ||
        ip route add to $network via $gw dev eth0
    [ -e $file ] && iptables -A OUTPUT --destination $network -j ACCEPT
    [ -e $file ] && grep -q "^$network\$" $file || echo "$network" >>$file

    echo "RETURN ROUTE SET TO $network"
}

### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC=${1:-0}
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -f          Firewall rules so that only the VPN and DNS are allowed to
                send internet traffic (IE if VPN is down it's offline)
    -r '<network>' CIDR network (IE 192.168.1.0/24)
                required arg: \"<network>\"
                <network> add a route to (allows replies once the VPN is up)

The 'command' (if provided and valid) will be run instead of openvpn
" >&2
    exit $RC
}

while getopts ":hfr:" opt; do
    case "$opt" in
        h) usage ;;
        f) firewall; touch $file ;;
        r) return_route "$OPTARG" ;;
       "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
       ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

if [ $# -ge 1 && -x $(which $1 2>&-) ]; then
    exec "$@"
elif [ $# -ge 1 ]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v 'grep|openvpn.sh' | grep -q openvpn; then
    echo "Service already running, please restart container to apply changes"
else
    exec openvpn --config $dir/CA\ Toronto.ovpn
fi