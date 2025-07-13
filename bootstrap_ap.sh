#!/bin/bash
# Install Java
yum install -y java-11
yum install -y nmap-ncat

# Install Jboss-eap
/usr/bin/aws s3 cp s3://jboss-eap-demo-right-lionfish/jboss-eap-7.4.0.zip /opt/
unzip /opt/jboss-eap-7.4.0.zip
rm -f /opt/jboss-eap-7.4.0.zip

# Install JDBC Driver
/usr/bin/aws s3 cp s3://jboss-eap-demo-right-lionfish/postgresql-42.2.5.jar /opt/jboss-eap-7.4/modules/com/postgresql/main

# Install Postgresql Client
yum install -y postgresql16

# Configure Jboss-eap
mkdir -p /app/standalone
cp -r /opt/jboss-eap-7.4/standalone/configuration \
/opt/jboss-eap-7.4/standalone/deployments \
/opt/jboss-eap-7.4/standalone/lib \
/app/standalone

cat << EOF > /root/configure.cli

EOF

# Start Jboss-eap
/opt/jboss-eap-7.4/bin/standalone.sh -Djboss.server.base.dir=/app/standalone -Djboss.bind.address=0.0.0.0




