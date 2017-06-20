$:.unshift *Dir[File.expand_path('../../files/default/vendor/gems/**/lib', __FILE__)]
require 'zip'

module Supportworks
  module Helpers
    extend self

    require 'nokogiri'

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
        unless val.nil?
          if val.is_a? Numeric
            options += "#{key}=#{val}"
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
      File.open(*Dir[File.join(path,'*.lic').gsub!('\\', '/')], 'wb') do |f|
        f.write(license)
      end
    end

    def install_zapp(basepath, zapp)
      Zip::File.open(zapp) do |_zapp|
        _zapp.each do |entry|
          itsm_name = entry.name.gsub('\\','/').gsub('itsm_default', 'itsm').gsub('ITSM_Default', 'ITSM')
          default_name = entry.name.gsub('\\','/')
          itsm_fullpath = File.join(basepath, itsm_name)
          default_fullpath = File.join(basepath, default_name)
          itsm_dir = File.dirname(itsm_fullpath)
          default_dir = File.dirname(default_fullpath)
          FileUtils::mkdir_p(itsm_dir)
          FileUtils::mkdir_p(default_dir)
          File.open(itsm_fullpath, 'w') do |f|
            f.write(entry.get_input_stream.read)
          end
          File.open(default_fullpath, 'w') do |f|
            f.write(entry.get_input_stream.read)
          end
        end
      end
    end

  end

end

