Docker Image for Icinga2 with Web-Management
============================================

Use [mwaeckerlin/icinga2ido](https://github.com/mwaeckerlin/icinga2ido) and [mwaeckerlin/icingaweb2](https://github.com/mwaeckerlin/icingaweb2) together with [mysql](https://hub.docker.com/r/_/mysql/) to get a complete icinga system monitoring with web ui and icinga director for configuration management.

Usage
-----

        docker run -d --restart unless-stopped --name icinga-mysql-volume \
               mysql sleep infinity
        docker run -d --restart unless-stopped --name icinga-mysql \
                   -e MYSQL_ROOT_PASSWORD=$(pwgen 20 1) \
                   --volumes-from icinga-mysql-volume \
               mysql
        docker run -d --restart unless-stopped --name icinga-carbon-volume \
               mwaeckerlin/carbon-cache sleep infinity
        docker run -d --restart unless-stopped --name icinga-carbon \
                      --volumes-from icinga-carbon-volume \
               mwaeckerlin/carbon-cache
        docker run -d --restart unless-stopped --name icinga-volumes \
               mwaeckerlin/icinga2ido sleep infinity
        docker run -d --restart unless-stopped --name icinga \
                   --hostname icinga
                   --link icinga-mysql:mysql \
                   --link icinga-carbon:carbon \
                   --volumes-from icinga-volumes \
               mwaeckerlin/icinga2ido

Please note: If you don't specify a host name, then you get a random hostname on each re-creation of the container. Then the api certificates are no more valid and the service refuses to start. Als the hostname should be the same as the name to keep it simple.

See the log to get the database configuration, users and passwords:

        docker logs -f icinga

When ready, continue with [README.md in mwaeckerlin/icingaweb2](https://github.com/mwaeckerlin/icingaweb2/blob/master/README.md) to setup the wen user interface.


Docker Swarm
------------

This is an example docker compose file that you can use with `docker stack deploy`:

```yaml
version: '3.3'                                                                               
services:                                                                                    
                                                                                             
  mysql:                                                                                     
    image: mysql                                                                             
    volumes:                                                                                 
      - type: bind                                                                           
        source: /var/volumes/icinga/mysql                                                    
        target: /var/lib/mysql                                                               
    environment:                                                                             
      - MYSQL_ROOT_PASSWORD=cu0thei6lahl6eel0Uxadu5eep1eXei5ceesh0gu

  carbon:
    image: mwaeckerlin/carbon-cache
    volumes:
      - type: bind
        source: /var/volumes/icinga/graphite
        target: /var/lib/graphite

  icinga:
    image: mwaeckerlin/icinga2ido
    volumes:
      - type: bind
        source: /var/volumes/icinga/cmd
        target: /var/run/icinga2/cmd
      - type: bind
        source: /var/volumes/icinga/lib
        target: /var/lib/icinga2
      - type: bind
        source: /var/volumes/icinga/etc/icinga
        target: /etc/icinga2
    environment:
      - MYSQL_ROOT_PASSWORD=cu0thei6lahl6eel0Uxadu5eep1eXei5ceesh0gu
      - ICINGA_PW=sejae9peiph0mailahkuweshioDoo6sheewoow4E
      - WEB_PW=Eifei4echanoongooriiw4ooNgiong5iepur0vei
      - DIRECTOR_PW=xom9Ahlah0uth4ohv1ahxuichimieth8xohk8poh

  icingaweb:
    image: mwaeckerlin/icingaweb2
    ports:
      - 8016:80
    volumes:
      - type: bind
        source: /var/volumes/icinga/cmd
        target: /var/run/icinga2/cmd
      - type: bind
        source: /var/volumes/icinga/etc/web
        target: /etc/icingaweb2
      - type: bind
        source: /var/volumes/icinga/log
        target: /var/log/icingaweb2
```