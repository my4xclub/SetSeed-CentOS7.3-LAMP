#!/bin/bash
clear

# Parse command line options.

sudo read -p "Enter server admin email (e.g. admin@example.com) : " email
sudo read -p "Enter servername (e.g. example.com) : " servname
sudo read -p "Enter server alias (e.g. www.example.com) : " alias
sudo read -p "Enter docroot (e.g. setseed) : " docroot
sudo read -p "Enter time zone (e.g. America/New_York) : " time

sudo setenforce 0 >> /dev/null 2>&1
LOG=/root/installation.log

			
echo "************************************************************"
echo " Welcome SetSeed on CentOS 7.3 Installer"
echo "*************************************************************"

#-------------------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------   INSTALLATION  -----------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------------------
echo 'Installing additional Repos'
echo "-----------------------------------------------------------"
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm >> $LOG 2>&1
sudo yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm >> $LOG 2>&1
sudo yum install -y yum-utils >> $LOG 2>&1
sudo yum-config-manager --enable remi-php56 -y >> $LOG 2>&1
cat >>/etc/yum.repos.d/MariaDB.repo<<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.2.3/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
echo 'Installing HTTPD and MariaDB Client'
echo "-----------------------------------------------------------"
# Install web server 
sudo yum -y update >> $LOG 2>&1
sudo yum install -y httpd >> $LOG 2>&1
sudo yum install -y MariaDB-client >> $LOG 2>&1
echo 'Installing additional utilities'
echo "-----------------------------------------------------------"
sudo yum install -y wget >> $LOG 2>&1
sudo yum install -y net-tools >> $LOG 2>&1
sudo yum install -y links >> $LOG 2>&1
sudo yum install -y mod_ssl >> $LOG 2>&1
echo 'Installing PHP 5.6.xs'
echo "-----------------------------------------------------------"
echo
# Install PHP 5.6.x
yum install -y php php-opcache php-common php-fpm php-gd php-mbstring php-mcrypt php-mysql php-pear php-pecl-imagick php-pecl-memcache php-snmp >> $LOG 2>&1
echo 'Creating needed directories and bak files'
echo "-----------------------------------------------------------"
# Create additional dir
sudo mkdir -p /var/www/logs >> $LOG 2>&1
sudo mkdir -p /var/www/$docroot/public_html >> $LOG 2>&1
sudo mkdir -p /var/logs/php >> $LOG 2>&1
sudo mkdir -p /etc/httpd/sites-available >> $LOG 2>&1
sudo mkdir -p /etc/httpd/sites-enabled >> $LOG 2>&1
sudo chown apache /var/logs/php >> $LOG 2>&1
cp /etc/httpd/conf/httpd.conf ~/httpd.conf.backup >> $LOG 2>&1

echo "Creating HTTPD config files"
echo "-----------------------------------------------------------"
cat >>/etc/httpd/sites-enabled/$servname.conf<<EOF
NameVirtualHost *:80
<VirtualHost *:80>
    ServerAdmin $email
	DocumentRoot "/var/www/$docroot/public_html/"
    ServerName $servname
    ServerAlias $alias
	ErrorLog /var/www/logs/error.log
    CustomLog /var/www/logs/access.log combined
	
	<Directory "/var/www/$docroot/public_html/">
    DirectoryIndex index.php
	Options FollowSymLinks
	Require all granted
	AllowOverride All
    </Directory>
</VirtualHost>
EOF
echo "Creating Virtual Host symbolic links."
echo "-----------------------------------------------------------"
# Reorganizing Virtual Host files
sudo mv /etc/httpd/sites-enabled/$servname.conf /etc/httpd/sites-available/$servname.conf >> $LOG 2>&1
sudo ln -s /etc/httpd/sites-available/$servname.conf /etc/httpd/sites-enabled/$servname.conf >> $LOG 2>&1

echo "Modifying httpd.conf to enable site"
echo ""
echo "IncludeOptional sites-enabled/*.conf" >> /etc/httpd/conf/httpd.conf

echo "Modifying config files"
echo 
# Edit php.ini and httpd.conf files
sed -i 's/error_reporting =.*/error_reporting = E_COMPILE_ERROR|E_RECOVERABLE_ERROR|E_ERROR|E_CORE_ERROR/' /etc/php.ini
echo "error_log = /var/logs/php/error.log/" >> /etc/php.ini
sed -i 's/max_input_time = 60.*/max_input_time = 30/g' /etc/php.ini

echo "Installing IonCube Loader"
echo "-----------------------------------------------------------"
# Install Ioncube loader	
cd /tmp
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz >> $LOG 2>&1
tar xfz ioncube_loaders_lin_x86-64.tar.gz >> $LOG 2>&1
cp ioncube/ioncube_loader_lin_5.6.so /usr/lib64/php/modules >> $LOG 2>&1
sed -i '3i zend_extension = /usr/lib64/php/modules/ioncube_loader_lin_5.6.so' /etc/php.ini

echo "Starting services"
echo
# Bring up server services
sudo systemctl enable httpd.service >> $LOG 2>&1
service httpd restart >> $LOG 2>&1
service php-fpm restart >> $LOG 2>&1
echo "Installing certbot"
echo 
# Install certbot for SSL
sudo yum install -y python-certbot-apache >> $LOG 2>&1
certbot certonly --email $email --webroot -w /var/www/$docroot/public_html -d $servname -d $alias
echo "Setting Certbot to autorenew"
echo 
# Setup autorenew
sudo certbot renew >> $LOG 2>&1
echo "30 2 * * 1 /usr/bin/certbot renew" >> $LOG 2>&1

