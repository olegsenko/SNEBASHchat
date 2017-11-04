FROM ubuntu:16.04
COPY ./chat .
RUN apt-get update; apt-get install -y nmap iproute2 iputils-ping bc
CMD ./snEBASHchat.sh $p1
