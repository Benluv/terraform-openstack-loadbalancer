FLOATING_IP=$(openstack floating ip list -c ID -f value)
neutron floatingip-disassociate $FLOATING_IP 2> /dev/null

neutron lbaas-healthmonitor-delete $1-healthmonitor 2> /dev/null

neutron lbaas-pool-delete $1-pool 2> /dev/null

neutron lbaas-listener-delete $1-listener 2> /dev/null

neutron lbaas-loadbalancer-delete $1-loadbalancer 2> /dev/null