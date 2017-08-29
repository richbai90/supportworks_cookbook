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

  swserver = registry_get_values(swreg(node)).select do |val|
    val[:name] == "InstallPath"
  end[0][:data]

  mysql_path = registry_get_values("#{csreg(node)}\\Components\\MariaDB").select do |val|
    val[:name] == 'InstallPath'
  end[0][:data]

  load_setup(new_resource.custom_resources, swserver)

  ruby_block 'wait for ' + setup['prereq'] do
    block do
      p "\r\n" * 30 + 'Waiting for the creation of ' + setup["prereq"]
      until ::File.exists?(setup['prereq'])
        sleep 5
      end
      backup_and_copy(new_resource.custom_resources, swserver, ::File.join(mysql_path, 'bin'), swdata_db_user || cache_db_user, swdata_db_password || cache_db_password)
      p 'Applying Schema Changes'
      ::Dir.chdir(::File.join(swserver, 'bin')) do
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

  setup['execute'].each do |exec|
    execute exec['command'] do
      cwd exec['cwd']
      command exec['new_shell'] ? "start cmd /C cmd /C #{'"' + exec['command'] + '"'}" : exec['command']
    end
  end

  setup['queries'].each do |db, queries|
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
  
  template 'restore.bat' do
    path ::File.join(backup_folder(swserver), 'restore.bat')
    source 'restore.bat.erb'
    variables({
                  :usr => swdata_db_user || cache_db_user,
                  :pass => swdata_db_password || cache_db_password,
                  :mysql => ::File.join(mysql_path, 'bin').gsub('/', "\\")
              })
  end
end

action_class do
  include Supportworks::Helpers
end
