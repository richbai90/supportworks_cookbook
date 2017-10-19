powershell_script 'kill-running-processes' do
  code 'taskkill /f /im * /fi "imagename eq sw*"'
end

supportworks_core_services 'cs' do
  path ::File.join(node['supportworks']['install_dir'], 'Hornbill', 'Core Services')
  root_pw node['supportworks']['root_password'] # this is the root password that will exist on the new server
  version node['supportworks']['version']
  media node['supportworks']['media']
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