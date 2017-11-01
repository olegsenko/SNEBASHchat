#!/bin/bash

#debug="true"

pid=$$
port=51510
home_dir=/tmp/chat
user_dir=/tmp/chat/users


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

# read input (256 char max)
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
  
  if [ $(expr match "$message" '#.*') -gt 0 ]
  then
    #message=`./stickers/$message` #RCE
    message="`cat ./stickers/$message`"
    #read message < ./stickers/$message
  fi

  

  for i in $(ls -l $user_dir | awk '{print $9}');  # deliver the message to everyone in the room
  do                                
     printf '\033[0;36m%s: \033[0;39m%s\n\r' "$username" "$message"  >> $user_dir/$i
     
  done

 
}

# do something useful
do_something() {
  cleanup
  command="$*"
  niy="is not implemented yet.."
  case "$command" in
  LOGIN*)
    username=${command#LOGIN }
    username=$(expr match "$username" '\([a-zA-Z0-9]*\)')
    lin $username
  ;;
  LOGOUT*)
    lout $username
    exit 0
  ;;
  *)
   move_cursor_up
   clear_line 
   message_string=${command#MSG }   
   msg $message_string
    ;;
  esac
}




# check if a process already running
if [ "$(ps -ef | grep -v grep | grep -c "ncat.*$(basename $0)")" -lt "1" ]
then
  echo "starting Chat server in 3 seconds"
  for i in {1..0}; do echo -ne "${i}.. "; sleep 1; done
  [ ! -e "$user_dir" ] && mkdir -p $user_dir
  

  ##TODO: fix client or server
  if [ "$(ps -ef | grep -v grep | grep -c "ncat -m 10 -v -k -l -p $port")" -gt "0" ]
  then 
    kill $(ps aux | grep 'ncat -m 10 -v -k -l -p $port' | awk '{print $2}')
    echo "this is not bg"
    ncat -m 10 -v -k -l -p $port -c $0 
  else 
    echo "this is bg"
     ps aux | grep -v grep | grep "ncat -m 10 -v -k -l -p" | awk '{print $2}' | xargs -i kill {}
     ncat -m 10 -v -k -l -p $port -c $0 &
  fi


  while true; 
  do 
  read servcommand  
  case "$servcommand" in
  USERS*)
    ls -l $user_dir | awk '{print $9}'
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
  echo "wat?"  
  ;;
  esac
  done



else
  [[ ! $(tty) ]] && exit 1  # if running under ncat and called from TTY -> exit
fi


# Run Forest, run!
welcome_screen
echo $1
while true; do
  command=$(read_input)
  [ ! -z "$debug" ] && echo "debug: $command"
  do_something "$command"
done

