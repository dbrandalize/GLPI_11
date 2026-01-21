#!/bin/bash

echo "#########################################################"
echo " Script Revisado: Instalacao GLPI 11 (Arquitetura Segura)"
echo "#########################################################"

# 1. Adicionar repositório para PHP 8.3 (Necessário no Ubuntu 22.04)
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# 2. Instalar pacotes necessários (PHP 8.3 e extensões)
sudo apt install -y \
    nginx \
    mariadb-server \
    mariadb-client \
    php8.3-fpm \
    php8.3-dom \
    php8.3-fileinfo \
    php8.3-json \
    php8.3-simplexml \
    php8.3-xmlreader \
    php8.3-xmlwriter \
    php8.3-curl \
    php8.3-gd \
    php8.3-intl \
    php8.3-mysqli \
    php8.3-bz2 \
    php8.3-zip \
    php8.3-exif \
    php8.3-ldap \
    php8.3-opcache \
    php8.3-mbstring \
    php8.3-bcmath

# 3. Configurar Banco de Dados
sudo mysql -e "CREATE DATABASE IF NOT EXISTS glpi"
sudo mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost' IDENTIFIED BY '1cd73cddc8dad1fef981391f'"
sudo mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'localhost'"
sudo mysql -e "FLUSH PRIVILEGES"

# 4. Carregar Timezones no MariaDB
mysql_tzinfo_to_sql /usr/share/zoneinfo | sudo mysql -u root mysql

# 5. Configurar PHP (Timezone e Segurança)
sudo sed -i 's/^session.cookie_httponly =/session.cookie_httponly = on/' /etc/php/8.3/fpm/php.ini
sudo sed -i 's/^;date.timezone =/date.timezone = America\/Sao_Paulo/' /etc/php/8.3/fpm/php.ini

# 6. Configurar Nginx
cat << "EOF" > /etc/nginx/sites-available/glpi
server {
    listen 80;
    server_name _;
    root /var/www/glpi/public;
    index index.php;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/glpi /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# 7. Download e Extração do GLPI 11.0.4
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/11.0.4/glpi-11.0.4.tgz
tar -zxf glpi-11.0.4.tgz
sudo mv glpi /var/www/glpi

# 8. Criar estrutura de pastas seguras (Fora do Webroot)
sudo mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi
sudo chown -R www-data:www-data /etc/glpi /var/lib/glpi /var/log/glpi /var/www/glpi

# 9. Configurar os ponteiros (downstream.php e local_define.php)
cat << "EOF" > /var/www/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
   require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF

cat << "EOF" > /etc/glpi/local_define.php
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF

# 10. Instalação do Banco de Dados via CLI (Forçando PHP 8.3)
# O uso do --force garante a limpeza se houve tentativa falha anterior.
sudo php8.3 /var/www/glpi/bin/console db:install \
    --default-language=pt_BR \
    --db-host=localhost \
    --db-name=glpi \
    --db-user=glpi \
    --db-password=1cd73cddc8dad1fef981391f \
    --no-interaction --force

# 11. Ajustes Finais de Permissões e Segurança
sudo rm -rf /var/www/glpi/install/
sudo chown -R www-data:www-data /etc/glpi /var/lib/glpi /var/log/glpi /var/www/glpi
sudo find /var/www/glpi/ -type f -exec chmod 0644 {} \;
sudo find /var/www/glpi/ -type d -exec chmod 0755 {} \;

# 12. Reiniciar serviços
sudo systemctl restart nginx php8.3-fpm mysql

echo "#########################################################"
echo " INSTALACAO FINALIZADA COM SUCESSO."
echo " Acessar ao GLPI pelo seu navegador."
echo " Paz & Bem"
echo "#########################################################"
