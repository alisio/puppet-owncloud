# This is a manifest for building Owncloud development VM environments in CentOS 7
# Este manifesto é utilizado para criar ambientes de desenvolvimento para Owncloud
#
# Author - Autor
# -------
#
# Antonio Alisio de Menses Cordeiro <alisio.meneses@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# References:
# https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-owncloud-on-centos-7
# https://www.digitalocean.com/community/tutorials/how-to-create-an-ssl-certificate-on-apache-for-centos-7
# https://doc.owncloud.org/server/8.1/admin_manual/configuration_server/caching_configuration.html

# Variables - Variáveis
# $certdir          = caminho onde será criado o certificado ssl auto assinado
# $keydir           = caminho onde será criado o certificado ssl auto assinado
# $wwwroot          = caminho dos arquivos www do owncloud
# $fullyq           = fully qualified domain name do seu servidor (trocar pelo IP do seu servidor caso nao tiver fqdn)
# $pacotes          = pacotes necessários para instalação/administração do servidor
# $servicos         = serviços a serem ativados
# $senhaRootDb      =  senha de usuario root do banco de dados RECOMENDO ALTERAR
# $senhaOwncloudDb  = senha de usuario owncloud do banco de dados RECOMENDO ALTERAR
# $nomeModulo       = nome deste modulo
# $versaoCentos     = versao do sistema operacional (somente CentOS7 nesta versao do modulo)

# ----------
$certdir          = '/etc/ssl/certs'
$keydir           = '/etc/ssl/private'
# Para instalar certificado auto assinado, definir certTipo como autoAss
$certTipo         = 'letsencrypt'
$wwwroot          = '/var/www/html/owncloud'
$fullyq           = $fqdn
$pacotes          = ['certbot-apache','httpd','git','mariadb-server','mariadb',
                     'mlocate','mod_ssl','ngrep','owncloud-files',
                     'php56','php56-php','php56-php-gd','php56-php-mbstring',
                     'php56-php-mysqlnd','php56-php-pecl-apcu','vim-enhanced','wget']
$servicos         = ['httpd','mariadb']
$senhaRootDb      = 'senhaDeRootdoBancoDeDados'
$senhaOwncloudDb  = 'senhadoUsuarioOwncloudnoBancoDeDados'
$nomeModulo       = 'puppet-owncloud'
$versaoCentos     = $operatingsystemmajrelease



# TODO: set firewall
# TODO: set memcached

class owncloud {
  exec { 'repositorio-owncloud':
    command => "rpm --import https://download.owncloud.org/download/repositories/stable/CentOS_${versaoCentos}/repodata/repomd.xml.key; curl -L https://download.owncloud.org/download/repositories/stable/CentOS_${versaoCentos}/ce:stable.repo -o /etc/yum.repos.d/ownCloud.repo",
    unless => 'rpm -qa | egrep "^owncloud"',
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
  }
  exec { 'repositorio-remi':
    command => "cd /tmp/; wget https://rpms.remirepo.net/enterprise/remi-release-${versaoCentos}.rpm;rpm -ivh remi-release-${versaoCentos}.rpm",
    unless => 'rpm -qa | egrep "^remi-release"',
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
  }
  package { $pacotes :
    ensure => installed,
    require   => Exec['repositorio-owncloud'],
    notify => Exec['updatedb'],
    allow_virtual => true,
  }
  exec { 'updatedb':
    command => 'updatedb',
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    refreshonly => true,
  }
  file { '/etc/timezone':
    ensure => link,
    target   => '/usr/share/zoneinfo/America/Fortaleza',
  }
  file { '/var/tmp/config-mariadb-owncloud.conf':
    ensure    => present,
    replace   => true,
    content   => template("${nomeModulo}/var/tmp/config-mariadb-owncloud.conf.erb"),
    mode      => '0644',
    owner     => 'root',
    group     => 'root',
  }
  file { '/var/tmp/config-mariadb.conf':
    ensure    => present,
    replace   => true,
    content   => template("${nomeModulo}/var/tmp/config-mariadb.conf.erb"),
    mode      => '0644',
    owner     => 'root',
    group     => 'root',
  }
  exec { 'criar link simbolico para php':
    command => 'ln -s /usr/bin/php56 /usr/bin/php',
    onlyif  =>  'test -f /usr/bin/php56 && test ! -f /usr/bin/php',
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
  }
}

