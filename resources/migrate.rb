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


  execute 'dump' do
    retries 3
    retry_delay 2
	cwd mysql_bin
    command "mysqldump -h #{new_resource.host} -u #{new_resource.from_user} -p#{new_resource.from_password} --port 5002 --all-databases --add-drop-table --single-transaction > #{::File.join(Chef::Config['file_cache_path'], 'dump.sql')}"
	not_if {::File.exist?(::File.join(mysql_path,'data','swdata'))}
  end

  execute 'restore' do
	cwd mysql_bin
    command "mysql -u root --port 5002 < #{::File.join(Chef::Config['file_cache_path'], 'dump.sql')}"
	not_if {::File.exist?(::File.join(mysql_path,'data','swdata'))}
  end

  template ::File.join(Chef::Config['file_cache_path'], 'update.sql') do
	not_if {}
    source 'update.sql.erb'
    variables({
                  :dsn => swdata_dsn,
                  :uid => swdata_user || to_user,
                  :pwd => swdata_pw || to_password,
                  :root => (to_user == 'root') ? to_user : root_user,
                  :root_pwd => (to_user == 'root') ? to_password : root_password
              })
  end

  execute 'update.sql' do
	not_if { registry_key_exists?(swreg(node)) }
    cwd mysql_bin
    command "mysql -u #{root_user} --password=#{(update_password && old_root_password ) || to_password} --port 5002 < \"#{::File.join(Chef::Config['file_cache_path'], 'update.sql')}\""
  end

end

action_class do
  include Supportworks::Helpers
end