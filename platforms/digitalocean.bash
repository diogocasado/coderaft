
PLAT_ID=do
PLAT_DESC="DigitalOcean (https://digitalocean.com)"

VLAN_IFACE="eth0"
VLAN_SUBNET="10.132.0.0/16"

platform_setup () {
	prompt_input "DigitalOcean Token" DO_TOKEN null
}
