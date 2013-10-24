#!/bin/bash

# passwordless sudo
echo "%sudo   ALL=NOPASSWD: ALL" >> /etc/sudoers

# speed up ssh
echo "UseDNS no" >> /etc/ssh/sshd_config

# clean up
apt-get clean

# copy puppet
cp -R /media/cdrom/puppet /home/tdsparrow
cat <<EOF > /home/tdsparrow/config_openstack
ABSPATH=$(cd "$(dirname $0)"; pwd)
sudo -s puppet --modulepath=$ABSPATH/puppet/modules puppet/trial.pp
sudo cp /root/openrc $ABSPATH/
source $ABSPATH/openrc
EOF
chmod u+x /home/tdsparrow/config_openstack

chown -R tdsparrow:tdsparrow /home/tdsparrow
su - tdsparrow -c 'ssh-keygen -q -t rsa -N "" -f /home/tdsparrow/.ssh/id_rsa'

