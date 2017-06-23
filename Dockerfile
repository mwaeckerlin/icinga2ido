FROM mwaeckerlin/ubuntu-base
MAINTAINER mwaeckerlin

# requires: --link mysl:mysql

RUN apt-get install -y wget debconf-utils pwgen nmap
RUN wget -O - http://packages.icinga.org/icinga.key | apt-key add -
RUN echo "deb http://packages.icinga.org/ubuntu icinga-$(lsb_release -sc) main" > /etc/apt/sources.list.d/icinga-main-trusty.list
RUN apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
      icinga2 icinga2-ido-mysql
RUN touch /firstrun

ADD start.sh /start.sh
CMD /start.sh

VOLUME /var/run/icinga2/cmd
VOLUME /etc/icinga2
