#!/bin/bash
# Install httpd
yum install -y httpd mod_ssl

# Generate Self-signed Certificate
PATH_TLS=/etc/pki/tls
mkdir -p $PATH_TLS/ca

openssl genpkey -algorithm ec -pkeyopt ec_paramgen_curve:P-256 -out $PATH_TLS/ca/ca.pem

openssl req -key $PATH_TLS/ca/ca.pem \
-new -x509 -days 3650 -addext keyUsage=critical,keyCertSign,cRLSign \
-subj "/CN=my_ca" -out $PATH_TLS/ca/ca.crt 

openssl genpkey -algorithm ec -pkeyopt ec_paramgen_curve:P-256 -out $PATH_TLS/private/server.pem

openssl req -key $PATH_TLS/private/server.pem -new -out $PATH_TLS/server.csr \
-subj '/C=JP/CN=http-server.local'

openssl x509 -req -in $PATH_TLS/server.csr \
-CA $PATH_TLS/ca/ca.crt \
-CAkey $PATH_TLS/ca/ca.pem \
-CAcreateserial -days 3650 \
-out $PATH_TLS/certs/server.crt

chown apache:apache $PATH_TLS/certs/server.crt
chown apache:apache $PATH_TLS/private/server.pem

# Configure httpd
cat << EOF > /etc/httpd/conf/httpd.conf
# Load Module
Include conf.modules.d/*.conf

# Global Settings
ServerRoot "/etc/httpd"
Listen 443
ServerAdmin root@localhost
AddDefaultCharset UTF-8
<Directory />
    AllowOverride none
    Require all denied
</Directory>
<Directory "/var/www">
    AllowOverride None
    Require all granted
</Directory>
<Files ".ht*">
    Require all denied
</Files>
<IfModule mime_module>
    TypesConfig /etc/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz
    AddType text/html .shtml
    AddOutputFilter INCLUDES .shtml
</IfModule>
<IfModule mime_magic_module>
    MIMEMagicFile conf/magic
</IfModule>

# Logging Settings
ErrorLog "logs/error_log"
LogLevel warn
<IfModule log_config_module>
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %b" common
    <IfModule logio_module>
      LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %I %O" combinedio
    </IfModule>
    CustomLog "logs/access_log" combined
</IfModule>

# SSL Settings
ServerName http_server.local
SSLEngine on
SSLProtocol -all +TLSv1.2 +TLSv1.3
SSLCertificateFile "/etc/pki/tls/certs/server.crt"
SSLCertificateKeyFile "/etc/pki/tls/private/server.pem"

# Health Check Settings
<Location /healthz>
    SetHandler default-handler
    Require all granted
</Location>

# Proxy Settings
Define ELB_INTERNAL internal-jboss-eap-demo-alb-internal-850967156.ap-northeast-1.elb.amazonaws.com
ProxyRequests Off
ProxyPass / http://${ELB_INTERNAL}
ProxyPassReverse / http://${ELB_INTERNAL}

# Test Page
#DocumentRoot "/var/www/html"
# <Directory "/var/www/html">
#     Options Indexes FollowSymLinks
#     AllowOverride None
#     Require all granted
# </Directory>
# <IfModule dir_module>
#     DirectoryIndex index.html
# </IfModule>
EOF

# Restart httpd
systemctl restart httpd.service