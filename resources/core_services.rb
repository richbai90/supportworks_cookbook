property :version, String, default: '6.0'
property :path, String, default: Supportworks::Helpers.install_path('cs', node)
property :root_user, String, default: 'root'
property :root_pw
property :db_type, Symbol, default: :sw
default_action :install

action :install do

  cookbook_file ::File.join('C:', 'windows', 'system32', 'swsqlodbc.dll') do
    source 'swsqlodbc.dll'
    action :create
  end

  windows_package 'CsSetup' do
    action :install
    checksum checksum_from_version('cs', new_resource.version)
    source repo_from_version('cs', new_resource.version)
    options create_option_string(:INSTALLDIR => path)
    not_if { registry_key_exists?(csreg(node)) }
  end

  registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\Supportworks Cache' do
    values [
               {:name => 'Database', :type => :string, :data => 'sw_systemdb'},
               {:name => 'Description', :type => :string, :data => 'Supportworks Helpdesk Cache Data'},
               {:name => 'Driver', :type => :string, :data => ::File.join('C:', 'windows', 'system32', 'swsqlodbc.dll').gsub('/', "\\")},
               {:name => 'Option', :type => :dword, :data => 0x0},
               {:name => 'Password', :type => :string, :data => root_pw},
               {:name => 'Port', :type => :dword, :data => 0x138a},
               {:name => 'Server', :type => :string, :data => '127.0.0.1'},
               {:name => 'Stmt', :type => :string, :data => ''},
               {:name => 'User', :type => :string, :data => root_user},
           ]

    architecture((node['kernel']['machine'] == 'x86_64') ? :i386 : :machine)
  end

  registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' do
    values [
               {:name => 'Supportworks Cache', :type => :string, :data => 'Supportworks SQL Driver'},
           ]

    architecture((node['kernel']['machine'] == 'x86_64') ? :i386 : :machine)
  end

  registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\Supportworks SQL Driver' do
    values [
               {:name => 'APILevel', :type => :string, :data => '3'},
               {:name => 'ConnectFunctions', :type => :string, :data => 'YYN'},
               {:name => 'Driver', :type => :string, :data => ::File.join('C:', 'windows', 'system32', 'swsqlodbc.dll').gsub('/', "\\")},
               {:name => 'DriverODBCVer', :type => :string, :data => '03.51'},
               {:name => 'FileUsage', :type => :string, :data => '0'},
               {:name => 'Setup', :type => :string, :data => ::File.join('C:', 'windows', 'system32', 'swsqlodbc.dll').gsub('/', "\\")},
               {:name => 'SQLLevel', :type => :dword, :data => 0x01},
           ]
  end

  if db_type == :sw
    registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources' do
      values [
                 {:name => 'Supportworks Data', :type => :string, :data => 'Supportworks SQL Driver'},
             ]

      architecture((node['kernel']['machine'] == 'x86_64') ? :i386 : :machine)
    end

    registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.INI\Supportworks Data' do
      values [
                 {:name => 'Database', :type => :string, :data => 'swdata'},
                 {:name => 'Description', :type => :string, :data => 'Supportworks Helpdesk Application Data'},
                 {:name => 'Driver', :type => :string, :data => ::File.join('C:', 'windows', 'system32', 'swsqlodbc.dll').gsub('/', "\\")},
                 {:name => 'Option', :type => :dword, :data => 0x0},
                 {:name => 'Password', :type => :string, :data => root_pw},
                 {:name => 'Port', :type => :dword, :data => 0x138a},
                 {:name => 'Server', :type => :string, :data => '127.0.0.1'},
                 {:name => 'Stmt', :type => :string, :data => ''},
                 {:name => 'User', :type => :string, :data => root_user},
             ]

      architecture((node['kernel']['machine'] == 'x86_64') ? :i386 : :machine)
    end
  end

end

action_class do
  include Supportworks::Helpers
end