echo "Enabling SSL on Host file"
echo ""
# Redo Vhost File
rm /etc/httpd/sites-enabled/$servname.conf >> $LOG 2>&1
cat >>/etc/httpd/sites-enabled/$servname.conf<<EOF
NameVirtualHost *:80
<VirtualHost *:80>
    ServerAdmin $email
	DocumentRoot "/var/www/$docroot/public_html/"
    ServerName $servname
    ServerAlias $alias
	ErrorLog /var/www/logs/error.log
    CustomLog /var/www/logs/access.log combined
	
	<Directory "/var/www/$docroot/public_html/">
    DirectoryIndex index.php
	Options FollowSymLinks
	Require all granted
	AllowOverride All
    </Directory>
</VirtualHost>
NameVirtualHost *:443
<VirtualHost *:443>
 ServerAdmin $email
	DocumentRoot "/var/www/$docroot/public_html/"
    ServerName $servname
    ServerAlias $alias
	ErrorLog /var/www/logs/error.log
    CustomLog /var/www/logs/access.log combined
	
	<Directory "/var/www/$docroot/public_html/">
    DirectoryIndex index.php
	Options FollowSymLinks
	Require all granted
	AllowOverride All
    </Directory>
SSLEngine on
SSLCertificateFile    /etc/letsencrypt/live/$servname/cert.pem
SSLCertificateKeyFile /etc/letsencrypt/live/$servname/privkey.pem
SSLCertificateChainFile /etc/letsencrypt/live/$servname/fullchain.pem

# HSTS (mod_headers is required) (15768000 seconds = 6 months)
    Header always set Strict-Transport-Security "max-age=15768000"
</VirtualHost>

# intermediate configuration, tweak to your needs
SSLProtocol             all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite          ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256
SSLHonorCipherOrder     on
EOF

echo "ReCreating Virtual Host symbolic links."
echo ""
# Reorganizing Virtual Host files
sudo mv /etc/httpd/sites-enabled/$servname.conf /etc/httpd/sites-available/$servname.conf >> $LOG 2>&1
sudo ln -s /etc/httpd/sites-available/$servname.conf /etc/httpd/sites-enabled/$servname.conf >> $LOG 2>&1

echo "Securing Centos 7.3"
echo ""
# Secure the OS

echo "Turning on firewall and setting up services"
echo ""

sudo systemctl start firewalld >> $LOG 2>&1
sudo firewall-cmd --permanent --add-service=ssh >> $LOG 2>&1
sudo firewall-cmd --permanent --add-service=http >> $LOG 2>&1
sudo firewall-cmd --permanent --add-service=https >> $LOG 2>&1
sudo firewall-cmd --permanent --add-service=smtp >> $LOG 2>&1
sudo firewall-cmd --reload >> $LOG 2>&1
sudo systemctl enable firewalld >> $LOG 2>&1

echo "Configuring Timezones and Synch"
echo ""

sudo timedatectl set-timezone $time >> $LOG 2>&1
sudo yum -y install ntp >> $LOG 2>&1
sudo systemctl start ntpd >> $LOG 2>&1
sudo systemctl enable ntpd >> $LOG 2>&1

echo "Disable root password"
echo ""
sed -i 's/PasswordAuthentication yes.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
systemctl reload sshd >> $LOG 2>&1
sudo chmod 600 /boot/grub2/grub.cfg >> $LOG 2>&1

echo "Sysctl Security"
echo ""
rm /etc/sysctl.conf >> $LOG 2>&1
cat >>/etc/sysctl.conf<<EOF
# System default settings live in /usr/lib/sysctl.d/00-system.conf.
# To override those settings, enter new settings here, or in an /etc/sysctl.d/<name>.conf file
#
# For more information, see sysctl.conf(5) and sysctl.d(5).
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_max_syn_backlog = 1280
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_timestamps = 0
EOF
echo "Disable Uncommon Protocols"
echo ""
echo "install dccp /bin/false" > /etc/modprobe.d/dccp.conf
echo "install sctp /bin/false" > /etc/modprobe.d/sctp.conf
echo "install rds /bin/false" > /etc/modprobe.d/rds.conf
echo "install tipc /bin/false" > /etc/modprobe.d/tipc.conf

echo "Prevent log in with empty passwords"
echo ""
sed -i 's/\<nullok\>//g' /etc/pam.d/system-auth

service httpd restart >> $LOG 2>&1
service php-fpm restart >> $LOG 2>&1

echo "Installing SetSeed"
echo ""
cd /tmp >> $LOG 2>&1
curl -J -O http://162.243.82.181/owncloud/index.php/s/zBDZDyoeLSOIXcO/download >> $LOG 2>&1
tar -zxvf SetSeed-Latest.tgz -C /var/www/html/$docroot/ --strip-components=1 >> $LOG 2>&1
chmod 777 /var/www/html/$docroot/admin/css/css_archives
chmod 777 /var/www/html/$docroot/admin/javascripts/jplayertheme
chmod 777 /var/www/html/$docroot/admin/javascripts/js_archives
chmod 777 /var/www/html/$docroot/admin/javascripts/js_archives2
chmod 777 /var/www/html/$docroot/app/cache
chmod 777 /var/www/html/$docroot/app/configuration.php
chmod 777 /var/www/html/$docroot/install
chmod 777 /var/www/html/$docroot/sites
