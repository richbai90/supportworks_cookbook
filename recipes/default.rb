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
  action :install #default
  path 'C:\Program Files (x86)\Hornbill\Core Services'
  root_pw 'ch@ng3d&Up!' # this is the root password that will exist on the new server
  version '6.0'
  media 'C:\swmedia'
end

supportworks_migrate '192.168.1.108' do
  from_user 'migrate' # this is the user we are using to migrate from the server at the address specified in the name
  from_password 'password' #this is the password for the migrate user
  to_user 'root' # this is the user that will have root privileges and that sw will use when accessing the db on the new server
  to_password 'ch@ng3d&Up!' # this is the password for the aforementioned user
  update_password true # this option says to update the password to the value in the to_password if it is not the same leave it be
  old_root_password '' # this says what to expect the password to be prior to updating it. leave it be.
  swdata_dsn 'Supportworks Data' #default
end

supportworks_server 'C:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :install
  version '8.2'
  # path :default # overwrites what's in the name. Tells the automator to use the default path
  license '------------------ BEGIN KEY -------------------
1334e975e10334693d628cfb334d5d42a43fdc953c468bac
f1d16c6292b89723b4c532e6a5ba6c9d016a3ab5f65ddbef
ed2457bb257600834e113f8cfd85977d24948d8c556461c6
0542a296698e00d2ace1dfd80fbda0b0e4c0033e98e6053f
0ed3470ebfc108ddd07a0637bfabce80c2ecb7907d1c0a51
ac758c7edee9fed73b61e76ac1fb66d3eeed12b73d9ec2cd
d159d718b6ff38ed52e0c80722178b8d2bcc41af151de9fb
c32ffd4808215ee2039b8aef3f2148b7821452f6
------------------- END KEY --------------------'
  db_type :sw
  cache_db_user 'root'
  cache_db_password 'ch@ng3d&Up!' # this is the password on the new server, corresponding to the to_password option in migrate and root_pw in core services
  sw_admin_pw 'password'
  media 'C:\swmedia'
  skip_esp_for_testing false
end

supportworks_server 'C:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :configure
  cache_db_user 'root'
  cache_db_password 'ch@ng3d&Up!'
  version '8.2'
  license 'Bittercreek Technology, Inc'
  media 'C:\swmedia'
  fqdn false
end
