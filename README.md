# Docker Image for Icinga2 with IDO and MySQL - use separate Icinga2 Webinterface

## Usage

        docker run -d --name icinga-mysql-volume mysql
        docker run -d --name icinga-mysql -e MYSQL_RANDOM_ROOT_PASSWORD=1 -e MYSQL_DATABASE=icinga -e MYSQL_USER=icinga -e MYSQL_PASSWORD=$(pwgen 20 1) --volumes-from icinga-mysql-volume mysql
        docker run -d --name icinga-volumes mwaeckerlin/icinga
        docker run -d --name icinga --link icinga-mysql:mysql --volumes-from icinga-volumes mwaeckerlin/icinga
        docker run -d --name icingaweb-volumes mwaeckerlin/icingaweb2
        docker run -d --name icingaweb --link icinga-mysql:mysql --volumes-from icinga-volumes --volumes-from icingaweb-volumes -p 80:80 mwaeckerlin/icingaweb2

## Database Configuration for IcingaWeb2

To setup mwaeckerlin/icingaweb2, you need the ido database configuration data. At the end of setup, these are printed out, so call `docker icinga logs` to see them:

        **** Configuration done.
        IDO database is:
        /**
         * The db_ido_mysql library implements IDO functionality
         * for MySQL.
         */        
        
        library "db_ido_mysql"
        
        object IdoMysqlConnection "ido-mysql" {
          user = "icinga2",
          password = "aPassWord",
          host = "mysql",
          database = "icinga2"
        }

## Known Problems and Limitations:

  1. Warning:

        warning/ApplyRule: Apply rule 'satellite-host' (in /etc/icinga2/conf.d/satellite.conf: 29:1-29:41) for type 'Dependency' does not match anywhere!
  2. No Mail Tool Yet:

         warning/PluginNotificationTask: Notification command for object '4251edee216c!ssh' (PID: 510, arguments: '/etc/icinga2/scripts/mail-service-notification.sh') terminated with exit code 127, output: /etc/icinga2/scripts/mail-service-notification.sh: 20: /etc/icinga2/scripts/mail-service-notification.sh: mail: not found