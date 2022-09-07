
FWEND=nftables

nftables_setup () {

	prompt_input "VLAN ifname" VLAN_IFACE
	prompt_input "VLAN subnet" VLAN_SUBNET

	if [ -z $(command -v nft) ]; then
		echo "(Error) Command nft not found"
		exit 2
	fi
}


nftables_gen_conf () {

	cat <<-EOF
	#!/usr/sbin/nft -f

	flush ruleset

	table inet coderaft {

	        set ban_v4 {
	               type ipv4_addr
	               flags timeout
	        }

	        set ban_v6 {
	                type ipv6_addr
	                flags timeout
	        }

	        chain pre {
	                type filter hook prerouting priority 0
	                policy accept

	                iifname "lo" ip saddr 127.0.0.0/8 accept
	EOF

	if [ ! -z "$VLAN_IFACE" ] && [ ! -z "$VLAN_SUBNET" ]; then
	cat <<-EOF
	                iifname "$VLAN_IFACE" ip saddr $VLAN_SUBNET accept
	EOF
	fi

	cat <<-EOF
	                ip saddr {
	                        0.0.0.0/8,
	                        10.0.0.0/8,
	                        127.0.0.0/8,
	                        169.254.0.0/16,
	                        172.16.0.0/12,
	                        192.0.2.0/24,
	                        192.168.0.0/16,
	                        224.0.0.0/3,
	                        240.0.0.0/5 } drop

	                ct state invalid drop

	                tcp flags != syn / fin,syn,rst,ack ct state new drop
	                tcp flags fin,syn,rst,psh,ack,urg / fin,syn,rst,psh,ack,urg drop
	                tcp flags ! fin,syn,rst,psh,ack,urg drop
	                tcp flags fin,psh,urg / fin,syn,rst,psh,ack,urg drop
	                tcp flags fin / fin,ack drop
	                tcp flags fin,syn / fin,syn drop
	                tcp flags syn,rst / syn,rst drop
	                tcp flags fin,rst / fin,rst drop
	                tcp flags urg / ack,urg drop
	                tcp flags psh / psh,ack drop
	                #meta l4proto tcp ct state new # tcpmss match 1501:65535  drop
	        }

	        chain in {
	                type filter hook input priority 0
	                policy drop

	                iifname "lo" accept

	                fib daddr type broadcast drop
	                fib daddr type multicast drop
	                fib daddr type anycast drop

	                ip saddr @ban_v4 drop
	                ip6 saddr @ban_v6 drop

	                icmp type {
	                        echo-reply,
	                        destination-unreachable,
	                        time-exceeded } accept
	                icmp type echo-request goto in_icmp

	                icmpv6 type {
	                        destination-unreachable,
	                        packet-too-big,
	                        time-exceeded,
	                        echo-reply } accept
	                        icmpv6 type echo-request goto in_icmp

	                meta nfproto ipv4 tcp dport 22 ct state new goto in_ssh
	EOF

	if [ ! -z $HTTPSVC ]; then
	cat <<-EOF
	                tcp dport 80 accept
	                tcp dport 443 accept
	EOF
	fi

	cat <<-EOF
	                ct state related,established accept
	        }

	        chain in_icmp {
	                limit rate 55/minute burst 3 packets accept;
	                add @ban_v4 { ip saddr timeout 5m };
	                add @ban_v6 { ip6 saddr timeout 5m };
	                log prefix "nftables[in_icmp] ban "
	                drop;
	        }

	        chain in_ssh {
	                limit rate 5/minute burst 3 packets accept;
	                add @ban_v4 { ip saddr timeout 1h };
	                log prefix "nftables[in_ssh] ban "
	                drop;
	        }
	}
	EOF
}

