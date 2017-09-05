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

supportworks_migrate :no_migrate do #use :no_migrate to not migrate the data but still perform neccessary confs
  from_user 'migrate' # this is the user we are using to migrate from the server at the address specified in the name
  from_password 'password' #this is the password for the migrate user
  to_user 'root' # this is the user that will have root privileges and that sw will use when accessing the db on the new server
  to_password 'ch@ng3d&Up!' # this is the password for the aforementioned user
  update_password true # this option says to update the password to the value in the to_password if it is not the same leave it be
  swdata_dsn 'Supportworks Data' #default
end