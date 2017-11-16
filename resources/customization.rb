property :db_type, Symbol, default: :sw
property :sw_admin_pw, String, default: 'password'
property :cache_db_user, String, default: 'root'
property :cache_db_password, String, default: ''
property :db, String, default: 'swdata'
property :swdata_db_user, String
property :swdata_db_password, String
property :custom_resources, String, name_property: true
default_action :install

action :install do

  service 'ApacheServer' do
    action :stop
  end

  service 'SwMailSchedule' do
    action :stop
    timeout 300
  end

  service 'SwMailService' do
    action :stop
    timeout 300
  end

  service 'SwCalendarService' do
    action :stop
  end

  service 'SwFileService' do
    action :stop
  end

  service 'SwMessengerService' do
    action :stop
  end

  service 'SwLogService' do
    action :stop
  end

  service 'SwSchedulerService' do
    action :stop
  end

  service 'SwServerService' do
    action :stop
    timeout 300
  end

  ruby_block 'deploy' do
    block do
      $swserver = registry_get_values(swreg(node)).select do |val|
        val[:name] == "InstallPath"
      end[0][:data]

      $core_services = registry_get_values(csreg(node)).select do |val|
        val[:name] == "InstallPath"
      end[0][:data]

      $mysql_path = registry_get_values("#{csreg(node)}\\Components\\MariaDB").select do |val|
        val[:name] == 'InstallPath'
      end[0][:data]

      setup = load_setup(new_resource.custom_resources, $swserver, $core_services)

      def deploy_customizations(dir)
        setup = load_setup(dir, $swserver, $core_services)
        ruby_block 'wait for ' + setup['prereq'] do
          block do
            (1..30).each do
              p ''
            end
            p 'Waiting for the creation of ' + setup["prereq"]
            until ::File.exists?(setup['prereq'])
              sleep 5
            end
            backup_and_copy(dir, $swserver, $core_services::File.join($mysql_path, 'bin'), swdata_db_user || cache_db_user, swdata_db_password || cache_db_password)
            if setup["db_schema"] && setup["db_schema"] != null
              p 'Applying Schema Changes'
              ::Dir.chdir(::File.join($swserver, 'bin')) do
                export_schema = ::File.join(Chef::Config['file_cache_path'], 'ex_dbschema.xml').gsub('/', "\\")
                system("start cmd /k cmd /C swdbconf.exe -import \"#{setup["db_schema"].gsub('/', '\\')}\"  -tdb swdata -cuid #{swdata_db_user || cache_db_user} -cpwd \"#{swdata_db_password || cache_db_password}\"")
                wait_for_db_schema
                system("start cmd /k cmd /C swdbconf.exe -s Localhost -app \"swserverservice\" -tdb swdata -log chef_dbconf.log -pipelog -cuid #{swdata_db_user || cache_db_user} -cpwd \"#{swdata_db_password || cache_db_password}\"")
                wait_for_db_schema
                system("start cmd /k cmd /C swdbconf.exe -export \"#{export_schema}\" -tdb swdata -cuid #{swdata_db_user || cache_db_user} -cpwd \"#{swdata_db_password || cache_db_password}\"")
                wait_for_db_schema
                system("start cmd /k cmd /C swdbconf.exe -import \"#{export_schema}\"  -tdb swdata -cuid #{swdata_db_user || cache_db_user} -cpwd \"#{swdata_db_password || cache_db_password}\"")
                wait_for_db_schema
                system("start cmd /k cmd /C swdbconf.exe -s Localhost -app \"swserverservice\" -tdb swdata -log chef_dbconf.log -pipelog -cuid #{swdata_db_user || cache_db_user} -cpwd \"#{swdata_db_password || cache_db_password}\"")
                wait_for_db_schema
              end
            end
          end
        end

        (setup['execute'] || []).each do |exec|
          execute exec['command'] do
            if exec['cwd']
              cwd exec['cwd']
            end
            command exec['new_shell'] ? "start cmd /C cmd /C #{'"' + exec['command'] + '"'}" : exec['command']
          end
        end

        (setup['queries'] || []).each do |db, queries|
          queries.each do |query|
            tmpname = ::Dir::Tmpname.make_tmpname('sql', nil)
            tmppath = ::File.join(Chef::Config['file_cache_path'], tmpname)
            file tmppath do
              content <<~sql
                use #{db};
                #{query};
              sql
            end

            execute query do
              cwd ::File.join($mysql_path, 'bin')
              command "mysql --port=5002 -u #{swdata_db_user || cache_db_user} --password=\"#{swdata_db_password || cache_db_password}\" < #{'"' + tmppath + '"'}"
            end
          end
        end
      end

      setup["deploy"].each do |d|
        deploy_customizations(::File.join(new_resource.custom_resources, d["package"]))
      end
      template 'restore.bat' do
        p $swserver
        path ::File.join(backup_folder($swserver), 'restore.bat')
        source 'restore.bat.erb'
        variables({
                      :usr => swdata_db_user || cache_db_user,
                      :pass => swdata_db_password || cache_db_password,
                      :mysql => ::File.join($mysql_path, 'bin').gsub('/', "\\")
                  })
      end
    end
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
end

action_class do
  include Supportworks::Helpers
end
