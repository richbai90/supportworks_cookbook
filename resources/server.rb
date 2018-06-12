property :version, String, default: '8.2'
property :media, String
property :path, [String, Symbol], name_property: true
property :license, String, required: true
property :db_type, Symbol, default: :sw
property :sw_admin_pw, String, default: 'password'
property :cache_db_user, String, default: 'root'
property :cache_db_password, String, default: ''
property :db, String, default: 'swdata'
property :swdata_db_user, String
property :swdata_db_password, String
property :https, [TrueClass, FalseClass], default: true
property :enhanced_security, [TrueClass, FalseClass], default: false
property :zapp, String
property :fqdn, [TrueClass, FalseClass], default: false
property :skip_esp_for_testing, [TrueClass, FalseClass], default: false
property :debug_webclient, [TrueClass, FalseClass], default: true

default_action :install

action :install do

  mysql_path = registry_get_values("#{csreg(node)}\\Components\\MariaDB").select do |val|
    val[:name] == 'InstallPath'
  end[0][:data]

  powershell_script 'install_ESP' do
    code <<~PS1
      $DefaultAdminPassword = '#{new_resource.sw_admin_pw}'
      $InstallPath = '"#{get_path(new_resource.path, 'sw', node)}"'
      $OdbcDSN = '"Supportworks Data"'
      $OdbcUID = '#{new_resource.swdata_db_user || new_resource.cache_db_user}'
      $OdbcPWD = '#{new_resource.swdata_db_password || new_resource.cache_db_password}'
      $UseSwDatabase = #{new_resource.db_type == :sw ? 1 : 0}
      $OdbcDBName = 'swdata'
      $OdbcCacheDSN = '"Supportworks Cache"'
      $SystemDBUID = '#{new_resource.cache_db_user}'
      $SystemDBPWD = '#{new_resource.cache_db_password}'
      $EnableXMLMCDocumentation = 1
      $UseLegacyODBC = 1

      cd "#{new_resource.media}"
      ./SwSetup.exe -s -var:DefaultAdminPassword=$DefaultAdminPassword -var:InstallPath=$InstallPath -var:OdbcDSN=$OdbcDSN -var:OdbcUID=$OdbcUID -var:OdbcPWD=$OdbcPWD -var:UseSwDatabase=$UseSwDatabase -var:OdbcCacheDSN=$OdbcCacheDSN -var:OdbcDBName=$OdbcDBName -var:SystemDBUID=$SystemDBUID -var:SystemDBPWD=$systemDBPWD -var:EnableXMLMCDocumentation=1 -var:UseLegacyODBC=1 | Out-Null
    PS1
    not_if { new_resource.skip_esp_for_testing }
  end

  template 'sql_configuration' do
    path ::File.join(Chef::Config['file_cache_path'], 'swsqlconfs.sql')
    source 'swsqlconfs.sql.erb'
    variables({
                  :server => get_path(new_resource.path, 'sw', node).gsub('\\', '/'),
                  :systag => '::SYSTAG::'
              })
  end

  ruby_block 'license server' do
    block do
      license_server(get_path(new_resource.path, 'sw', node), new_resource.license)
      file = Chef::Util::FileEdit.new(::File.join(Chef::Config['file_cache_path'], 'swsqlconfs.sql'))
      file.search_file_replace(/::SYSTAG::/, get_sysid(new_resource.path, 'sw', node))
      file.write_file
    end
  end

  execute 'sw_config.sql' do
    cwd ::File.join(mysql_path, 'bin')
    command "mysql -f -u #{new_resource.swdata_db_user || new_resource.cache_db_user} --password=\"#{new_resource.swdata_db_password || new_resource.cache_db_password}\" --port 5002 < \"#{::File.join(Chef::Config['file_cache_path'], 'sw_config.sql')}\""
    ignore_failure false
  end

end

