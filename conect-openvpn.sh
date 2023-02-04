#!/bin/bash
#Autor: Steven Guadalupe
#Script de conexion tunel openvpn

#ESTADO ESPERADO
establecido="ESTAB"

#RUTA DE UBICACION ARCHIVO .OVPN
ruta="/home/el-admin/fitbank/ovpns/"

#VERIFICACION DE ESTADO ACTUAL
result=$(ss | egrep openvpn | awk '{print $2}')
if [ "$result" != "$establecido" ] 
then
    #POSICIONARSE EN LA RUTA DE ARCHIVO .OVPN
    cd $ruta
    sudo openvpn oficina.ovpn

    #POSIBLEMENTE ESTE VALOR SE DEBA SUBIR, DEPENDERA DE LA RAPIDEZ QUE OPENVPN SE CONECTE
    sleep 2    

    #VERIFICACION DEL NUEVO ESTADO
    result=$(ss | egrep openvpn | awk '{print $2}')
    if [ "$result" != "$establecido" ] 
    then
        exit 1
    fi
fi

exit 0