# == Class: configuraServicos
#
class configuraServicos {
  service { $servicos:
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus  => true,
    # pattern => 'httpd',
  }
  exec { 'chown-apache':
    command => 'chown apache: /var/www/html/* -R',
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    # refreshonly => true,
    logoutput => false,
  }
  exec { 'owncloud-db-config':
    command   => "/usr/bin/mysql -uroot < /var/tmp/config-mariadb-owncloud.conf;/bin/rm -f /var/tmp/config-mariadb-owncloud.conf ",
    onlyif    =>  '/usr/bin/mysqlshow',
    require   => Service[$servicos],
  }
  exec { 'mariadb-config':
    command   => "/usr/bin/mysql_secure_installation < /var/tmp/config-mariadb.conf;/bin/rm -f /var/tmp/config-mariadb.conf ",
    onlyif    =>  '/usr/bin/mysqlshow',
    require   => Exec['owncloud-db-config'],
  }
  # exec { 'seta-memcache':
  #   command => "sed -i \"s/^);/  'memcache.local' => '\\OC\\Memcache\\APCu',\n);/g\" /var/www/html/owncloud/config/config.php",
  #   unless => "egrep -q \"'memcache.local' => '\\OC\\Memcache\\APCu',\" /var/www/html/owncloud/config/config.php",
  #   path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
  # }
}
# == Class: seguranca
#
class seguranca {
  if "$selinux" == "true" {
    exec { 'selinux-disable':
      onlyif  =>  '/sbin/selinuxenabled',
      command => '/bin/sed -i s/SELINUX=.*/SELINUX=disabled/g /etc/selinux/config;reboot',
      notify  => Notify['reboot'],
    }
    notify { reboot:
      message   => 'Necessario reiniciar servidor para aplicacao de configuracao SELINUX',
    }
  }
}
# == Class: certificadoSSL
#
class certificadoSSL {
  file { $keydir:
    ensure => directory,
    mode => '0700',
  }
  exec {'criar_self_signed_sslcert':
    command => "openssl req -newkey rsa:2048 -nodes -keyout ${keydir}/${$fullyq}.key  -x509 -days 3600 -out ${certdir}/${$fullyq}.crt -subj '/CN=${$fullyq}'",
    cwd     => $keydir,
    creates => [ "${keydir}/${$fullyq}.key", "${certdir}/${$fullyq}.crt", ],
    path    => ["/usr/bin", "/usr/sbin"],
    require   => File[$keydir],
    notify  => Exec['Diffie-Hellman'],
  }
  exec { 'Diffie-Hellman':
    command   => "openssl dhparam -out ${certdir}/dhparam.pem 2048",
    creates   => "${certdir}/dhparam.pem",
    path      => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    notify    => Exec['append-diffie-hellman'],
    refreshonly => true,
  }
  exec { 'append-diffie-hellman':
    command => "cat ${certdir}/dhparam.pem | sudo tee -a ${certdir}/${$fullyq}.crt",
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    refreshonly => true,
  }
  file { '/etc/httpd/conf.d/non-ssl.conf':
    ensure => file,
    content   => template("${nomeModulo}/etc/httpd/conf.d/non-ssl.conf.erb"),
    mode => '0644',
    notify => Service['httpd'],
  }
  file { '/etc/httpd/conf.d/ssl.conf':
    ensure => file,
    content   => template("${nomeModulo}/etc/httpd/conf.d/ssl.conf.erb"),
    mode => '0644',
    notify => Service['httpd'],
  }
  service { 'httpd':
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus  => true,
    # pattern => 'httpd',
  }
}
# == Class: owncloudManutencao
#
class owncloudManutencao {
  cron { 'lixoApagar':
    command => 'sudo -u apache /var/www/html/owncloud/occ trashbin:cleanup',
    user => 'root',
    hour => 0,
    minute  => 0,
    weekday => 0,
  }
  cron { 'background_jobs':
    command => 'sudo -u apache php -f /var/www/html/owncloud/cron.php',
    user => 'root',
    hour => '*',
    minute  => '*/15',
    weekday => '*',
  }
}

# == Class: letsencrypt
#
class letsencrypt {
  cron { 'renovarCertLetsEncrypt':
    command => '/usr/bin/certbot renew',
    user => 'root',
    hour => 1,
    minute  => 0,
    month => '*',
    monthday => '*',
    weekday => '*',
  }
}

if "$certTipo" == "autoAss" {
  include owncloud
  include configuraServicos
  include seguranca
  include certificadoSSL
  include owncloudManutencao
  Class['owncloud'] -> Class['certificadoSSL'] -> Class['configuraServicos'] -> Class['seguranca'] -> Class['owncloudManutencao']
} elsif "$certTipo" == "letsencrypt" {
    include letsencrypt
    include owncloud
    include configuraServicos
    include seguranca
    include owncloudManutencao
    Class['owncloud'] -> Class['letsencrypt'] -> Class['configuraServicos'] -> Class['seguranca'] -> Class['owncloudManutencao']
} else {
  # TODO:
  include owncloud
  include configuraServicos
  include seguranca
  include owncloudManutencao
  Class['owncloud'] -> Class['configuraServicos'] -> Class['seguranca'] -> Class['owncloudManutencao']
}
