FROM ubuntu
MAINTAINER mwaeckerlin

# requires: --link mysl:mysql

RUN apt-get install -y wget debconf-utils
RUN wget -O - http://packages.icinga.org/icinga.key | apt-key add -
RUN echo "deb http://packages.icinga.org/ubuntu icinga-$(lsb_release -sc) main" > /etc/apt/sources.list.d/icinga-main-trusty.list
RUN apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
      icinga2 icinga2-ido-mysql
RUN touch /firstrun

CMD if test -z "${MYSQL_ENV_MYSQL_ROOT_PASSWORD}"; then \
      echo "You must link to a MySQL docker container: --link mysql-server:mysql" 1>&2; \
      exit 1; \
    fi; \
    if test -e /firstrun; then \
      echo "Configuration of Icinga ..."; \
      PASSWORD=$(sed -n 's/ *password = "\(.*\)",\?/\1/p' \
                 /etc/icinga2/features-available/ido-mysql.conf); \
      DBUSER=$(sed -n 's/ *user = "\(.*\)",\?/\1/p' \
               /etc/icinga2/features-available/ido-mysql.conf); \
      DATABASE=$(sed -n 's/ *database = "\(.*\)",\?/\1/p' \
                 /etc/icinga2/features-available/ido-mysql.conf); \
      HOSTIP="%"; \
      ( echo "icinga2-ido-mysql icinga2-ido-mysql/app-password-confirm password ${MYSQL_ENV_MYSQL_ROOT_PASSWORD} "; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/mysql/admin-pass password ${MYSQL_ENV_MYSQL_ROOT_PASSWORD}"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/password-confirm password ${MYSQL_ENV_MYSQL_ROOT_PASSWORD} "; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/mysql/app-pass password ${MYSQL_ENV_MYSQL_ROOT_PASSWORD}"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/dbconfig-reinstall boolean true"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/database-type select mysql"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/dbconfig-upgrade boolean true"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/mysql/admin-user string root"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/remote/port string ${MYSQL_PORT_3306_TCP_PORT}"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/enable boolean true"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/mysql/method select tcp/ip"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/internal/reconfiguring boolean true"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/upgrade-backup boolean true"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/db/app-user string ${DBUSER}"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/remote/host select mysql"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/purge boolean true"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/dbconfig-remove boolean true"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/dbconfig-install boolean true"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/remote/newhost string mysql"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/db/dbname string ${DATABASE}"; \
      ) | debconf-set-selections; \
      dpkg-reconfigure -f noninteractive icinga2-ido-mysql; \
      echo "update mysql.user set Host='${HOSTIP}' where User='${DBUSER}'; flush privileges;" \
      | mysql -u root --password=${MYSQL_ENV_MYSQL_ROOT_PASSWORD} -h mysql; \
      echo "set password for '${DBUSER}'@'${HOSTIP}' = PASSWORD('${PASSWORD}');" \
      | mysql -u root --password=${MYSQL_ENV_MYSQL_ROOT_PASSWORD} -h mysql; \
      echo "grant all privileges on ${DATABASE}.* to '${DBUSER}'@'${HOSTIP}'; flush privileges;" \
      | mysql -u root --password=${MYSQL_ENV_MYSQL_ROOT_PASSWORD} -h mysql; \
      icinga2 feature enable ido-mysql; \
      icinga2 feature enable command; \
      mkdir -p /run/icinga2/cmd; \
      chown -R nagios.nagios /run/icinga2/; \
      rm  /firstrun; \
      echo "**** Configuration done."; \
      echo "IDO database is:"; \
      cat /etc/icinga2/features-available/ido-mysql.conf; \
    fi; \
    echo "starting icinga2"; \
    /usr/sbin/icinga2 --no-stack-rlimit daemon -e /var/log/icinga2/icinga2.err

VOLUME /var/run/icinga2/cmd
