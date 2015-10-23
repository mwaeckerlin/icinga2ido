FROM ubuntu
MAINTAINER mwaeckerlin

# requires: --link mysl:mysql
ENV WEBPATH /icingaweb2
ENV TIMEZONE "Europe/Zurich"

RUN apt-get install -y wget debconf-utils
RUN wget -O - http://packages.icinga.org/icinga.key | apt-key add -
RUN echo "deb http://packages.icinga.org/ubuntu icinga-$(lsb_release -sc) main" > /etc/apt/sources.list.d/icinga-main-trusty.list
RUN apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
      icinga2 icinga2-ido-mysql icingaweb2 \
      php5-intl php5-gd php5-imagick php5-pgsql php5-mysql
RUN touch /firstrun

CMD if test -z "${MYSQL_ENV_MYSQL_ROOT_PASSWORD}"; then \
      echo "You must link to a MySQL docker container: --link mysql-server:mysql" 1>&2; \
      exit 1; \
    fi; \
    if test -e /firstrun; then \
      echo "Configuration of Icinga ..."; \
      ( echo "icinga2-ido-mysql icinga2-ido-mysql/app-password-confirm password ${MYSQL_ENV_MYSQL_ROOT_PASSWORD} "; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/mysql/admin-pass password ${MYSQL_ENV_MYSQL_ROOT_PASSWORD}"; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/password-confirm password ${MYSQL_ENV_MYSQL_ROOT_PASSWORD} "; \
        echo "icinga2-ido-mysql icinga2-ido-mysql/mysql/app-pass password ${MYSQL_ENV_MYSQL_ROOT_PASSWORD}"; \
        PASSWORD=$(sed -n 's, *password = "\(.*\)",\1,p' \
                   /etc/icinga2/features-available/ido-mysql.conf); \
        DBUSER=$(sed -n 's, *user = "\(.*\)",\1,p' \
                 /etc/icinga2/features-available/ido-mysql.conf); \
        DATABASE=$(sed -n 's, *database = "\(.*\)",\1,p' \
                   /etc/icinga2/features-available/ido-mysql.conf); \
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
      icinga2 feature enable ido-mysql; \
      icinga2 feature enable command; \
      head -c 12 /dev/urandom | base64 > /etc/icingaweb2/setup.token; \
      chmod 0660 /etc/icingaweb2/setup.token; \
      sed -i 's,;\?date.timezone =.*,date.timezone = "'${TIMEZONE}'",g' \
             /etc/php5/apache2/php.ini; \
      mkdir /var/log/icingaweb2; \
      chown www-data.www-data /var/log/icingaweb2; \
      mkdir /run/icinga2/; \
      chown nagios.nagios /run/icinga2/; \
      rm  /firstrun; \
      echo "**** Configuration done."; \
      echo "To setup, head your browser to (port can be different):"; \
      echo "  http://localhost:80${WEBPATH}/setup"; \
      echo "and enter the following token:"; \
      echo "  $(cat /etc/icingaweb2/setup.token)"; \
      echo "IDO database is:"; \
      cat /etc/icinga2/features-available/ido-mysql.conf; \
    fi; \
    echo "starting apache"; \
    /usr/sbin/icinga2 --no-stack-rlimit daemon -e /var/log/icinga2/icinga2.err; \
    apache2ctl -DFOREGROUND;
