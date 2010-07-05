#!/bin/bash

## FUNCTIONS

check_bitnami_dir()
{
  test -d "$1" || return 1
  test -f "$1/ctlscript.sh" || return 1
  test -f "$1/properties.ini" || return 1

  mysqladmin=$bitnami/mysql/bin/mysqladmin
  test -x "$mysqladmin" || return 1
  mysql=$bitnami/mysql/bin/mysql
  test -x "$mysql" || return 1

  return 0
}

## SCRIPT

cd `dirname $0`

echo "Welcome to the Enano CMS BitNami module installer."
autobitnami=""
if test -n "$HOME"; then
  autobitnami=$(echo $HOME/lampstack-*)
  if test ! -d "$autobitnami"; then
    autobitnami=""
  fi
fi
while true; do
  if test -n "$autobitnami"; then
    read -p "Path to BitNami directory [$autobitnami]: " bitnami
    test -z "$bitnami" && bitnami="$autobitnami"
  else
    read -p "Path to BitNami directory: " bitnami    
  fi
  check_bitnami_dir $bitnami && break
  echo "This does not seem to be the home of a BitNami LAMPStack installation."
done

if [ -d $bitnami/apps/enanocms ]; then
  echo "Enano is already installed as a module on this LAMPStack."
  exit 1
fi

mysql_port=$(cat $bitnami/properties.ini | grep mysql_port | sed -re 's/^mysql_port=//g')

while true; do
  read -s -p "MySQL root password: " mysqlpass
  echo ""
  out=`$mysqladmin -u root --password="$mysqlpass" ping 2>&1`
  test "$out" = "mysqld is alive" && break
  echo $out
done

echo "Creating database."

bitnami_db="bn_enanocms"
bitnami_user="bn_enanocms"
bitnami_pass=`dd if=/dev/urandom bs=256 count=1 2>/dev/null | tr -cd '\41-\46\50-\176' | cut -c 1-12`

query='CREATE DATABASE IF NOT EXISTS `'$bitnami_db'`; GRANT ALL PRIVILEGES ON '$bitnami_db'.* TO '"$bitnami_user"'@localhost IDENTIFIED BY '"'$bitnami_pass'"'; FLUSH PRIVILEGES;'
echo "$query" | $mysql -u root --password="$mysqlpass" || exit 1

echo "Installing files."
mkdir -p $bitnami/apps/enanocms/{conf,licenses} || exit 1
cp -r ./enano-* $bitnami/apps/enanocms/htdocs || exit 1
cp ./COPYING $bitnami/apps/enanocms/licenses/ || exit 1
cat <<EOF > $bitnami/apps/enanocms/conf/enanocms.conf
Alias /enanocms "$bitnami/apps/enanocms/htdocs"

<Directory "$bitnami/apps/enanocms/htdocs">
    Options -Indexes MultiViews FollowSymLinks
    AllowOverride All
    Order allow,deny
    Allow from all
</Directory>
EOF
cp ./uninstall.sh $bitnami/apps/enanocms/

echo "Patching Apache configuration."
if test x$(cat $bitnami/apache2/conf/httpd.conf | grep '^Include' | grep enanocms | wc -l) = x0; then
  echo -ne "\nInclude "'"'"$bitnami/apps/enanocms/conf/enanocms?conf"'"'"\n" >> $bitnami/apache2/conf/httpd.conf
fi

echo "Adding Enano to BitNami's applications.html."
if test x$(cat $bitnami/apache2/htdocs/applications.html | fgrep 'START BitNami Enano CMS Module enanocms' | wc -l) = x0; then
  cp enanocms-module.png $bitnami/apache2/htdocs/img/
  line=$(cat $bitnami/apache2/htdocs/applications.html | fgrep -n '<!-- @@BITNAMI_MODULE_PLACEHOLDER@@ -->' | cut -d ':' -f 1)
  head -n $(($line - 1)) $bitnami/apache2/htdocs/applications.html > ./applications-temp.html
  cat application.html >> ./applications-temp.html
  tail -n +$line $bitnami/apache2/htdocs/applications.html >> ./applications-temp.html
  mv ./applications-temp.html $bitnami/apache2/htdocs/applications.html
fi

echo "Starting Enano installer."
while true; do
  if $bitnami/php/bin/php $bitnami/apps/enanocms/htdocs/install/install-cli.php -b mysql -h 127.0.0.1 -o $mysql_port -u "$bitnami_user" -p "$bitnami_pass" -d $bitnami_db -i /enanocms -r rewrite
  then
    break
  else
    read -n 1 -p "Try installation again? [y/N] " RETRY
    if test "$RETRY" != "y"; then
      cat <<EOF

Enano installation failed. To install Enano using the web interface,
navigate to http://localhost/enanocms (or http://localhost:8080/enanocms,
depending on how you installed LAMPStack), and use the following settings:

  Database type:       MySQL
  Database hostname:   localhost
  Database name:       $bitnami_db
  Database username:   $bitnami_user
  Database password:   $bitnami_pass


EOF
      break
    fi
  fi
done

echo "Restarting Apache."
$bitnami/ctlscript.sh restart apache

echo
echo -e "Installation finished, \e[31;1mbut be warned! We are aware of a bug with BitNami's"
echo -e "copy of GMP.\e[0m If your server doesn't support SSE2, Enano logins may fail. A"
echo -e "symptom of this problem is messages similar to the following in your Apache"
echo -e "error log and a blank response when you try to log in to your Enano website:"
echo
echo -e "\t[Mon Jul 05 14:22:10 2010] [notice] child pid 26544 exit signal"
echo -e "\tIllegal instruction (4)"
echo
echo -e "If you experience this bug, please report it to BitNami, not the Enano project."
echo

