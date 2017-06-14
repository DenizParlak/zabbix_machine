#!/bin/bash

gr='\033[1;32m'
re='\033[0;31m'
xx='\033[0m'

echo -en '\n'

echo  "+-+-+-+-+-+-+-+-+-+-+-+-+-+"
echo  "|Z|a|b|b|i|x|M|a|c|h|i|n|e|"
echo  "+-+-+-+-+-+-+-+-+-+-+-+-+-+"
echo -en '\n'
echo denizparlak@papilon.com.tr
echo -en '\n'

echo "###########################"

echo -en '\n'
echo -n "Apache sunucusu kuruluyor.."

yum -y install httpd > /dev/null

echo -e "${gr}OK${xx}"

echo -n "Apache sunucusu başlatılıyor.."

systemctl start httpd
systemctl enable httpd

echo -e "${gr}OK${xx}"

echo -n "Apache için firewall kuralı oluşturuluyor.."
firewall-cmd --permanent --add-service=http 2> /dev/null
systemctl restart firewalld &> /dev/null

echo -e "${gr}OK${xx}"

echo -en '\n'

##

echo -n "MariaDB kuruluyor.."

yum -y install mariadb mariadb-server > /dev/null

echo -e "${gr}OK${xx}"

echo -n "MariaDB başlatılıyor.."

systemctl start mariadb
systemctl enable mariadb &> /dev/null

echo -e "${gr}OK${xx}"

echo -n "MariaDB için root parolası giriniz: "
read -s mypass
echo -en '\n'
echo -en '\n'
#mysqladmin -u root -p password $mypass

echo -n "IUS reposu kuruluyor.."
wget -q https://dl.iuscommunity.org/pub/ius/stable/CentOS/7/x86_64//ius-release-1.0-15.ius.centos7.noarch.rpm
echo -e "${gr}OK${xx}"

yum clean all &> /dev/null

echo -n "EPEL reposu kuruluyor.."
wget -q http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm

echo -e "${gr}OK${xx}"

rpm -U *release*.rpm &> /dev/null

rm -f ius-release-1.0-15.ius.centos7.noarch.rpm
rm -f epel-release-7-9.noarch.rpm

echo -en '\n'

###

echo -n "PHP kuruluyor.."

yum install -y mod_php56u php56u-cli php56u-mysqlnd &> /dev/null
yum install -y php56u-bcmath php56u-mbstring &> /dev/null

cat << EOT >> /var/www/html/test.php
<?php
phpinfo();
?>
EOT

systemctl restart httpd
if  curl -v --silent localhost/test.php 2>&1 | grep "license@" >> /dev/null
then
echo -e "${gr}OK${xx}"
else
echo -e "${re}ERROR${xx}"
fi

echo -en '\n'

###


rpm --import http://repo.zabbix.com/RPM-GPG-KEY-ZABBIX
rpm -U  http://repo.zabbix.com/zabbix/2.4/rhel/7/x86_64/zabbix-release-2.4-1.el7.noarch.rpm

yum -y install zabbix-server-mysql zabbix-web-mysql zabbix-agent zabbix-java-gateway > /dev/null

date=$(timedatectl | grep Time | awk -F ':' '{print $2}' | awk -F ' ' '{print $1}')
echo -e -n "Yerel saat dilimi: $date"
echo -en '\n'
echo -e -n "Bu ayar kullanılsın mı? e/h "
read vv

if [ $vv = "e" ]
then
cat << EOT >> /etc/httpd/conf.d/zabbix.conf
php_value date.timezone $date
EOT
else
echo -n "Yerel saat dilimini giriniz, e.g.  Europe/Istanbul: "
echo -en '\n'
read tm1

cat << EOT >> /etc/httpd/conf.d/zabbix.conf
php_value date.timezone $tm1
EOT
fi

echo -e "${gr}OK${xx}"

echo -n "Apache sunucusu yeniden başlatılıyor.."

systemctl restart httpd

echo -e "${gr}OK${xx}"

echo -en '\n'

echo -n "Zabbix için gerekli MariaDB ayarları yapılıyor.."
echo -en '\n'
echo -en '\n'
echo "Zabbix veritabanı adını giriniz: "
read dbname
echo "Zabbix veritabanı kullanıcısı adını giriniz: "
read dbuser
echo "Zabbix veritabanı kullanıcısı parolasını giriniz: "
read -s dbpass
mysql -u root -p << EOF
create database $dbname character set utf8;
grant all privileges on $dbname.* to '$dbuser'@'localhost' identified by '$dbpass';
flush privileges;
EOF

echo -e "${gr}OK${xx}"

echo -n "Zabbix veritabanı şemaları oluşturuluyor.."
echo -en '\n'
mysql -u $dbuser -p $dbname < /usr/share/doc/zabbix-server-mysql-2.4.8/create/schema.sql
mysql -u $dbuser -p $dbname < /usr/share/doc/zabbix-server-mysql-2.4.8/create/images.sql
mysql -u $dbuser -p $dbname < /usr/share/doc/zabbix-server-mysql-2.4.8/create/data.sql

echo -e "${gr}OK${xx}"


echo -en '\n'
echo -n "Zabbix sunucu ayarları yapılıyor.."

sed -i "s/DBName=zabbix/DBName=$dbname/g" /etc/zabbix/zabbix_server.conf
sed -i "s/DBUser=zabbix/DBName=$dbuser/g" /etc/zabbix/zabbix_server.conf
echo DBPassword=$dbpass >> /etc/zabbix/zabbix_server.conf

echo -e "${gr}OK${xx}"

echo -en '\n'
echo -n "Zabbix Agent ayarları yapılıyor.."
sed -i "s/Hostname=Zabbix server/Hostname=zabbixserver/g" /etc/zabbix/zabbix_agentd.conf

echo -e "${gr}OK${xx}"
echo -en '\n'
echo -n "Güvenlik kuralları ekleniyor.."
echo -en '\n'
firewall-cmd --permanent --add-port=10050/tcp 2> /dev/null
firewall-cmd --permanent --add-port=10051/tcp 2> /dev/null
systemctl restart firewalld &> /dev/null
echo -e "${gr}OK${xx}"

echo -n "SELinux kuralı ekleniyor.."
setsebool -P httpd_can_connect_zabbix=1
echo -e "${gr}OK${xx}"

echo -en '\n'

systemctl start zabbix-server
systemctl start zabbix-agent
systemctl restart httpd
systemctl restart mariadb
systemctl enable zabbix-server &> /dev/null
systemctl enable zabbix-agent &> /dev/null
