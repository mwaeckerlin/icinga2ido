Docker Image for Icinga2 with Web-Management
============================================

Use [mwaeckerlin/icinga2ido](https://github.com/mwaeckerlin/icinga2ido) and [mwaeckerlin/icingaweb2](https://github.com/mwaeckerlin/icingaweb2) together with [mysql](https://hub.docker.com/r/_/mysql/) to get a complete icinga system monitoring with web ui and icinga director for configuration management.

Usage
-----

        docker run -d --restart unless-stopped --name icinga-mysql-volume \
               mysql sleep infinity
        docker run -d --restart unless-stopped --name icinga-mysql \
                   -e MYSQL_ROOT_PASSWORD=$(pwgen 20 1) \
                   -e MYSQL_DATABASE=icinga \
                   -e MYSQL_USER=icinga \
                   -e MYSQL_PASSWORD=$(pwgen 20 1) \
                   --volumes-from icinga-mysql-volume \
               mysql
        docker run -d --restart unless-stopped --name icinga-volumes \
               mwaeckerlin/icinga2ido sleep infinity
        docker run -d --restart unless-stopped --name icinga \
                   --link icinga-mysql:mysql \
                   --volumes-from icinga-volumes \
               mwaeckerlin/icinga2ido

See the log to get the database configuration, users and passwords:

        docker logs -f icinga

When ready, continue with [README.md in mwaeckerlin/icingaweb2](https://github.com/mwaeckerlin/icingaweb2/blob/master/README.md) to setup the wen user interface.
