FROM        ubuntu:18.04 AS base
LABEL       maintainer.name="KaiserKatze"
LABEL       maintainer.mail="donizyo@gmail.com"

ENV         PATH_APP=/root/App
WORKDIR     $PATH_APP

# list installed packages
RUN         echo "Installed packages:" && \
            dpkg -l

# install necessary tools
RUN         echo "Installing necessary packages:" && \
            apt-get update && \
            apt-get -y install curl tar git && \
            apt-get -y install build-essential
# Install `gpg`
RUN         apt-get -y install gnupg
# Install `ip`
RUN         apt-get -y install iproute2

# Install unnecessary packages (vim, netstat, ping, nmap)
RUN         apt-get -y install vim net-tools iputils-ping nmap

# install python2.7 on ubuntu:18.04(debian:buster)
RUN         apt-get -y install python2.7
RUN         update-alternatives --install /usr/bin/python python /usr/bin/python2.7 1
