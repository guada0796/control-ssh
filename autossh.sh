#!/bin/bash
#Autor: Steven Guadalupe
#Control de conexiones ssh

#URL DEL ARCHIVO QUE CONTIENE LAS SSH QUE DEBEN ESTAR CONECTADAS
conections="/home/el-admin/.ssh-control/ssh-activas.txt"

#LEER ARCHIVO DE CONEXIONES SSH ACTIVAS
names=($(cat $conections | awk -F ';' '{print $1}'))
ips=($(cat $conections | awk -F ';' '{print $2}'))
ports=($(cat $conections | awk -F ';' '{print $3}'))
vpns=($(cat $conections | awk -F ';' '{print $4}'))
scripts=($(cat $conections | awk -F ';' '{print $5}'))

#TIEMPO DE ESPERA TRAS CADA VERIFICACION
timesleep=1

#TIEMPO DE ESPERA PARA PROBAR CONEXIONES SSH
timeout=3

#INTENTOS DE RECONEXION
attemps=2

#ESTADOS ESPERADOS
establecido="ESTAB"

#BANDERA DE MAIL
sendmail="false"
message=("Aqui van los nombres de conexiones rebeldes")

#REALIZA LA RECONECION SSH
function reconect(){
	echo "INTENTANDO RECONECTAR $1 => $2"
	#SE ITERAN LOS INTENTOS DE CONEXION
	for((j=0;j<$attemps;j=j+1))
	do
		result=""
		#RECONECTANDO
		echo "ITERACION $j"
		ssh -N -f $1
		sleep $timesleep
		echo "REALIZANDO VERIFICACION DE CONEXION"
		result=$(ss | egrep ${ips[j]}:${ports[j]} | awk '{print $2}')
		echo $result
		#VERIFICACION DE ESTADO ACTUAL
		if [ "$result" = "$establecido" ] 
		then
			#PARA ROMPER EL CICLO
			j=$attemps
			echo "SE ESTABLECIO NUEVAMENTE LA CONEXION ${names[j]} RESULTADO: $result"
		fi
		
	done
	
	#SI LA CONEXION NO SE PUDO ESTABLECER, ENVIAR EL CORREO
	if [ "$result" != "$establecido" ] 
	then
		sendmail="true"
		echo "Correo: $1 => $2"
	fi
}

#ENVIO DE CORREO ELECTRONICO
function sendEmail(){
	if [ "${sendmail}" = "true" ]
	then
		echo -e "Estimado,\n\nSe notifica que en el/los siguiente/s tunel/es se encontraron problemas al intentar reconectarse automáticamente, por favor revise las conexiones pertinentes.\n\n${message[*]}\n\nMuchas gracias." | mutt -s "Fallo reconeccion de tunel automática" heccer.benavides@softwarehouse.com.ec
	fi
}

#PROCESA LA VERIFICACION DE LAS CONEXIONES
function process(){

	#VERIFICA SI EL TAMANIO DE ARREGLOS DE LOS DATOS PRINCIPALES ES IGUAL
	if (( ${#names[*]}>0 && ${#names[*]}==${#ips[*]} && ${#names[*]}==${#ports[*]} && ${#names[*]}==${#vpns[*]}))
	then

		#ITERADO LAS CONEXIONES
		for((i=0;i<${#names[*]};i=i+1))
		do
			result=""
			#VERIFICACION DE COMUNICACION CON TUNEL SSH
			$(timeout $timeout bash -c "</dev/tcp/${ips[i]}/${ports[i]}")
			#result=$(nmap ${ips[i]} -PN -p ${ports[i]} | egrep 'open|closed|filtered' | awk '{print $2}')
			result=$?
			echo ">>> COMUNICACION CON ${names[i]} RESULTADO: $result <<<"

			#SI EL VALOR DE LA COMUNICACION ES 0, ES POSIBLE CONECTARSE AL TUNEL
			if (($result==0))
			then

				#VERIFICACION DEL ESTADO ACTUAL DEL TUNEL
				result=$(ss | egrep ${ips[i]}:${ports[i]} | awk '{print $2}')
				echo $result
				
				if [ "$result" != "$establecido" ] 
				then
					
					reconect ${names[i]} "${ips[i]}:${ports[i]}"

				else
					echo "CONEXION ${names[i]} VERIFICADA"
				fi
			else

				#EN CASO DE QUE NO EXISTA COMUNICACION MEDIANTE CON TUNEL, SE VERIFICA QUE LA CONEXION ES POR VPN
				if [ "${vpns[i]}" = "1" ]
				then

					#VERIFICACION DE VPN, EL SCRIPT DEVUELVE 0 SI LA CONEXION ESTA ESTABLECIDA
					./${scripts[i]}
					sleep $timesleep
					if [ $? == 0 ] 
					then
						#RECONECTAR SSH
						echo "CONEXION DE VPN EXITOSA"
						reconect ${names[i]} "${ips[i]}:${ports[i]}"

					else
						echo "NO FUE POSIBLE CONECTAR VPN"
						sendmail="true"
						echo "Correo: ${names[i]} => ${ips[i]}:${ports[i]}"

					fi
				else

					#EN CASO DE QUE NO SE PUDO ESTABLECER CONEXION Y EL TUNEL NO SE CONECTA MEDIANTE VPN, SE REGISTRAN LOS DATOS
					#PARA EL ENVIO DE CORREO
					sendmail="true"
					echo "Correo: ${names[i]} => ${ips[i]}:${ports[i]}"
				fi
			fi
			
		done	

		#sendEmail
		echo "ENVIO DE CORREO"
	else
		echo 'ARCHIVO CON FORMATO ERRONEO'
	fi
}

process