action :configure do
  mysql_path = registry_get_values("#{csreg(node)}\\Components\\MariaDB").select do |val|
    val[:name] == 'InstallPath'
  end[0][:data]

  swpath = get_path(new_resource.path, 'sw', node)

  cookbook_file ::File.join(Chef::Config['file_cache_path'], 'ZappUtility.exe') do
    source 'ZappUtility.exe'
    action :create
  end

  if new_resource.zapp.nil?
    if new_resource.media.nil?
      remote_file ::File.join(Chef::Config['file_cache_path'], zapp_version(new_resource.version)) do
        source zapp_from_repo(new_resource.version, new_resource.media)
      end
      new_resource.zapp = ::File.join(Chef::Config['file_cache_path'], zapp_version(new_resource.version))
    else
      new_resource.zapp = zapp_from_repo(new_resource.version, new_resource.media)
    end
  else
    if is_uri(new_resource.zapp)
      remote_file ::File.join(Chef::Config['file_cache_path'], zapp_version(new_resource.version)) do
        source new_resource.zapp
      end
      new_resource.zapp = ::File.join(Chef::Config['file_cache_path'], zapp_version(new_resource.version))
    else
      unless ::File.exist? new_resource.zapp
        raise "Unexpected value for new_resource.zapp parameter. Got: #{new_resource.zapp} expected local file or valid URI"
      end
    end
  end

  execute 'license_itsm_default' do
    command ::File.join(Chef::Config['file_cache_path'], 'ZappUtility.exe') + " '#{new_resource.zapp}' -l '#{new_resource.license}'"
  end

  execute 'install_itsm_default' do
    cwd ::File.join(get_path(new_resource.path, 'sw', node), 'bin')
    command "swappinstall.exe -appinstall \"#{new_resource.zapp}\""
    # install_zapp(swpath.gsub('\\', '/'), new_resource.zapp)
  end

  ruby_block 'database_configurations' do
    block do
      ::Dir.chdir(::File.join(get_path(new_resource.path, 'sw', node), 'bin')) do
        export_schema = ::File.join(Chef::Config['file_cache_path'], 'ex_dbschema.xml').gsub('/', "\\")
        system("start cmd /k cmd /C swdbconf.exe -import \"#{::File.join(swpath, 'idata', 'itsm_default', 'dbschema.xml').gsub('/', '\\')}\" -app \"swserverservice\"  -tdb swdata -cuid #{new_resource.swdata_db_user || new_resource.cache_db_user} -cpwd \"#{new_resource.swdata_db_password || new_resource.cache_db_password}\"")
        wait_for_db_schema
        system("start cmd /k cmd /C swdbconf.exe -s Localhost -app \"swserverservice\" -tdb swdata -log chef_dbconf.log -pipelog -cuid #{new_resource.swdata_db_user || new_resource.cache_db_user} -cpwd \"#{new_resource.swdata_db_password || new_resource.cache_db_password}\"")
        wait_for_db_schema
        system("start cmd /k cmd /C swdbconf.exe -export \"#{export_schema}\" -app \"swserverservice\" -tdb swdata -cuid #{new_resource.swdata_db_user || new_resource.cache_db_user} -cpwd \"#{new_resource.swdata_db_password || new_resource.cache_db_password}\"")
        wait_for_db_schema
        system("start cmd /k cmd /C swdbconf.exe -import \"#{export_schema}\" -app \"swserverservice\"  -tdb swdata -cuid #{new_resource.swdata_db_user || new_resource.cache_db_user} -cpwd \"#{new_resource.swdata_db_password || new_resource.cache_db_password}\"")
        wait_for_db_schema
        system("start cmd /k cmd /C swdbconf.exe -s Localhost -app \"swserverservice\" -tdb swdata -log chef_dbconf.log -pipelog -cuid #{new_resource.swdata_db_user || new_resource.cache_db_user} -cpwd \"#{new_resource.swdata_db_password || new_resource.cache_db_password}\"")
        wait_for_db_schema
      end
    end
  end

  execute 'install_itsm_default' do
    cwd ::File.join(get_path(new_resource.path, 'sw', node), 'bin')
    command "swappinstall.exe -appinstall \"#{new_resource.zapp}\""
    # install_zapp(swpath.gsub('\\', '/'), new_resource.zapp)
  end

  ruby_block 'precopy ITSM' do
    block { precopy_itsm(swpath) }
  end

  template ::File.join(get_path(new_resource.path, 'sw', node), 'clients', 'client.setup.bat') do
    source 'client.setup.bat.erb'
    variables({
                  :version => pad_version(new_resource.version),
                  :base_version => new_resource.version[0]
              })
  end

  template ::File.join(get_path(new_resource.path, 'sw', node), 'docs', 'software', 'index.php') do
    source 'client_install.php.erb'
  end

  template ::File.join(get_path(new_resource.path, 'sw', node), 'html', '_selfservice', '_itsm_default_v2_template', 'config', '_ssp_config.json') do
    source 'selfservice_config.json.erb'
    variables({
                  :protocol => (new_resource.https && 'https') || 'http',
                  :instance_address => (new_resource.fqdn && node['fqdn']) || node['ipaddress']
              })
  end

  ruby_block 'copy selfservice template' do
    block do
      require('fileutils')
      temp_path = ::File.join(get_path(new_resource.path, 'sw', node), 'html', '_selfservice', '_itsm_default_v2_template').gsub('\\', '/')
      new_path = ::File.join(get_path(new_resource.path, 'sw', node), 'html', '_selfservice', 'selfservice').gsub('\\', '/')
      if ::File.exist?(new_path) do
        FileUtils.rm_rf(new_path)
      end
      end
      FileUtils.mkdir_p new_path
      FileUtils.cp_r(temp_path + '/.', new_path)
    end
  end

  template ::File.join(get_path(new_resource.path, 'sw', node), 'html', 'webclient', 'php', '_wcconfig.php') do
    source 'webclient_config.php.erb'
    variables({
                  :enhanced_security => new_resource.enhanced_security
              })
  end

  apache_path = registry_get_values("#{csreg(node)}\\Components\\Apache").select do |val|
    val[:name] == 'InstallPath'
  end[0][:data]

  template ::File.join(apache_path, 'conf', 'cs', 'apps', '501_sw_aliases.conf') do
    server_path = get_path(new_resource.path, 'sw', node)
    variables({
                  :server_unix => server_path.gsub('\\', '/'),
                  :server_windows => server_path.gsub('/', '\\')
              })
  end

  execute 'swqlconfs.sql' do
    cwd ::File.join(mysql_path, 'bin')
    command "mysql -f -u #{new_resource.swdata_db_user || new_resource.cache_db_user} --password=\"#{new_resource.swdata_db_password || new_resource.cache_db_password}\" --port 5002 < \"#{::File.join(Chef::Config['file_cache_path'], 'swsqlconfs.sql')}\""
    ignore_failure false
  end

  service 'ApacheServer' do
    action :stop
  end

  service 'ApacheServer' do
    action :start
  end

  service 'SwServerService' do
    action :start
    timeout 300
  end

  service 'SwMailService' do
    action :start
    timeout 300
  end

  service 'SwMailSchedule' do
    action :start
    timeout 300
  end

  service 'SwCalendarService' do
    action :start
  end

  service 'SwFileService' do
    action :start
  end

  service 'SwMessengerService' do
    action :start
  end

  service 'SwLogService' do
    action :start
  end

  service 'SwSchedulerService' do
    action :start
  end

  powershell_script 'Create New Data Dictionary Alert' do
    code <<~PS1
      $wshell = New-Object -ComObject Wscript.Shell
      $wshell.Popup("Please create the new Data Dictionary",0,"Create Data Dictionary",0x1)
    PS1
  end

end

action_class do
  include Supportworks::Helpers
end

