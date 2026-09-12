#!/bin/sh

ip link add link br0 name br0.10 type vlan id 10
ip link set br0.10 up
ip addr add 192.168.10.1/24 dev br0.10

ip link add link wan name wan.10 type vlan id 10
ip link set wan.10 up
ip addr add 11.0.10.1/24 dev wan.10
