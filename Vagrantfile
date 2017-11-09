# -*- mode: ruby -*-
# vi: set ft=ruby :

$script = <<SCRIPT
moduloNome="puppet-owncloud"
versaoGuestadditions=5.1.18
echo Provisionando VM
if [ ! -f /etc/${moduloNome}-provisionado ]; then
  #rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
  yum -y update
  yum groupinstall -y "development tools"
  yum install -y epel-release
  yum install -y puppet wget vim kernel-devel
  # mv -f /etc/puppet/modules /etc/puppet/modules.old
  ln -s /vagrant/ /etc/puppet/modules/$moduloNome
  echo "  cd /tmp/" >> /etc/rc.local
  echo "  /usr/bin/wget -q http://download.virtualbox.org/virtualbox/${versaoGuestadditions}/VBoxGuestAdditions_$versaoGuestadditions.iso" >> /etc/rc.local
  echo "  /bin/mount -t iso9660 -o loop /tmp/VBoxGuestAdditions_${versaoGuestadditions}.iso /mnt" >> /etc/rc.local
  echo "  /mnt/VBoxLinuxAdditions.run" >> /etc/rc.local
  echo "  /bin/sed -i \"s/^  .*$//g\" /etc/rc.local" >> /etc/rc.local
  echo "#  /usr/bin/puppet apply /etc/puppet/modules/${moduloNome}/manifests/init.pp" >> /etc/rc.local
  touch /etc/${moduloNome}-provisionado
  echo Reiniciando para conclusão da instalação
  reboot
fi
SCRIPT
# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vm.provision "shell", inline: $script
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.network "private_network", ip: "10.31.8.180"
end
