#!/bin/bash

set -x

export OS_TOKEN=$ADMIN_TOKEN
export OS_URL=http://openstack:35357/v2.0
KEYSTONE_VERSION=${KEYSTONE_VERSION:-v2.0}

# For Keystone
name=`openstack service list | awk '/ identity / {print $2}'`
if [ -z $name ]; then
   openstack service create --name keystone --description "OpenStack Identity" identity
fi

# Endpoint create for keystone service
endpoint=`openstack endpoint list | awk '/ identity / {print $2}'`
if [ -z "$endpoint" ]; then
   openstack endpoint create \
     --publicurl http://openstack:5000/${KEYSTONE_VERSION} \
     --internalurl http://openstack:5000/${KEYSTONE_VERSION} \
     --adminurl http://openstack:35357/${KEYSTONE_VERSION} \
     --region $REGION_NAME \
     identity
fi

# Create projects, users, and roles
openstack project create --description "Admin Project" admin > /dev/null 2>&1
openstack user create --password $ADMIN_PASS admin > /dev/null 2>&1
openstack role create admin > /dev/null 2>&1
openstack role add --project admin --user admin admin > /dev/null 2>&1

openstack project create --description "Service Project" $ADMIN_TENANT_NAME > /dev/null 2>&1
openstack project create --description "Demo Project" demo > /dev/null 2>&1
openstack user create --password $DEMO_PASS demo > /dev/null 2>&1
openstack role create user > /dev/null 2>&1
openstack role add --project demo --user demo user > /dev/null 2>&1

# Foe Heat Service
openstack role create heat_stack_owner > /dev/null 2>&1
openstack role add --project demo --user demo heat_stack_owner > /dev/null 2>&1
openstack role create heat_stack_user > /dev/null 2>&1

# add to policy.v3.json
if [ ${KEYSTONE_VERSION} = "v3" ]; then
    admin_id=$(openstack user show admin | grep id | awk '{ print $4 }')
    sed -i "s/ADMIN_USER_ID/$admin_id/" /etc/keystone/policy.v3.json
fi


unset OS_TOKEN OS_URL
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_ADMIN_TOKEN=$ADMIN_TOKEN
export OS_AUTH_URL=http://openstack:35357/${KEYSTONE_VERSION}
export OS_AUTH_URL=http://openstack:35357/${KEYSTONE_VERSION}
if [ ${KEYSTONE_VERSION} = "v3" ]; then
    export OS_IDENTITY_API_VERSION=3
fi

echo "export OS_PROJECT_DOMAIN_ID=default" > /openrc
echo "export OS_USER_DOMAIN_ID=default" >> /openrc
echo "export OS_PROJECT_NAME=admin" >> /openrc
echo "export OS_TENANT_NAME=admin" >> /openrc
echo "export OS_USERNAME=admin" >> /openrc
echo "export OS_PASSWORD=$ADMIN_PASS" >> /openrc
echo "export OS_AUTH_URL=http://openstack:35357/${KEYSTONE_VERSION}" >> /openrc
if [ ${KEYSTONE_VERSION} = "v3" ]; then
    echo "export OS_IDENTITY_API_VERSION=3" >> /openrc
fi

# user / role / endpoint create for Glance Service
openstack user create --password $GLANCE_PASS glance > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user glance admin > /dev/null 2>&1
name=`openstack service list | awk '/ image / {print $2}'`
if [ -z $name ]; then
   openstack service create --name glance --description "OpenStack Image service" image
fi

# Endpoint create for glance service
endpoint=`openstack endpoint list | awk '/ image / {print $2}'`
if [ -z "$endpoint" ]; then
    if [ ${KEYSTONE_VERSION} = "v3" ]; then
        openstack endpoint create \
          image \
          public http://openstack:9292 \
          --region $REGION_NAME
        openstack endpoint create \
          image \
          internal http://openstack:9292 \
          --region $REGION_NAME
        openstack endpoint create \
          image \
          admin http://openstack:9292 \
          --region $REGION_NAME
    else
        openstack endpoint create \
          --publicurl http://openstack:9292 \
          --internalurl http://openstack:9292 \
          --adminurl http://openstack:9292 \
          --region $REGION_NAME \
          image
    fi
fi

# user / role / endpoint create for Nova Service
openstack user create --password $NOVA_PASS nova > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user nova admin > /dev/null 2>&1
name=`openstack service list | awk '/ compute / {print $2}'`
if [ -z $name ]; then
   openstack service create --name nova --description "OpenStack Compute" compute
fi

# Endpoint create for nova service
endpoint=`openstack endpoint list | awk '/ compute / {print $2}'`
if [ -z "$endpoint" ]; then
    if [ ${KEYSTONE_VERSION} = "v3" ]; then
        openstack endpoint create \
          compute \
          public http://openstack:8774/v2/%\(tenant_id\)s \
          --region $REGION_NAME
        openstack endpoint create \
          compute \
          internal http://openstack:8774/v2/%\(tenant_id\)s \
          --region $REGION_NAME
        openstack endpoint create \
          compute \
          admin http://openstack:8774/v2/%\(tenant_id\)s \
          --region $REGION_NAME
    else
        openstack endpoint create \
          --publicurl http://openstack:8774/v2/%\(tenant_id\)s \
          --internalurl http://openstack:8774/v2/%\(tenant_id\)s \
          --adminurl http://openstack:8774/v2/%\(tenant_id\)s \
          --region $REGION_NAME \
          compute
    fi
fi

