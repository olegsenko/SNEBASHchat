myip=$(ip a | grep -v "127.0.0.1"| grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}"  -m 1)
gw=$(ip r | awk '/default/{print$3}')
ip1="1.2.3.4"
ip2="188.130.150.41"
echo 
if [[ "$myip" != "$ip1" &&  "$gw" != "$ip1" ]] ; 
then 
echo "$myip and $ip2"
echo "NOt matching" 
else 
echo "$myip and $ip2"
echo  "match" 
fi 