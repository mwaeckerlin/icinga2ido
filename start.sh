#!/bin/bash -e

# template for bash scripts

# internal use only
append_msg() {
    if test $# -ne 0; then
        echo -en ":\e[0m \e[1m$*"
    fi
    echo -e "\e[0m"
}

# write a notice
notice() {
    if test $# -eq 0; then
        return
    fi
    echo -e "\e[1m$*\e[0m" 1>&3
}

# write error message
error() {
    echo -en "\e[1;31merror" 1>&2
    append_msg $* 1>&2
}

# write a warning message
warning() {
    echo -en "\e[1;33mwarning" 1>&2
    append_msg $* 1>&2
}

# write a success message
success() {
    echo -en "\e[1;32msuccess" 1>&2
    append_msg $* 1>&2
}

# commandline parameter evaluation
while test $# -gt 0; do
    case "$1" in
        (--help|-h) less <<EOF
SYNOPSIS

  $0 [OPTIONS]

OPTIONS

  --help, -h                 show this help

DESCRIPTION

  start icinga daemon in mwaeckerlin/icinga docker container

EOF
            exit;;
        (*) error "unknow option $1, try $0 --help"; exit 1;;
    esac
    if test $# -eq 0; then
        error "missing parameter, try $0 --help"; exit 1
    fi
    shift;
done

# run a command, print the result and abort in case of error
# option: --no-check: ignore the result, continue in case of error
run() {
    check=1
    while test $# -gt 0; do
        case "$1" in
            (--no-check) check=0;;
            (*) break;;
        esac
        shift;
    done
    echo -en "\e[1m-> running:\e[0m $* ..."
    result=$($* 2>&1)
    res=$?
    if test $res -ne 0; then
        if test $check -eq 1; then
            error "failed with return code: $res"
            if test -n "$result"; then
                echo "$result"
            fi
            exit 1
        else
            warning "ignored return code: $res"
        fi
    else
        success
    fi
}

# error handler
function traperror() {
    set +x
    local err=($1) # error status
    local line="$2" # LINENO
    local linecallfunc="$3"
    local command="$4"
    local funcstack="$5"
    for e in ${err[@]}; do
        if test -n "$e" -a "$e" != "0"; then
            error "line $line - command '$command' exited with status: $e (${err[@]})"
            if [ "${funcstack}" != "main" -o "$linecallfunc" != "0" ]; then
                echo -n "   ... error at ${funcstack} "
                if [ "$linecallfunc" != "" ]; then
                    echo -n "called at line $linecallfunc"
                fi
                echo
            fi
            exit $e
        fi
    done
    success
    exit 0
}

# catch errors
trap 'traperror "$? ${PIPESTATUS[@]}" $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[@]}" "${FUNCTION}"' ERR SIGINT INT TERM EXIT

###########################################################################################

# restore file structure in case an empty volume is mounted
test -d /etc/icinga2/features-available || apt -o Dpkg::Options::="--force-confmiss" install --reinstall $(dpkg -S /etc/icinga2 | sed 's,:.*,,g')

# wait for mysql to become ready
mysql=0
if test -n "${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD}}"; then
    echo "wait ${WAIT_SECONDS_FOR_MYSQL:-300}s for mysql to become ready"
    for ((i=0; i<${WAIT_SECONDS_FOR_MYSQL:-300}; ++i)); do
        if mysql -e "select 1" -h mysql -u root -p"${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD}}" 2> /dev/null > /dev/null; then
            echo "mysql is ready"
            mysql=1
            break;
        fi
        sleep 1
    done
fi
if test $mysql -eq 0; then
    cat 1>&2 <<EOF
**** ERROR: mysql database not found

      - you must link to a MySQL docker container and name it mysql
        e.g. --link mysql-server:mysql
      - mysql server must have a database configured

Example:

  docker run -d --restart always --name icinga-mysql \\
             -e MYSQL_ROOT_PASSWORD=$(pwgen 20 1) \\
         mysql
  docker run -d --restart always --name icinga \\
             --link icinga-mysql:mysql \\
         mwaeckerlin/icinga2ido

