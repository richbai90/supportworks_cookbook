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

supportworks_migrate '10.0.2.5' do
  from_user 'migrate' # this is the user we are using to migrate from the server at the address specified in the name
  from_password 'password' #this is the password for the migrate user
  to_user 'root' # this is the user that will have root privileges and that sw will use when accessing the db on the new server
  to_password 'ch@ng3d&Up!' # this is the password for the aforementioned user
  update_password true # this option says to update the password to the value in the to_password if it is not the same leave it be
  swdata_dsn 'Supportworks Data' #default
end

supportworks_server 'C:\Program Files (x86)\Hornbill\Supportworks Server' do
  action :install
  version '8.2'
  # path :default # overwrites what's in the name. Tells the automator to use the default path
  license '------------------ BEGIN KEY -------------------
a79494b2445a44aa54d7a8541077a0a283aadfd3b2e09172
87c8315ab4a5abfedec59b9697e5e9bb18936512ac42afa9
096e7e31cd07e4f3baf26cae6ff01d43d63885c617131398
70f2b88800de89fc5182eceec5520006915d5c7cf5bb9d39
4f96a51cfd6cca819fc9c85712c79d89a56055b26624c9cb
7bb75777827a837a9038bc393e767115b6aa3082146921e2
db82c08b6abe4fbe08700eba7fb2c39ba38c1166742179a5
afe904bbe5eb8fc9de000d348500dbff8329b331
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