# user / role / endpoint create for Neutron Service
openstack user create --password $NEUTRON_PASS neutron > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user neutron admin > /dev/null 2>&1
name=`openstack service list | awk '/ network / {print $2}'`
if [ -z $name ]; then
   openstack service create --name neutron --description "OpenStack Networking" network
fi

# Endpoint create for neutron service
endpoint=`openstack endpoint list | awk '/ network / {print $2}'`
if [ -z "$endpoint" ]; then
    if [ ${KEYSTONE_VERSION} = "v3" ]; then
        openstack endpoint create \
          network \
          public http://contrail:9696 \
          --region $REGION_NAME
        openstack endpoint create \
          network \
          internal http://contrail:9696 \
          --region $REGION_NAME
        openstack endpoint create \
          network \
          admin http://contrail:9696 \
          --region $REGION_NAME
    else
        openstack endpoint create \
          --publicurl http://contrail:9696 \
          --adminurl http://contrail:9696 \
          --internalurl http://contrail:9696 \
          --region $REGION_NAME \
          network
    fi
fi

# user / role / endpoint create for Heat Service
openstack user create --password $HEAT_PASS heat > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user heat admin > /dev/null 2>&1
name=`openstack service list | awk '/ orchestration / {print $2}'`
if [ -z $name ]; then
   openstack service create --name heat --description "Orchestration" orchestration
fi

name=`openstack service list | awk '/ cloudformation / {print $2}'`
if [ -z $name ]; then
   openstack service create --name heat-cfn --description "Orchestration" cloudformation
fi

# Endpoint create for heat service
endpoint=`openstack endpoint list | awk '/ orchestration / {print $2}'`
if [ -z "$endpoint" ]; then
    if [ ${KEYSTONE_VERSION} = "v3" ]; then
        openstack endpoint create \
          orchestration \
          public http://openstack:8004 \
          --region $REGION_NAME
        openstack endpoint create \
          orchestration \
          internal http://openstack:8004 \
          --region $REGION_NAME
        openstack endpoint create \
          orchestration \
          admin http://openstack:8004 \
          --region $REGION_NAME
    else
        openstack endpoint create \
          --publicurl http://openstack:8004/v1/%\(tenant_id\)s  \
          --internalurl http://openstack:8004/v1/%\(tenant_id\)s \
          --adminurl http://openstack:8004/v1/%\(tenant_id\)s  \
          --region $REGION_NAME \
          orchestration
    fi
fi

endpoint=`openstack endpoint list | awk '/ cloudformation / {print $2}'`
if [ -z "$endpoint" ]; then
    if [ ${KEYSTONE_VERSION} = "v3" ]; then
        openstack endpoint create \
          cloudformation \
          public http://openstack:8000/v1 \
          --region $REGION_NAME
        openstack endpoint create \
          cloudformation \
          internal http://openstack:8000/v1 \
          --region $REGION_NAME
        openstack endpoint create \
          cloudformation \
          admin http://openstack:8000/v1 \
          --region $REGION_NAME
    else
        openstack endpoint create \
          --publicurl http://openstack:8000/v1  \
          --internalurl http://openstack:8000/v1 \
          --adminurl http://openstack:8000/v1  \
          --region $REGION_NAME \
          cloudformation 
    fi
fi


# user / role / endpoint create for Cinder Service
openstack user create --password $CINDER_PASS cinder > /dev/null 2>&1
openstack role add --project $ADMIN_TENANT_NAME --user cinder admin > /dev/null 2>&1
name=`openstack service list | awk '/ volume / {print $2}'`
if [ -z $name ]; then
   openstack service create --name cinder --description "OpenStack Block Storage" volume
fi

name=`openstack service list | awk '/ volumev2 / {print $2}'`
if [ -z $name ]; then
   openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
fi

# Endpoint create for heat service
endpoint=`openstack endpoint list | awk '/ volume / {print $2}'`
if [ -z "$endpoint" ]; then
    if [ ${KEYSTONE_VERSION} = "v3" ]; then
        openstack endpoint create \
          volume \
          public http://openstack:8776/v2/%\(tenant_id\)s \
          --region $REGION_NAME
        openstack endpoint create \
          volume \
          internal http://openstack:8776/v2/%\(tenant_id\)s \
          --region $REGION_NAME
        openstack endpoint create \
          volume \
          admin http://openstack:8776/v2/%\(tenant_id\)s \
          --region $REGION_NAME
    else
        openstack endpoint create \
          --publicurl http://openstack:8776/v2/%\(tenant_id\)s \
          --internalurl http://openstack:8776/v2/%\(tenant_id\)s \
          --adminurl http://openstack:8776/v2/%\(tenant_id\)s \
          --region $REGION_NAME \
          volume
    fi
fi

endpoint=`openstack endpoint list | awk '/ volumev2 / {print $2}'`
if [ -z "$endpoint" ]; then
    if [ ${KEYSTONE_VERSION} = "v3" ]; then
        openstack endpoint create \
          volumev2 \
          public http://openstack:8776/v2/%\(tenant_id\)s \
          --region $REGION_NAME
        openstack endpoint create \
          volumev2 \
          internal http://openstack:8776/v2/%\(tenant_id\)s \
          --region $REGION_NAME
        openstack endpoint create \
          volumev2 \
          admin http://openstack:8776/v2/%\(tenant_id\)s \
          --region $REGION_NAME
    else
        openstack endpoint create \
          --publicurl http://openstack:8776/v2/%\(tenant_id\)s \
          --internalurl http://openstack:8776/v2/%\(tenant_id\)s \
          --adminurl http://openstack:8776/v2/%\(tenant_id\)s \
          --region $REGION_NAME \
          volumev2 
    fi
fi
