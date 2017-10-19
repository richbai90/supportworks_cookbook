#
# Cookbook Name:: supportworks
# Recipe:: default
#
# Copyright 2017, Bittercreek Technology, Inc
#
# All rights reserved - Do Not Redistribute

powershell_script 'kill-running-processes' do
  code 'taskkill /f /im * /fi "imagename eq sw*"'
end

supportworks_core_services 'cs' do
  path ::File.join(node['supportworks']['install_dir'], 'Hornbill', 'Core Services')
  root_pw node['supportworks']['root_password'] # this is the root password that will exist on the new server
  version node['supportworks']['version']
  media node['supportworks']['media']
end

supportworks_migrate node['supportworks']['migrate_data_from'] do
  from_user node['supportworks']['migrate_using_user'] # this is the user we are using to migrate from the server at the address specified in the name
  from_password node['supportworks']['migrate_using_password'] # this is the password for the migrate user
  to_user 'root' # this is the user that will have root privileges and that sw will use when accessing the db on the new server
  to_password node['supportworks']['root_password'] # this is the password for the aforementioned user
  update_password true # this option says to update the password to the value in the to_password if it is not the same leave it be
  swdata_dsn 'Supportworks Data' #default
end

supportworks_server 'C:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :install
  version node['supportworks']['version']
  # path :default # overwrites what's in the name. Tells the automator to use the default path
  license node['supportworks']['license']
  db_type :sw
  cache_db_user 'root'
  cache_db_password node['supportworks']['root_password'] # this is the password on the new server, corresponding to the to_password option in migrate and root_pw in core services
  sw_admin_pw node['supportworks']['admin_password']
  media node['supportworks']['media']
end

supportworks_server 'C:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :configure
  cache_db_user 'root'
  cache_db_password node['supportworks']['root_password']
  version node['supportworks']['version']
  license node['supportworks']['licensed_to']
  media ['supportworks']['media']
end
