#!/bin/bash

read -p "Really uninstall Enano including database and config? (type uppercase yes): " confirm
if test "$confirm" != "YES"; then
	echo "Uninstallation aborted."
	exit 1
fi

bitnami=`dirname $0`/../..

while true; do
	read -s -p "MySQL root password: " mysqlpass
	echo ""
	out=`$bitnami/mysql/bin/mysqladmin -u root --password="$mysqlpass" ping 2>&1`
	test "$out" = "mysqld is alive" && break
	echo $out
done

echo "Removing Enano from Apache configuration."
cat $bitnami/apache2/conf/httpd.conf | grep -F -v apps/enanocms/conf/ > $bitnami/apache2/conf/httpd.conf.new || exit 1
mv $bitnami/apache2/conf/httpd.conf $bitnami/apache2/conf/httpd.conf.bak.enanocms-uninstall || exit 1
mv $bitnami/apache2/conf/httpd.conf.new $bitnami/apache2/conf/httpd.conf || exit 1

$bitnami/ctlscript.sh restart apache

echo "Uninstalling database."
echo 'DROP DATABASE bn_enanocms; DROP USER bn_enanocms@localhost;' | $bitnami/mysql/bin/mysql -u root --password="${mysqlpass}" || exit 1

echo "Removing Enano from applications.html."
marker='BitNami Enano CMS Module enanocms'
startline=`cat $bitnami/apache2/htdocs/applications.html | grep -n "START $marker" | cut -d: -f1`
endline=`cat $bitnami/apache2/htdocs/applications.html | grep -n "END $marker" | cut -d: -f1`
nlines=`cat $bitnami/apache2/htdocs/applications.html | wc -l`
# sanity check...
if test "$startline" -gt 0 -a "$endline" -gt 0 -a "$endline" -gt "$startline" -a "$nlines" -gt "$endline" ; then
	cat $bitnami/apache2/htdocs/applications.html | head -n$(($startline - 1)) > $bitnami/apache2/htdocs/applications.html.new
	cat $bitnami/apache2/htdocs/applications.html | tail -n$(($nlines - $endline)) >> $bitnami/apache2/htdocs/applications.html.new
	mv $bitnami/apache2/htdocs/applications.html $bitnami/apache2/htdocs/applications.html.bak.enanocms-uninstall || exit 1
	mv $bitnami/apache2/htdocs/applications.html.new $bitnami/apache2/htdocs/applications.html
fi

echo "Removing app directory."
cd $bitnami || exit 1
rm -rf apps/enanocms/ || exit 1

