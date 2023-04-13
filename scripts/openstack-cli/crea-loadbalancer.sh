#!/bin/bash

# creacion de loadbalancer
neutron lbaas-loadbalancer-create --name $1-loadbalancer $1-subnet-lab2 2> /dev/null

# espera a que el balanceador de carga este activo
OP_STATUS=$(neutron lbaas-loadbalancer-show proyecto8-loadbalancer -c operating_status -f value 2> /dev/null)
PROV_STATUS=$(neutron lbaas-loadbalancer-show $1-loadbalancer -c provisioning_status -f value 2> /dev/null)
while [ "$PROV_STATUS" != "ACTIVE" ] && [ "$OP_STATUS" != "ONLINE" ]
do
    sleep 1
    OP_STATUS=$(neutron lbaas-loadbalancer-show proyecto8-loadbalancer -c operating_status -f value 2> /dev/null)
    PROV_STATUS=$(neutron lbaas-loadbalancer-show $1-loadbalancer -c provisioning_status -f value 2> /dev/null)
done

# creacion de listener y se lo asignamos al balanceador de carga
neutron lbaas-listener-create --name $1-listener --loadbalancer $1-loadbalancer --protocol HTTP --protocol-port 80 2> /dev/null

# espera de actualizacion del balanceador de carga al asignarle el listener
PROV_STATUS=$(neutron lbaas-loadbalancer-show $1-loadbalancer -c provisioning_status -f value 2> /dev/null)
while [ "$PROV_STATUS" == "PENDING_UPDATE" ]
do
    sleep 1
    PROV_STATUS=$(neutron lbaas-loadbalancer-show $1-loadbalancer -c provisioning_status -f value 2> /dev/null)
done

# creacion del pool en la cual se encontraran las instancias del balanceador de carga
neutron lbaas-pool-create --name $1-pool --lb-algorithm ROUND_ROBIN --listener $1-listener --protocol HTTP 2> /dev/null
sleep 1

# creacion de los miembros del pool que representan los servidores creados en terraform
for i in {1..3}; do
    ADDRESS=$(openstack server list --name $1-server$i -c Networks -f value | cut -d'=' -f2)
    neutron lbaas-member-create --name member-$i --subnet $1-subnet-lab2 --address $ADDRESS --protocol-port 80 $1-pool 2> /dev/null
done

# creacion de healthmonitor para monitorear el estado de salud de cada instancia
neutron lbaas-healthmonitor-create --name $1-healthmonitor --delay 5 --type HTTP --max-retries 3 --timeout 2 --pool $1-pool 2> /dev/null

# asociamos el floating ip al puerto correspondiente al balanceador de carga
FLOATING_IP=$(openstack floating ip list -c ID -f value 2> /dev/null)
LOADBALANCER=$(neutron lbaas-loadbalancer-list -c id -f value 2> /dev/null)
PORT_ID=$(neutron lbaas-loadbalancer-show $LOADBALANCER -c vip_port_id -f value 2> /dev/null)
neutron floatingip-associate $FLOATING_IP $PORT_ID 2> /dev/null

# se realizan actualizaciones al puerto del balanceador de cargar para permitir requests del puerto 80
neutron port-update --security-group $1-secgroup-rule $PORT_ID 2> /dev/null
neutron port-update --security-group $1-secgroup $PORT_ID 2> /dev/null

# Notas sobre las Pruebas a realizar:
# neutron lbaas-member-list proyecto8-pool --sort-key address --sort-dir asc

# for i in {1..20}; do
#     curl -w "\n" http://147.156.86.10/index.html | grep <title>
#     sleep 0.2
# done