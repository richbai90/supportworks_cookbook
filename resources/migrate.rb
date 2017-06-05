property :host, String, name_property: true
property :user, String, required: true
property :password, String, required: true
property :root_user, String, default: 'root'
property :root_pw, String, default: ''
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

  mysqldump = file_join(mysql_path, 'bin', 'mysqldump.exe')


  execute 'dump' do
    retries 3
    retry_delay 2
    command "#{mysqldump} -h #{new_resource.host} -u #{new_resource.user} -p#{new_resource.password} --port 5002 --all-databases --add-drop-table --single-transaction > #{::File.join(Chef::Config['file_cache_path'], 'dump.sql')}"
  end

  execute 'restore' do
    command "#{::File.join(mysql_path, 'bin', 'mysql.exe')} -u root --port 5002 < #{::File.join(Chef::Config['file_cache_path'], 'dump.sql')}"
  end

  template ::File.join(Chef::Config['file_cache_path'], 'update.sql') do
    source 'update.sql.erb'
    variables({
                  :dsn => swdata_dsn,
                  :uid => swdata_user || root_user,
                  :pwd => swdata_pw || root_pw,
                  :root => root_user,
                  :root_pwd => root_pw
              })
  end

  execute 'update.sql' do
    command "#{::File.join(mysql_path, 'bin', 'mysql.exe')} -u #{root_user} --password=#{(update_password && old_root_password ) || root_pw} --port 5002 < #{::File.join(Chef::Config['file_cache_path'], 'update.sql')}"
  end

end

action_class do
  include Supportworks::Helpers
end