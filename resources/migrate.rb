property :host, String, name_property: true
property :from_user, String, required: true
property :from_password, String, required: true
property :to_user, String, default: 'root'
property :to_password, String, default: ''
property :root_user, String, default: 'root'
property :root_password, String, default: ''
property :swdata_user, String
property :swdata_pw, String
property :swdata_dsn, String, default: 'Supportworks Data'
property :old_root_password, String, default: ''
property :update_password, [TrueClass,FalseClass], default: false

default_action :migrate

action :migrate do

  mysql_path = registry_get_values("#{csreg(node)}\\Components\\MariaDB").select do |val|
    val[:name] == 'InstallPath'
  end[0][:data]

  mysql_bin = file_join(mysql_path, 'bin')


  execute 'dump_data' do
    retries 3
    retry_delay 2
	cwd mysql_bin
    command "mysqldump -h #{new_resource.host} -u #{new_resource.from_user} --password=\"#{new_resource.from_password}\" --port 5002 --add-drop-table --databases swdata sw_systemdb sw_messagestore sw_knowledgebase sw_calendar --single-transaction --quick  > #{::File.join(Chef::Config['file_cache_path'], 'dump.sql')}"
  end
  
  execute 'update_password' do
    cwd mysql_bin
    command "mysql -u root --password=\"#{old_root_password}\" --port 5002 -e \"SET PASSWORD FOR 'root'@'localhost' = OLD_PASSWORD('#{root_password}')\""
	ignore_failure true
	only_if "cd #{'"' + mysql_bin + '"'} && mysql -u root --password=\"#{old_root_password}\" --port 5002"
  end
  
    execute 'restore_data' do
	cwd mysql_bin
    command "mysql -u root --port 5002 -f < #{::File.join(Chef::Config['file_cache_path'], 'dump.sql')}"
	ignore_failure true
	only_if "cd #{'"' + mysql_bin + '"'} && mysql -u root --port 5002"
  end
  
  execute 'restore data with password' do
    password = (to_user == 'root') ? to_password : root_password
	cwd mysql_bin
	command "mysql -u root --password=\"#{password}\" --port 5002 -f < #{::File.join(Chef::Config['file_cache_path'], 'dump.sql')}"
	only_if "cd #{'"' + mysql_bin + '"'} && mysql -u root --password=\"#{password}\" --port 5002"
  end

  template ::File.join(Chef::Config['file_cache_path'], 'update.sql') do
    source 'update.sql.erb'
    variables({
                  :dsn => swdata_dsn,
                  :uid => swdata_user || to_user || root_user,
                  :pwd => swdata_pw || to_password || root_password,
                  :root => (to_user == 'root') ? to_user : root_user,
                  :root_pwd => (to_user == 'root') ? to_password : root_password
              })
  end
  
  template ::File.join(Chef::Config['file_cache_path'], 'sw_config.sql') do
	source 'sw_config.sql.erb'
	variables({
                  :dsn => swdata_dsn,
                  :uid => swdata_user || to_user,
                  :pwd => swdata_pw || to_password,
                  :root => (to_user == 'root') ? to_user : root_user,
                  :root_pwd => (to_user == 'root') ? to_password : root_password
              })
  end


  execute 'update.sql' do
    password = (to_user == 'root') ? to_password : root_password
    not_if "cd #{'"' + mysql_bin + '"'} && mysql -u root --password\"#{password}\" --port 5002"
    cwd mysql_bin
    command "mysql -u #{root_user} --port 5002 < \"#{::File.join(Chef::Config['file_cache_path'], 'update.sql')}\""
	only_if "cd #{'"' + mysql_bin + '"'} && mysql -u root --port 5002"
  end
  
  execute 'update.sql with password' do
    password = (to_user == 'root') ? to_password : root_password
    not_if "cd #{'"' + mysql_bin + '"'} && mysql -u root --password=\"#{password}\" --port 5002"
    cwd mysql_bin
    command "mysql -u #{root_user} --port 5002 < \"#{::File.join(Chef::Config['file_cache_path'], 'update.sql')}\""
	only_if "cd #{'"' + mysql_bin + '"'} && mysql -u root --password=\"#{password}\" --port 5002"
  end
end

action_class do
  include Supportworks::Helpers
end