#!/bin/bash

#debug="true"

pid=$$
port=51510
votingport=51511
countingport=51515
home_dir=/tmp/chat
user_dir=/tmp/chat/users
default_server="188.130.155.41"
echo "" > voting.txt

ncat -m 10 -l -k -v -p $votingport >> voting.txt &

control_c() {
  break
}
trap control_c SIGINT



[ ! -e "$(which ncat)" ] && (echo "ncat is not installed.. cannot continue"; exit 1)

clear_line() {
  printf '\r\033[2K'
}

move_cursor_up() {
  printf '\033[1A'
}






# login
lin() {
  username=$1
  if [ -z "$username" ] # check if username is passed
  then
    echo "ERROR no username specified"
    return 1
  elif [ -e "$user_dir/$username" ] # check if username is taken
  then
    echo "ERROR this username is already taken"
    username="" # reset username variable
    return 1
  fi
  touch $user_dir/$username
  echo "OK"
  tail --pid $pid -q -f $user_dir/$username&
  return
}


# logout
kick() {
  username=$1
  rm -f $user_dir/$username
  username=""
  echo "OK"
  return
}

# logout
lout() {
  echo $username
  username=$1
  if [ -z "$username" ] # check if username is passed
  then
    echo "ERROR you are not logged "
    return 1
  else
    # cleanup when loggin out
    rm -f $user_dir/$username

    username=""
    echo "OK"
    return
  fi
}



# welcome on initial connection
welcome_screen() {
  echo " _ _ _ ___| |___ ___ _____ ___  "
  echo "| | | | -_| |  _| . |     | -_| "
  echo "|_____|___|_|___|___|_|_|_|___| "
  echo "                                "

}

# clanup left over tails running as root
cleanup() {
  ps -ef | grep "\s1\s.*tail.*$home_dir" | grep -v $pid | awk '$3~1 {print $2}' | xargs -i kill {}
}


read_input() {
  read -n 256 command
  echo $command
  return
}






msg() {
  if [ -z "$username" ]   # check if user is logged-in
  then
    echo "ERROR you are not logged in"
    return 1
  fi

  message=$*    # everything else is a part of the message

  if [ $(expr match "$message" '#.*') -gt 0 ] # stickers
  then
    #message=`./stickers/$message` #RCE
    message="`cat ./stickers/$message`"

  fi



  for i in $(ls -l $user_dir | awk '{print $9}');
  do
    printf '\033[0;36m%s: \033[0;39m%s\n\r' "$username" "$message"  >> $user_dir/$i

  done


}

# do something useful
do_something() {
  cleanup
  command="$*"

  case "$command" in
    LOGIN*)
      username=${command#LOGIN }
      username=$(expr match "$username" '\([a-zA-Z0-9]*\)')
      lin $username
      ;;

    LOGOUT*)
      lout $username
      ;;
    *)

      move_cursor_up
      clear_line
      message_string=${command#MSG }
      msg $message_string
      ;;
  esac
}


serve() {
  ncat -m 10 -v -k -l -p $port -c $0  &
  mkdir $home_dir
  mkdir $user_dir
  echo "You is server, great./n Options for controlling: USERS|KICK|LOGIN|LOGOUT|EXIT"
  while true;
  do
    read servcommand
    case "$servcommand" in
      USERS*)
        ls -l $user_dir | awk '{print $9}'
        ;;
      LOGOUT*)
        lout $username
        exit 0
        ;;
      LOGIN*)
        username=${servcommand#LOGIN }
        username=$(expr match "$username" '\([a-zA-Z0-9]*\)')
        lin $username
        ;;
      EXIT*)
        lout $username
        kill $(ps aux | grep 'ncat' | awk '{print $2}') 2>/dev/null
        kill $(ps aux | grep '$0' | awk '{print $2}')   2>/dev/null
        exit 0
        ;;
      KICK*)
        ls -l $user_dir | awk '{print $9}'
        echo "What user do you want to kick? Type "ALL" if you are angry."
        read servcommand
        if [ $servcommand == "ALL" ]
        then
          for i in $(ls -l $user_dir | awk '{print $9}');
          do
            kick $i
          done
        else
          kick $servcommand
        fi
        ;;
      *)
        move_cursor_up
        clear_line
        message_string=${servcommand#MSG }
        msg $message_string
        ;;
    esac
  done

}

# check if a process already running
if [ "$(ps -ef | grep -v grep | grep -c "ncat.*$(basename $0)")" -lt "1" ]
then
  [[ $1 == "server" ]] && serve
  [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && ncat $1 $port
  echo "Scanning for default  server../n"
  open=$(nmap -sT $default_server -p $port  | grep "$port/tcp.*open")
  if [ "$open" ]
  then
    echo "Connecting to default server..."
    ncat $default_server $port
  else
    echo "No connection to defaul server, scanning the network for a server(Press CTRL+C to stop scanning):"
    myip=$(ip a | grep -v "127.0.0.1"| grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}"  -m 1)
    gw=$(ip r | awk '/default/{print$3}')
    echo "my ip is $myip"
    openips=()
    for ip in $(ip a | grep -v "127.0.0.1"| grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}" |grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}" );do

      echo $ip
      openips+=$(nmap -T5 $ip/24 -p $votingport | grep -B 3 "$votingport/tcp.*[open|filtered]" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
      
     
    done

    ##TODO: delete myip and gw
    tmp1="${openips%$myip}"
    tmp2="${tmp1#$gw}"
    openips=$tmp2
    #openips+="188.130.155.41"
    echo "Found this open IP: $openips"
    if [ "$openips" ]; then

      min=99999
      declare -A pingsforserver

      for i in ${openips[*]}; do
        p=$(ping -c 4 $i  | tail -1| awk '{print $4}' | cut -d '/' -f 2)
        pingsforserver[$p]=$i
        if [[ $(echo "$min > $p" | bc) -ne 0  ]]; then
          min=$p
        fi
      done


      #for K in "${!pingsforserver[@]}"; do echo $K; done
      echo "voting process starting"
      ncat -m 10 -v -k -l -p $countingport >> votes.txt &

      echo "min is ${pingsforserver[$min]}, voting for him!"
      echo "1" | ncat ${pingsforserver[$min]} $votingport
      echo "vote sended"
      echo "waiting for result"
      sleep 5
      votes=$(cat ./voting.txt | wc -l)
      echo "calculating votes... you have $votes"

      myip=$(ip a | grep -v "127.0.0.1"| grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}"  -m 1)
      echo "my ip is $myip"

      for i in ${openips[*]}; do
        echo "$votes $myip" | ncat $i $countingport &
      done
      echo "calculating result..."
      sleep 5
      if [[ $votes -lt $( cat votes.txt | sort | tail -1 | cut -d ' ' -f 1 ) ]]; then
        #connect to the server
        sleep 4
        ncat $(cat votes.txt | sort | tail -1 | cut -d ' ' -f 2) $port

      else
        serve
      fi







    else
      serve
    fi

    #serve
  fi

else
  [[ ! $(tty) ]] && exit 1  # if running under ncat and called from TTY -> exit
fi


# Run Forest, run!
welcome_screen

while true; do

  read servcommand
  [ ! -z "$debug" ] && echo "debug: $servcommand"
  do_something "$servcommand"
done

kill $(ps aux | grep 'ncat' | awk '{print $2}') 2>/dev/null
kill $(ps aux | grep '$0' | awk '{print $2}')   2>/dev/null
kill $(ps aux | grep 'tail' | awk '{print $2}')   2>/dev/null

