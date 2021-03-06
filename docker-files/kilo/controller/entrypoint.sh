#!/bin/bash
set -x
env

RABBIT_HOST=${RABBIT_HOST:-localhost}
MYSQL_HOST=${MYSQL_HOST:-localhost}
NOVA_HOST=${NOVA_HOST:-openstack}
GLANCE_HOST=${GLANCE_HOST:-openstack}
KEYSTONE_HOST=${KEYSTONE_HOST:-openstack}
HEAT_HOST=${HEAT_HOST:-openstack}
CFN_HOST=${CFN_HOST:-openstack}
CINDER_HOST=${CINDER_HOST:-openstack}
NEUTRON_HOST=${NEUTRON_HOST:-contrail}

MYIPADDR=$(hostname -i)
# Setup for MySQL
# Remove mysql directory
if [ -d /data/mysql ]; then
    rm -rf /data/mysql
fi

echo 'Running mysql_install_db ...'
mysql_install_db
echo 'Finished mysql_install_db'

tempSqlFile='/tmp/mysql-first-time.sql'
cat > "$tempSqlFile" <<-EOSQL
DELETE FROM mysql.user ;
CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
DROP DATABASE IF EXISTS test ;
EOSQL

# Create User & Database
if [ "$KEYSTONE_DBPASS" ]; then
    echo "CREATE USER 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`keystone\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`keystone\`.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';" >> "$tempSqlFile"
fi
if [ "$GLANCE_DBPASS" ]; then
    echo "CREATE USER 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`glance\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`glance\`.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';" >> "$tempSqlFile"
fi
if [ "$NOVA_DBPASS" ]; then
    echo "CREATE USER 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`nova\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`nova\`.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';" >> "$tempSqlFile"
fi
if [ "$CINDER_DBPASS" ]; then
    echo "CREATE USER 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`cinder\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`cinder\`.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';" >> "$tempSqlFile"
fi
if [ "$HEAT_DBPASS" ]; then
    echo "CREATE USER 'heat'@'%' IDENTIFIED BY '$HEAT_DBPASS' ;" >> "$tempSqlFile"
    echo "CREATE DATABASE IF NOT EXISTS \`heat\` ;" >> "$tempSqlFile"
    echo "GRANT ALL ON \`heat\`.* TO 'heat'@'%' IDENTIFIED BY '$HEAT_DBPASS';" >> "$tempSqlFile"
fi

echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
		
mysqld --init-file="$tempSqlFile" &

# Rabbitmq-server Setup
echo 'Rabbitmq-server Setup....................'
service rabbitmq-server start

# Add User & Change password for Rabbitmq Server
rabbitmqctl add_user openstack $RABBIT_PASS
#while true; do
#    if [ "$RABBIT_PASS" ]; then
#        rabbitmqctl add_user openstack $RABBIT_PASS
#        if [ $? == 0 ]; then break
#        else echo "Waiting for RabbitMQ Server Password change....";sleep 1
#        fi
#    fi
#done
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

# Keystone Setup
echo 'Keystone Setup....................'

sed -i "s/ADMIN_TOKEN/$ADMIN_TOKEN/g" /etc/keystone/keystone.conf
sed -i "s/KEYSTONE_DBPASS/$KEYSTONE_DBPASS/g" /etc/keystone/keystone.conf
sed -i "s/MYSQL_HOST/$MYSQL_HOST/g" /etc/keystone/keystone.conf
sed -i "s#POLICY_FILE#$POLICY_FILE#g" /etc/keystone/keystone.conf

# excution for keystone Service
su -s /bin/sh -c "keystone-manage db_sync" keystone

# Dashboard Service
# Timezone Setup for Horizone Service
if [ "$TIME_ZONE" ]; then
    sed -i "s|^TIME_ZONE.*|TIME_ZONE = \"$TIME_ZONE\"|" /etc/openstack-dashboard/local_settings.py
fi

# Start the Apache HTTP Server
service apache2 start
service memcached start

# Creation of Tenant & User & Role
echo 'Creation of Tenant / User / Role ..............'
/keystone.sh

# GLANCE SETUP
echo 'Glance Setup..................'
GLANCE_API=/etc/glance/glance-api.conf
GLANCE_REGISTRY=/etc/glance/glance-registry.conf

