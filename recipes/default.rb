#
# Cookbook Name:: nagios
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

isnagios = true

if File.exist?('/etc/init.d/nagios')
  isnagios = false
end
iscloud = true

if File.exist?("#{node['cloudwatch']['config']}")
  iscloud = false
end

bash 'extarcting files' do
#  command <<-EOF
	code <<-EOH
      set -e
      sudo apt-get update
      sudo apt-get install -y wget build-essential apache2 php5 openssl perl make php5-gd wget libgd2-xpm-dev libapache2-mod-php5 libperl-dev libssl-dev daemon libgd2-xpm-dev openssl libssl-dev xinetd apache2-utils unzip libmysqlclient-dev libcgi-pm-perl librrds-perl libgd-gd2-perl
      sudo useradd nagios
      sudo groupadd nagcmd
      curl -L -O https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.1.1.tar.gz
      tar zxvf nagios-4.1.1.tar.gz
      cd nagios-4.1.1
      ./configure --with-nagios-group=nagios --with-command-group=nagcmd
      make all
      sudo make install
      sudo make install-commandmode
      sudo make install-init
      sudo make install-config
      sudo /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf
      sudo usermod -G nagcmd www-data
      curl -L -O http://nagios-plugins.org/download/nagios-plugins-2.1.1.tar.gz
      tar -zxvf nagios-plugins-2.1.1.tar.gz
      cd nagios-plugins-2.1.1
      ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl
      make
      sudo make install
      curl -L -O http://downloads.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz
      tar -zxvf nrpe-2.15.tar.gz
      cd nrpe-2.15
      ./configure --enable-command-args --with-nagios-user=nagios --with-nagios-group=nagios --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu
      make all
      sudo make install
      sudo make install-xinetd
      sudo make install-daemon-config
      sudo mkdir /usr/local/nagios/etc/servers
      sudo a2enmod rewrite
      sudo a2enmod cgi
      sudo mkdir /opt/cloudwatch
	EOH
  only_if { isnagios == true }
end

execute 'setup for cloudwatch' do
  command <<-EOF
  sudo apt-get update
  cd ~ && curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
  sudo python get-pip.py
  sudo pip install awscli
  sudo apt-get install -y rubygems1.9.1 irb1.9.1 ri1.9.1 rdoc1.9.1 build-essential libopenssl-ruby1.9.1 libssl-dev zlib1g-dev ruby-dev libxslt-dev libxml2-dev
  sudo gem install aws-sdk -v 1.15
  sudo update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 400 --slave /usr/share/man/man1/ruby.1.gz ruby.1.gz /usr/share/man/man1/ruby1.9.1.1.gz --slave /usr/bin/ri ri /usr/bin/ri1.9.1 --slave /usr/bin/irb irb /usr/bin/irb1.9.1 --slave /usr/bin/rdoc rdoc /usr/bin/rdoc1.9.1
  EOF
  only_if { iscloud == true }
end

directory node['nagios']['path'] do
  owner node['nagios']['user']
  group node['nagios']['group']
  recursive true
  mode "0755"
end

service "apache2" do
  supports :status => true, :reload => true, :restart => true
  action [:enable, :restart]
end

execute 'set password' do
  command <<-EOF
  nagios_password=$(date +%s | sha256sum | base64 | head -c 15 ; echo)
  echo $nagios_password > '/opt/.nagios_password'
  EOF
  only_if { isnagios == true }
end

execute 'Websetup nagios' do
	command <<-EOF
      set -e
      sudo ln -s /etc/apache2/sites-available/nagios.conf /etc/apache2/sites-enabled/
      sudo ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios
      EOF
  only_if { isnagios == true }
end

service "nagios" do
  supports :status => true, :reload => true, :restart => true
  action [:enable, :restart]
end

execute 'Extract cloudwatch' do
  cwd node['cloudwatch']['path']
  command <<-EOF
  set -e
  sudo wget -O nagios-cloudwatch.latest.tar.gz https://github.com/maglub/nagios-cloudwatch/tarball/master
  sudo tar xvzf nagios-cloudwatch.latest.tar.gz
  sudo service apache2 restart
  sudo service nagios restart
  EOF
  only_if { iscloud == true }
end

directory node['cloudwatch']['path'] do
  owner node['nagios']['user']
  group node['nagios']['group']
  recursive true
  mode "0775"
end

template "#{node['cloudwatch']['config']}/config.yml" do
  source "config.yml.erb"
  mode "0755"
end
