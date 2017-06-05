module Supportworks
  module Helpers
    extend self

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

    def repo_from_version(which, version)
      version = pad_version(version)
      case which
        when 'cs'
          "https://files.hornbill.com/coreservices/R_CS_#{version.join('_')}/CsSetup.msi"
        when 'sw'
          "https://files.hornbill.com/supportworks/R_SW_#{version.join('_')}/SwSetup.exe"
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

    def zapp_from_repo(version)
      "https://github.com/richbai90/BTI_Zapps/blob/master/#{zapp_version(version)}?raw=true"
    end

    def get_path(path, which, node)
      (path.to_s == 'default') ? install_path(which, node) : path
    end

  end

end