sed -i "s/RABBIT_HOST/$RABBIT_HOST/g" $GLANCE_API
sed -i "s/MYSQL_HOST/$MYSQL_HOST/g" $GLANCE_API
sed -i "s/KEYSTONE_HOST/$KEYSTONE_HOST/g" $GLANCE_API
sed -i "s/GLANCE_DBPASS/$GLANCE_DBPASS/g" $GLANCE_API
sed -i "s/GLANCE_PASS/$GLANCE_PASS/g" $GLANCE_API
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $GLANCE_API

sed -i "s/RABBIT_HOST/$RABBIT_HOST/g" $GLANCE_REGISTRY
sed -i "s/MYSQL_HOST/$MYSQL_HOST/g" $GLANCE_REGISTRY
sed -i "s/KEYSTONE_HOST/$KEYSTONE_HOST/g" $GLANCE_REGISTRY
sed -i "s/GLANCE_DBPASS/$GLANCE_DBPASS/g" $GLANCE_REGISTRY
sed -i "s/GLANCE_DBPASS/$GLANCE_DBPASS/g" $GLANCE_REGISTRY
sed -i "s/GLANCE_PASS/$GLANCE_PASS/g" $GLANCE_REGISTRY
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $GLANCE_REGISTRY

### glance image directory / files owner:group change
chown -R glance:glance /var/lib/glance

# excution for glance service
su -s /bin/sh -c "glance-manage db_sync" glance
su -s /bin/sh -c "glance-registry &" glance
su -s /bin/sh -c "glance-api &" glance

## Nova Setup
echo 'Nova Setup.......................'
NOVA_CONF=/etc/nova/nova.conf

sed -i "s/NOVA_DBPASS/$NOVA_DBPASS/g" $NOVA_CONF
sed -i "s/NOVA_PASS/$NOVA_PASS/g" $NOVA_CONF
sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $NOVA_CONF
sed -i "s/RABBIT_HOST/$RABBIT_HOST/g" $NOVA_CONF
sed -i "s/MYSQL_HOST/$MYSQL_HOST/g" $NOVA_CONF
sed -i "s/KEYSTONE_HOST/$KEYSTONE_HOST/g" $NOVA_CONF
sed -i "s/MYIPADDR/${MYIPADDR}/g" $NOVA_CONF
sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $NOVA_CONF
sed -i "s/NEUTRON_PASS/$NEUTRON_PASS/g" $NOVA_CONF

# Nova service start
su -s /bin/sh -c "nova-manage db sync" nova

su -s /bin/sh -c "nova-api --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-cert --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-consoleauth --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-scheduler --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-conductor --config-file=$NOVA_CONF &" nova
su -s /bin/sh -c "nova-novncproxy --config-file=$NOVA_CONF &" nova

while true; do
    sleep 10
done
### Heat
#echo 'Heat Setup.........................'
#HEAT_CONF=/etc/heat/heat.conf
#sed -i "s/HEAT_DOMAIN_PASS/$HEAT_DOMAIN_PASS/g" $HEAT_CONF
#sed -i "s/HEAT_DBPASS/$HEAT_DBPASS/g" $HEAT_CONF
#sed -i "s/HEAT_PASS/$HEAT_PASS/g" $HEAT_CONF
#sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $HEAT_CONF
#sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $HEAT_CONF
#
#su -s /bin/sh -c "heat-manage db_sync" heat
#service heat-api start
#service heat-api-cfn start
#service heat-engine start
#
### Cinder
#echo 'Cinder Setup.........................'
#CINDER_CONF=/etc/cinder/cinder.conf
#sed -i "s/CINDER_PASS/$CINDER_PASS/g" $CINDER_CONF
#sed -i "s/CINDER_DBPASS/$CINDER_DBPASS/g" $CINDER_CONF
#sed -i "s/RABBIT_PASS/$RABBIT_PASS/g" $CINDER_CONF
#sed -i "s/MYIPADDR/$MYIPADDR/g" $CINDER_CONF
#sed -i "s/ADMIN_TENANT_NAME/$ADMIN_TENANT_NAME/g" $CINDER_CONF
#
#su -s /bin/sh -c "cinder-manage db sync" cinder
#service cinder-scheduler start 
#service cinder-api start
