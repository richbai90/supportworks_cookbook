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
  swserver = registry_get_values(swreg(node)).select do |val|
    val[:name] == "InstallPath"
  end[0][:data]

  core_services = registry_get_values(csreg(node)).select do |val|
    val[:name] == "InstallPath"
  end[0][:data]

  mysql_path = registry_get_values("#{csreg(node)}\\Components\\MariaDB").select do |val|
    val[:name] == 'InstallPath'
  end[0][:data]

  x86_64 = node['kernel']['machine'] == 'x86_64'

  setup = load_setup(new_resource.custom_resources, swserver, core_services)
  ::FileUtils.chdir(new_resource.custom_resources) do
    setup['deploy'].each do |d|
      setup_file = ::File.realpath(::File.join(d['package'], 'setup.yml'))
      ::File.open(setup_file) do |infile|
        l = 0
        while (line = infile.gets)
          l = l + 1
          if line =~ /CHANGE_ME/i
            class NotReadyError < StandardError
            end
            raise(NotReadyError, "ONE ORE MORE SETUP FILES ARE NOT READY TO BE DEPLOYED IN #{setup_file} LINE #{l} (CHANGE_ME)")
          end
        end
      end
    end
  end

  setup["deploy"].each do |d|
    ::FileUtils.chdir(new_resource.custom_resources) do
      _cwd = Dir.pwd
      _setup = load_setup(d["package"], swserver, core_services)
      begin
        if _setup['prereq'].respond_to?(:each)
          _setup['prereq'].each do |prereq|
            ruby_block "wait for #{prereq}" do
              block do
                p 'Waiting for the creation of ' + prereq
                until ::File.exists?(prereq)
                  sleep 5
                end
              end
            end
          end
        else
          prereq = _setup['prereq']
          ruby_block "wait for #{prereq}" do
            block do
              p 'Waiting for the creation of ' + prereq
              until ::File.exists?(prereq)
                sleep 5
              end
            end
          end
        end
      rescue TypeError
        p _setup['prereq']
      end


      ruby_block "Backup and copy files from #{d["package"]}" do
        block do
          backup_and_copy(::File.join(_cwd, d["package"]), swserver, core_services, ::File.join(mysql_path, 'bin'), swdata_db_user || cache_db_user, swdata_db_password || cache_db_password)
        end
      end

      ruby_block "Apply Schema Changes" do
        block do
          if _setup.has_key?('db_schema') && _setup['db_schema'].respond_to?(:empty?) && !_setup['db_schema'].empty?
            p 'Applying Schema Changes'
            ::Dir.chdir(::File.join(swserver, 'bin')) do
              export_schema = ::File.join(Chef::Config['file_cache_path'], 'ex_dbschema.xml').gsub('/', "\\")
              system("start cmd /k cmd /C swdbconf.exe -import \"#{_setup["db_schema"].gsub('/', '\\')}\"  -tdb swdata -cuid #{swdata_db_user || cache_db_user} -cpwd \"#{swdata_db_password || cache_db_password}\"")
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
      (_setup['queries'] || []).each do |db, queries|
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
            cwd ::File.join(mysql_path, 'bin')
            command "mysql --port=5002 -u #{swdata_db_user || cache_db_user} --password=\"#{swdata_db_password || cache_db_password}\" < #{'"' + tmppath + '"'}"
          end
        end
      end
      wrap_array(_setup['reg']).each do |reg|
        path = expand_reg(reg['path'])
        type = reg.has_key?('type') ? reg['type'].to_sym : :string
        values = []
        wrap_array(reg['entries']).each do |entry|
          if entry['value'] =~ /\+=\s*?/
            entry['value'] = entry['value'].split('+=').drop(1).join('').strip
            orig_key = registry_get_values(path).select do |val|
              val[:name] == entry['name']
            end[0]
            # make sure that the data and type are correct
            orig_val = orig_key[:data]
            type = orig_key[:type]
            # make sure that this has not already been updated
            unless orig_val.downcase.include?(entry['value'].downcase)
              entry['value'] = entry['value'] + orig_val
            end
          end
          values.push({:name => entry['name'], :type => type, :data => entry['value']})
        end
        unless values.empty?
          registry_key path do
            values values

            architecture(x86_64 ? :i386 : :machine)
          end
        end
      end
      wrap_array(_setup['execute']).each do |exec|
        if exec.respond_to? :lines
          # exec is a string so lets check if we need to use a ps template
          if exec.lines.count > 1
            # multi line string, need to use a ps1 template
            powershell_script exec.lines.first do
              code exec
            end
          else
            # on liner, just use exec
            execute exec do
              command exec
            end
          end
        else
          # exec is an object wrap cmd in an array incase we have multiple cmds in one dir
          wrap_array(exec['cmd']).each do |cmd|
            execute cmd do
              if exec['cwd']
                cwd exec['cwd']
              end
              command exec['new_shell'] ? "start cmd /C cmd /C #{'"' + cmd + '"'}" : cmd
            end
          end
        end
      end
    end
  end

  template 'restore.bat' do
    path ::File.join(backup_folder(swserver), 'restore.bat')
    source 'restore.bat.erb'
    variables({
                  :usr => swdata_db_user || cache_db_user,
                  :pass => swdata_db_password || cache_db_password,
                  :mysql => ::File.join(mysql_path, 'bin').gsub('/', "\\")
              })
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
