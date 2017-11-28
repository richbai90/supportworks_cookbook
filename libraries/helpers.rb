$:.unshift *Dir[File.expand_path('../../files/default/vendor/gems/**/lib', __FILE__)]

module Supportworks
  module Helpers
    extend self
    attr_reader :setup

    def update_config(path, map)
      require 'nokogiri'

      def elem_exists?(elem, in_doc, exists = false)
        require 'xmlsimple'
        require 'hashie'
        fragment = XmlSimple.xml_in(elem, {:force_array => false, :KeepRoot => true})
        in_doc = XmlSimple.xml_in(in_doc.to_xml, {:force_array => false, :KeepRoot => true})
        root = fragment.keys.first

        in_doc.extend Hashie::Extensions::DeepFind
        in_doc.deep_find(root) == fragment[root]

      end

      conf = Nokogiri::XML(File.open(path))
      selection = conf.at_css(path.select)
      wrap_array(map['add_siblings']).each do |elem|
        unless elem_exists?(elem, selection)
          selection.add_next_sibling(elem)
        end
      end
      wrap_array(map['add_children']).each do |elem|
        unless elem_exists?(elem, selection)
          selection.children.first.add_next_sibling(elem)
        end
      end
      wrap_array(map['update_text']).each do |text|
        selection.content = text
      end
      wrap_array(map['change_attr']).each do |attr|
        selection[attr['attr']] = attr['to']
      end

      File.open(path, 'w') do |f|
        f.write(selection.to_xml)
      end
    end

    def wrap_array(o)
      # wrap o in an array unless it's already an array
      if o.respond_to?(:each) && !o.respond_to?(:has_key?)
        # is o an array? Return o
        o
      else
        # is o nil? return [] else return [o]
        o.nil? ? [] : [o]
      end
    end

    def expand_reg(path)
      path = path.split('\\')
      hkey = path.shift
      case hkey
        when 'HKLM'
          hkey = 'HKEY_LOCAL_MACHINE'
        when 'HKCR'
          hkey = 'HKEY_CLASSES_ROOT'
        when 'HKCU'
          hkey = 'HKEY_CURRENT_USER'
        when 'HKU'
          hkey = 'HKEY_USERS'
        when 'HKCC'
          hkey = 'HKEY_CURRENT_CONFIG'
        else
          # do nothing
      end
      (path.unshift hkey).join('\\')
    end

    def backup_folder(swserver)
      @backup_folder = @backup_folder || File.join(swserver, "backup-#{Time.now.getutc.to_s.gsub(':', '.').gsub(' ', '_')}")
    end

    def wait_for_db_schema
      sleep 2
      until `tasklist /FI "Windowtitle eq Supportworks Database Configuration Analyzer"` =~ /No tasks are running which match the specified criteria/i
        sleep 1
      end
    end

    def load_setup(resource, swserver, core_services)
      require 'yaml'
      @setup = YAML.load_file(File.join(resource, 'setup.yml'))
      replace_vars_in_setup(swserver, core_services)
      @setup
    end

    def replace_vars_in_setup(swserver, core_services, setup = nil)
      # strip the trailing backslash
      swserver = swserver[/.*(?=\\$)/] || swserver
      core_services = core_services[/.*(?=\\$)/] || core_services
      setup = @setup if setup.nil?
      if setup.respond_to? :each
        setup.each do |k, v|
          val = (v || v === false) || k
          if val.respond_to? :each
            replace_vars_in_setup(swserver, core_services, val)
          else
            begin
              require 'securerandom'
              val.gsub!('%SWSERVER%', swserver)
              val.gsub!('%SWCS%', core_services)
              val.gsub!('%RAND%', SecureRandom.base64)
            rescue NoMethodError
              # not a string so who cares
            end
          end
        end
      end
    end

    def do_backup_and_copy(file, backup_folder, copy_to, resource, dir)
      file.slice! Regexp.new ".*#{resource}(\\/?)"
      cs_file = file.slice! /.*__CS__(\/?)/
      if file.empty?
        return
      end
      if dir
        Dir.chdir(backup_folder) do
          begin
            FileUtils.mkdir_p(file)
          rescue Errno::ENOENT
            # walk_and_mkdir(file)
          end
          Dir.chdir(copy_to) do
            unless File.exists? file
              FileUtils.mkdir_p(file)
            end
          end
        end
      else
        if File.basename(file) === 'setup.yml'
          return
        end
        server_file = File.join(copy_to, file).gsub('/', '\\')
        backup_file = File.join(backup_folder, file).gsub('/', '\\')
        if File.exists?(server_file)
          FileUtils.cp_r(server_file, backup_file)
        end

        package_file = cs_file.nil? ? File.join(resource, file) : File.join(resource, '__CS__', file)
        FileUtils.cp_r(package_file, server_file, remove_destination: true)
      end
    end

    def backup_and_copy(resource, swserver, core_services, mysqlpath, mysqluser, mysqlpass, _then)
      require 'time'
      resource = File.realpath(resource).gsub('\\', '/')
      resources = Dir[resource + '/**/*']
      p 'Backing up original SW structure and applying customizations'
      begin
        FileUtils.mkdir(backup_folder(swserver))
        @backup_folder = backup_folder(swserver)
        unless @backup_in_progress
          @backup_in_progress = true
          ::Dir.chdir(mysqlpath) do
            `mysqldump.exe --add-drop-table --all-databases -u #{mysqluser} --password="#{mysqlpass}" --port 5002 > "#{::File.join(backup_folder(swserver), 'backup.sql')}"`
          end
        end
      rescue Errno::EEXIST
        # no need to make the folder if the folder already exists
      end

      backup_folders = resources.select do |_resource|
        File.directory?(_resource) && !((_resource =~ /node_modules/) || (_resource =~ /__CS__/) || (_then ? _resource =~ Regexp.new(_then) : false))
      end

      cs_folders = resources.select do |_resource|
        File.directory?(_resource) && _resource =~ /__CS__/ && !(_resource == '__CS__' || (_then ? _resource =~ Regexp.new(_then) : false))
      end

      backup_files = resources.select do |_resource|
        !(File.directory?(_resource) || (_resource =~ /node_modules/) || (_resource =~ /__CS__/) || (_then ? _resource =~ Regexp.new(_then) : false) || (_resource =~ /readme/i))
      end

      cs_files = resources.select do |_resource|
        !(File.directory?(_resource) || (_then ? _resource =~ Regexp.new(_then) : false)) && _resource =~ /__CS__/
      end

      backup_folders.each do |f|
        do_backup_and_copy(f, backup_folder(swserver), swserver, resource, true);
      end

      backup_files.each do |f|
        do_backup_and_copy(f, backup_folder(swserver), swserver, resource, false)
      end

      cs_folders.each do |f|
        do_backup_and_copy(f, backup_folder(swserver), core_services, resource, true);
      end

      cs_files.each do |f|
        do_backup_and_copy(f, backup_folder(swserver), core_services, resource, false)
      end
      @backup_folder
    end

    def csreg(node)
      case node['kernel']['machine']
        when 'i386'
          'HKEY_LOCAL_MACHINE\SOFTWARE\HORNBILL\CORE SERVICES'
        when 'x86_64'
          'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432NODE\HORNBILL\CORE SERVICES'
        else
          'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432NODE\HORNBILL\CORE SERVICES'
      end
    end

    def swreg(node)
      case node['kernel']['machine']
        when 'i386'
          'HKEY_LOCAL_MACHINE\SOFTWARE\HORNBILL\SUPPORTWORKS SERVER'
        when 'x86_64'
          'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432NODE\HORNBILL\SUPPORTWORKS SERVER'
        else
          'HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432NODE\HORNBILL\SUPPORTWORKS SERVER'
      end
    end

    def hornbill_reg(node)
      reg = csreg(node).split('\\')
      reg.pop
      reg.join('\\')
    end

    def install_path(which, node)
      case which
        when 'cs'
          case node['kernel']['machine']
            when 'i386'
              'C:\Program Files\Hornbill\Core Services'
            when 'x86_64'
              'C:\Program Files (x86)\Hornbill\Core Services'
            else
              'C:\Program Files\Hornbill\Core Services'
          end
        when 'sw'
          case node['kernel']['machine']
            when 'i386'
              'C:\Program Files\Hornbill\Supportworks Server'
            when 'x86_64'
              'C:\Program Files (x86)\Hornbill\Supportworks Server'
            else
              'C:\Program Files\Hornbill\Supportworks Server'
          end
        else
          raise "Unknown option provided for which #{which} expected 'sw' or 'cs'"
      end
    end

    def repo_from_version(which, version, media = nil)
      version = pad_version(version)
      case which
        when 'cs'
          if media.nil?
            "https://files.hornbill.com/coreservices/R_CS_#{version.join('_')}/CsSetup.msi"
          else
            "#{media}/CsSetup.msi"
          end
        when 'sw'
          if media.nil?
            "https://files.hornbill.com/supportworks/R_SW_#{version.join('_')}/SwSetup.exe"
          else
            "#{media}/SwSetup.exe"
          end
        else
          raise "Unknown option provided for which #{which} expected 'sw' or 'cs'"
      end
    end

    def pad_version(version)
      version = version.split('.')
      while version.length < 3
        version.push '0'
      end
      version
    end

    def base_version(version)
      version[0]
    end

    def file_join(str, *args)
      File.join(str, args)
    end

    def ps_script(script)
      # call the automation process
      Thread.new { system("powershell -ExecutionPolicy ByPass -File #{script.gsub('/', "\\")}") }
    end

    def create_option_string(args = {})
      options = ''
      args.each do |key, val|
        if val.nil?
          options += "/#{key} "
        else
          if val.is_a? Numeric
            options += "#{key}=#{val} "
          else
            options += "#{key}=\"#{val}\" "
          end
        end
      end
      options.strip
    end

    def checksum_from_version(which, version)
      case which
        when 'cs'
          case version
            #todo implement other version checksums
            when '6.0'
              return 'b587d6ac5048c639d9cd014a2befaec32790a3d8b6ee4840e9e37c7ef2455048'
            else
              return ''
          end
        when 'sw'
          #todo implement sw checksums
        else
          raise "Unknown option provided for which #{which} expected 'sw' or 'cs'"
      end
    end

    def zapp_version(version)
      version = pad_version(version)
      case version
        when %w(8 1 0)
          return 'ITSM_Default_410.zapp'
        when %w(8 2 0)
          return 'ITSM_Default_421.zapp'
        else
          raise "Cannot find default zapp file for Supportworks version #{version}"
      end
    end

    def is_uri(str)
      require 'uri'
      /\A#{URI::regexp}\z/ =~ str ? true : false
    end

    def zapp_from_repo(version, media)
      unless media.nil?
        return File.join(media, zapp_version(version))
      end
      "https://github.com/richbai90/BTI_Zapps/blob/master/#{zapp_version(version)}?raw=true"
    end

    def get_path(path, which, node)
      (path.to_s == 'default') ? install_path(which, node) : path
    end

    def license_server(path, license)
      File.open(*Dir[File.join(path, '*.lic').gsub!('\\', '/')], 'wb') do |f|
        f.write(license)
      end
    end

    def get_sysid(path, which, node)
      path = get_path(path, which, node)
      File.basename(*Dir[File.join(path, '*.lic').gsub('\\', '/')]).split('.')[0]
    end

    def precopy_itsm(basepath)
      require('fileutils')
      files = Dir[basepath.gsub('\\', '/') + '/**/*'].select do |file|
        !((file =~ /\/itsm_default\/|\/ITSM_Default\//).nil? || File.directory?(file))
      end

      itsm_files = files.map do |file|
        file.gsub('itsm_default', 'itsm').gsub('ITSM_Default', 'ITSM')
      end

      itsm_files.each_with_index do |file, i|
        FileUtils.mkdir_p File.dirname(file)
        FileUtils.cp(files[i], file)
      end
      nil
    end

  end
end