#!/bin/bash
set -e  # Interrompe o script se houver qualquer erro

echo "#########################################################"
echo " Script Completo: Instalação GLPI 11 (Correção de Erros)"
echo "#########################################################"

# 1. Limpeza de bloqueios do APT (Comum em VMs Azure/Cloud)
sudo rm -f /var/lib/dpkg/lock-frontend
sudo rm -f /var/lib/apt/lists/lock

# 2. Atualização e Repositório PHP 8.3
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# 3. Instalação do Nginx, MariaDB e PHP 8.3
# Inclui a criação manual da pasta /var/www para evitar erros de 'No such file'
sudo mkdir -p /var/www/glpi
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

# 4. Configuração do Banco de Dados
sudo mysql -e "CREATE DATABASE IF NOT EXISTS glpi"
sudo mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost' IDENTIFIED BY '1cd73cddc8dad1fef981391f'"
sudo mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'localhost'"
sudo mysql -e "FLUSH PRIVILEGES"
mysql_tzinfo_to_sql /usr/share/zoneinfo | sudo mysql -u root mysql

# 5. Configuração do PHP 8.3 (Timezone e Segurança)
sudo sed -i 's/^session.cookie_httponly =/session.cookie_httponly = on/' /etc/php/8.3/fpm/php.ini
sudo sed -i 's/^;date.timezone =/date.timezone = America\/Sao_Paulo/' /etc/php/8.3/fpm/php.ini

# 6. Configuração do Servidor Web (Nginx)
cat << "EOF" | sudo tee /etc/nginx/sites-available/glpi
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

# 7. Download e Extração do GLPI 11
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/11.0.4/glpi-11.0.4.tgz
tar -zxf glpi-11.0.4.tgz
sudo mv glpi/* /var/www/glpi/

# 8. Criação da Estrutura de Pastas Seguras
sudo mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi

# 9. Configuração dos "Ponteiros" do GLPI 11
cat << "EOF" | sudo tee /var/www/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
   require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF

cat << "EOF" | sudo tee /etc/glpi/local_define.php
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF

# 10. Permissões Iniciais e Instalação via CLI
# O uso do 'php8.3' explícito resolve o erro de 'command not found'
sudo chown -R www-data:www-data /var/www/glpi /etc/glpi /var/lib/glpi /var/log/glpi
sudo php8.3 /var/www/glpi/bin/console db:install \
    --default-language=pt_BR \
    --db-host=localhost \
    --db-name=glpi \
    --db-user=glpi \
    --db-password=1cd73cddc8dad1fef981391f \
    --no-interaction --force

# 11. Limpeza e Permissões Finais
sudo rm -rf /var/www/glpi/install/
sudo find /var/www/glpi/ -type f -exec chmod 0644 {} \;
sudo find /var/www/glpi/ -type d -exec chmod 0755 {} \;

# 12. Reinício de Serviços
sudo systemctl restart nginx php8.3-fpm mariadb

echo "#########################################################"
echo " INSTALAÇÃO FINALIZADA COM SUCESSO."
echo " Acessar ao GLPI pelo seu navegador."
echo " Paz & Bem ^.^"
echo "#########################################################"
