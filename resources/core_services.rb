property :version, String, default: '6.0'
property :path, String, default: Supportworks::Helpers.install_path('cs', node)
property :media, String
property :root_user, String, default: 'root'
property :root_pw
property :db_type, Symbol, default: :sw
default_action :install

action :install do
  x86_64 = node['kernel']['machine'] == 'x86_64'
  system_folder = x86_64 ? 'SysWow64' : 'system32'

  cookbook_file ::File.join('C:', 'windows', system_folder, 'swsqlodbc.dll') do
    source 'swsqlodbc.dll'
    action :create
  end

  windows_package 'CsSetup' do
    action :install
    # checksum checksum_from_version('cs', new_resource.version)
    source repo_from_version('cs', new_resource.version, new_resource.media)
    options create_option_string(:INSTALLDIR => new_resource.path)
  end
  
  registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\Supportworks Cache' do
    values [
               {:name => 'Database', :type => :string, :data => 'sw_systemdb'},
               {:name => 'Description', :type => :string, :data => 'Supportworks Helpdesk Cache Data'},
               {:name => 'Driver', :type => :string, :data => ::File.join('C:', 'windows', system_folder, 'swsqlodbc.dll').gsub('/', "\\")},
               {:name => 'Option', :type => :dword, :data => 0x0},
               {:name => 'Password', :type => :string, :data => new_resource.root_pw},
               {:name => 'Port', :type => :dword, :data => 0x138a},
               {:name => 'Server', :type => :string, :data => '127.0.0.1'},
               {:name => 'Stmt', :type => :string, :data => ''},
               {:name => 'User', :type => :string, :data => new_resource.root_user},
           ]

     architecture(x86_64 ? :i386 : :machine)
  end

  registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' do
    values [
               {:name => 'Supportworks Cache', :type => :string, :data => 'Supportworks SQL Driver'},
           ]

     architecture(x86_64 ? :i386 : :machine)
  end
  
  registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBCINST.INI\Supportworks SQL Driver' do
    values [
               {:name => 'APILevel', :type => :string, :data => '3'},
               {:name => 'ConnectFunctions', :type => :string, :data => 'YYN'},
               {:name => 'Driver', :type => :string, :data => ::File.join('C:', 'windows', system_folder, 'swsqlodbc.dll').gsub('/', "\\")},
               {:name => 'DriverODBCVer', :type => :string, :data => '03.51'},
               {:name => 'FileUsage', :type => :string, :data => '0'},
               {:name => 'Setup', :type => :string, :data => ::File.join('C:', 'windows', system_folder, 'swsqlodbc.dll').gsub('/', "\\")},
               {:name => 'SQLLevel', :type => :dword, :data => 0x01},
           ]
    architecture(x86_64 ? :i386 : :machine)
  end

  if new_resource.db_type == :sw
    registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' do
      values [
                 {:name => 'Supportworks Data', :type => :string, :data => 'Supportworks SQL Driver'},
             ]

       architecture(x86_64 ? :i386 : :machine)
    end

    registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\Supportworks Data' do
      values [
                 {:name => 'Database', :type => :string, :data => 'swdata'},
                 {:name => 'Description', :type => :string, :data => 'Supportworks Helpdesk Application Data'},
                 {:name => 'Driver', :type => :string, :data => ::File.join('C:', 'windows', system_folder, 'swsqlodbc.dll').gsub('/', "\\")},
                 {:name => 'Option', :type => :dword, :data => 0x0},
                 {:name => 'Password', :type => :string, :data => new_resource.root_pw},
                 {:name => 'Port', :type => :dword, :data => 0x138a},
                 {:name => 'Server', :type => :string, :data => '127.0.0.1'},
                 {:name => 'Stmt', :type => :string, :data => ''},
                 {:name => 'User', :type => :string, :data => new_resource.root_user},
             ]

       architecture(x86_64 ? :i386 : :machine)
    end
  end
  
  registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers' do
    values [
               {:name => 'Supportworks SQL Driver', :type => :string, :data => 'Installed'},
           ]

     architecture(x86_64 ? :i386 : :machine)
  end
  
end

action_class do
  include Supportworks::Helpers
end