EOF
    exit 1
fi

if test -e /firstrun; then
    echo "Configuration of Icinga ..."
    test -d /etc/icinga2/features-available || apt install --reinstall -y icinga2-common
    if test -z "${ICINGA_PW}"; then
        ICINGA_PW=$(pwgen 40 1)
    fi
    if test -z "${WEB_PW}"; then
        WEB_PW=$(pwgen 40 1)
    fi
    if test -z "${DIRECTOR_PW}"; then
        DIRECTOR_PW=$(pwgen 40 1)
    fi
    mysql -h mysql -u root -p"${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD}}" <<EOF
CREATE DATABASE ${ICINGA_DB:-icinga} CHARACTER SET 'utf8';
CREATE DATABASE ${WEB_DB:-icingaweb} CHARACTER SET 'utf8';
CREATE DATABASE ${DIRECTOR_DB:-director} CHARACTER SET 'utf8';
GRANT ALL ON ${ICINGA_DB:-icinga}.* TO ${ICINGA_USER:-icinga}@'%' IDENTIFIED BY '${ICINGA_PW}';
GRANT ALL ON ${WEB_DB:-icingaweb}.* TO ${WEB_USER:-icingaweb}@'%' IDENTIFIED BY '${WEB_PW}';
GRANT ALL ON ${DIRECTOR_DB:-director}.* TO ${DIRECTOR_USER:-director}@'%' IDENTIFIED BY '${DIRECTOR_PW}';
FLUSH PRIVILEGES;
EOF
    mysql -h mysql -u "${ICINGA_USER:-icinga}" -p"${ICINGA_PW}" "${ICINGA_DB:-icinga}" < /usr/share/icinga2-ido-mysql/schema/mysql.sql
    cat > /etc/icinga2/features-available/ido-mysql.conf <<EOF
/**
 * The db_ido_mysql library implements IDO functionality
 * for MySQL.
 */

library "db_ido_mysql"

object IdoMysqlConnection "ido-mysql" {
  user = "${ICINGA_USER:-icinga}",
  password = "${ICINGA_PW}",
  host = "mysql",
  database = "${ICINGA_DB:-icinga}"
}
EOF
    chown nagios.nagios /etc/icinga2/features-available/ido-mysql.conf
    chmod go= /etc/icinga2/features-available/ido-mysql.conf
    icinga2 feature enable ido-mysql
    icinga2 feature enable command
    test -d /run/icinga2/cmd || mkdir -p /run/icinga2/cmd
    chown -R nagios.nagios /run/icinga2/
    icinga2 api setup
    cat >> /etc/icinga2/conf.d/api-users.conf <<EOF
object ApiUser "${DIRECTOR_USER:-director}" {
  password = "${DIRECTOR_PW}"
  permissions = [ "*" ]
}
EOF
    rm  /firstrun
    echo "**** Configuration done."
    echo "IDO database is:"
    cat /etc/icinga2/features-available/ido-mysql.conf
    echo "Icinga database:            ${ICINGA_DB:-icinga}"
    echo "Icinga database user:       ${ICINGA_USER:-icinga}"
    echo "Icinga database password:   ${ICINGA_PW}"
    echo "Web database:               ${WEB_DB:-icingaweb}"
    echo "Web database user:          ${WEB_USER:-icingaweb}"
    echo "Web database password:      ${WEB_PW}"
    echo "Director module user:       ${DIRECTOR_USER:-director}"
    echo "Director module password:   ${DIRECTOR_PW}"
    echo "Director database:          ${DIRECTOR_DB:-director}"
    echo "Director database user:     ${DIRECTOR_USER:-director}"
    echo "Director database password: ${DIRECTOR_PW}"
    echo "Director endpoint:          $(ls /etc/icinga2/pki | sed -n 's/.key//p')"
fi
echo "starting icinga2"
/usr/sbin/icinga2 --no-stack-rlimit daemon -e /var/log/icinga2/icinga2.err
