property :version, String, default: '8.2'
property :media, String
property :path, [String, Symbol], name_property: true
property :license, String, required: true
property :db_type, Symbol, default: :sw
property :sw_admin_pw, String, default: 'password'
property :cache_db_user, String, default: 'root'
property :cache_db_password, String, default: ''
property :dsn, String, default: 'swdata'
property :swdata_db_user, String, default: 'sa'
property :swdata_db_password, String, default: ''
property :https, [TrueClass, FalseClass], default: true
property :enhanced_security, [TrueClass, FalseClass], default: false
property :zapp, String
property :fqdn, [TrueClass, FalseClass], default: false

default_action :install

action :install do

  template_path=file_join(Chef::Config['file_cache_path'], 'automate_server.ps1')

  template template_path do
    source 'server.ps1.erb'
    variables({
                  :lic => license,
                  :install_path => (get_path(get_path(new_resource.path, 'sw', node), 'sw', node)),
                  :db => {type: db_type, user: [cache_db_user, swdata_db_user], pw: [cache_db_password, swdata_db_password]},
                  :admin_pw => sw_admin_pw,
                  :dsn => dsn
              })
  end

  execute 'noop' do
    action :nothing
  end

  ruby_block 'automate' do
    retries 3
    retry_delay 2
    block { ps_script(template_path) }
  end

  windows_package 'ESP' do
    action :install
    source repo_from_version('sw', new_resource.version, new_resource.media)
    installer_type :custom
    only_if { registry_data_exists?(csreg(node), :name => 'Version', :type => :string, :data => '6.0.0') }
    not_if { registry_key_exists?(swgreg(node), :name => 'Supportworks Server')}
  end

  template ::File.join(Chef::Config['file_cache_path'], 'swsystagfix.sql') do
    source 'swsystagfix.sql.erb'
  end

  mysql_path = registry_get_values("#{csreg(node)}\\Components\\MariaDB").select do |val|
    val[:name] == 'InstallPath'
  end[0][:data]

  execute 'update.sql' do
    command "#{::File.join(mysql_path, 'bin', 'mysql.exe')} -u #{cache_db_user} --password=#{cache_db_password} --port 5002 < #{::File.join(Chef::Config['file_cache_path'], 'swsystagfix.sql')}"
  end

  service 'SwServerService' do
    action :start
  end

  service 'SwMailService' do
    action :start
  end

  service 'SwMailSchedule' do
    action :start
  end

  windows_package 'client' do
    action :install
    source ::File.join(get_path(new_resource.path, 'sw', node), 'clients', 'LauncherInstaller.msi')
  end

end

action :configure do
  cookbook_file ::File.join(Chef::Config['file_cache_path'], 'ZappUtility.exe') do
    source 'ZappUtility.exe'
    action :create
  end

  if zapp.nil?
    remote_file ::File.join(Chef::Config['file_cache_path'], zapp_version(version)) do
      source zapp_from_repo(version)
    end
    zapp = ::File.join(Chef::Config['file_cache_path'], zapp_version(version))
  else
    if is_uri(zapp)
      remote_file ::File.join(Chef::Config['file_cache_path'], zapp_version(version)) do
        source zapp
      end
      zapp = ::File.join(Chef::Config['file_cache_path'], zapp_version(version))
    else
      unless ::File.exist? zapp
        raise "Unexpected value for zapp parameter. Got: #{zapp} expected local file or valid URI"
      end
    end
  end

  execute 'license_itsm_default' do
    command ::File.join(Chef::Config['file_cache_path'], 'ZappUtility.exe') + " '#{zapp}' -l '#{license}'"
  end

  execute 'install_itsm_default' do
    command ::File.join(get_path(get_path(new_resource.path, 'sw', node), 'sw', node), 'bin', 'swappinstall.exe') + " -appinstall \"#{zapp}\""
  end

  template ::File.join(get_path(get_path(new_resource.path, 'sw', node), 'sw', node), 'clients', 'client.setup.bat') do
    source 'client.setup.bat.erb'
    variables({
                  :version => pad_version(new_resource.version),
                  :base_version => new_resource.version[0]
              })
  end

  template ::File.join(get_path(get_path(new_resource.path, 'sw', node), 'sw', node), 'docs', 'software', 'index.php') do
    source 'client_install.php.erb'
  end

  template ::File.join(get_path(new_resource.path, 'sw', node), 'html', '_selfservice', '_itsm_default_v2_template', 'config', '_ssp_config.json') do
    source 'selfservice_config.json.erb'
    variables({
                  :protocol => (https && 'https') || 'http',
                  :instance_address => (fqdn && node['fqdn']) || node['ipaddress']
              })
  end

  ruby_block 'copy selfservice template' do
    temp_path = ::File.join(get_path(new_resource.path, 'sw', node), 'html', '_selfservice', '_itsm_default_v2_template')
    new_path = ::File.join(get_path(get_path(new_resource.path, 'sw', node), 'sw', node), 'html', '_selfservice', 'selfservice')
    block do
      if ::File.exist?(new_path) do
        delete(new_path)
      end
        ::FileUtils.mkdir_p new_path
        ::FileUtils.cp_r(Dir["#{temp_path}/**/*"], new_path)
      end
    end
  end

  template ::File.join(get_path(new_resource.path, 'sw', node), 'html', 'webclient', 'php', '_wcconfig.php') do
    source 'webclient_config.php.erb'
    variables({
                  :enhanced_security => new_resource.enhanced_security
              })
  end

end

action_class do
  include Supportworks::Helpers
end