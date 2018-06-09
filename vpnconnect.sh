#!/bin/bash

#Script pour se connecter directement au serveur VPN le plus rapide identifie dans le liste

dir="/home/s0bek/Documents/VPN/config"
current=$(pwd)
cd $dir
target=$(find $dir -name "*.ovpn" -type f)
#ici creer tableau contenant chaque resultat de la duree du premier ping
declare -A time
declare -A hosts

i=0
j=0
fastest="1000"
server=""

for file in $target; do
    host=$(cat "$file" | grep "remote" | grep "tcp" | cut -d " " -f2)
    time=$(ping $host -c1 -n | grep "time=" | cut -d "=" -f4 | cut -d " " -f1)

    time["$i"]="$time" && hosts["$j"]="$host"

    evaluate=$(echo "${time["$i"]} < $fastest" | bc)

    if [ $evaluate == 1 ]; then
        fastest="${time["$i"]}"
        server="$i"
    fi

    i=$(expr $i + 1)
    j=$(expr $j + 1)
done

#$fastest designe le temps le plus rapid et $server l'indice du tableau correspondant au serveur le plus rapide
#On affiche donc l'adresse du serveur vpn le plus rapide (on ne tient pas compte des erreurs, a corriger un peu plus tard pour ne pas trop fausser les resultats)
for j in ${!hosts[*]}; do
    fastest=""
    if [[ "$j" == "$server" ]]; then
        fastest="${hosts["$j"]}"
        config=$(grep $fastest * | cut -d ":" -f1 | head -1)
        #echo "Fichier de configuration identifie: $config"
        echo "Connexion au serveur $fastest identifie comme etant le plus rapide..."
        sudo openvpn --config $config
    fi
done

cd $current
