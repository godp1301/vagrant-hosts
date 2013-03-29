require 'vagrant'
require 'tempfile'


module VagrantHosts
class Provisioner < Vagrant.plugin('2', :provisioner)

  def initialize(machine, config)
    @machine, @config = machine, config
    p
  end

  def provision
    # too tired to do this. detect target platform, select according provider,
    # add entries that are specified in the config and are not on the client

    driver = Linux.new(@machine, @config)
    driver.sync!
  end

  class Linux

    def initialize(machine, config)
      @machine, @config = machine, config
    end

    def sync!
      upload_tmphosts
      update_hosts
    end

    private

    def upload_tmphosts
      cache = Tempfile.new('tmp-hosts')
      cache.write(format_hosts)
      cache.flush
      @machine.communicate.upload(cache.path, '/tmp/hosts')
    end

    def update_hosts
      @machine.guest.change_host_name(@machine.name.to_s)
      @machine.communicate.sudo('install -m 644 /tmp/hosts /etc/hosts')
    end

    # Generates content appropriate for a linux hosts file
    #
    # @return [String] All hosts in the config joined into hosts records
    def format_hosts
      all_hosts.inject('') do |str, (address, aliases)|
        str << "#{address} #{aliases.join(' ')}\n"
      end
    end

    def all_hosts
      all_hosts = []

      if @config.autoconfigure
        all_hosts += vagrant_hosts
      else
        all_hosts += @config.hosts
      end

      all_hosts.unshift(['127.0.0.1', ['localhost']])
      all_hosts.unshift(['127.0.1.1', [@machine.name]])
    end

    def vagrant_hosts
      hosts = []
      env = @machine.env
      names = env.machine_names

      # Assume that all VMs are using the current provider
      provider = @machine.provider

      names.each do |name|
        network_settings = env.machine(name, :virtualbox).config.vm.networks
        network_settings.each do |entry|
          if entry[0] == :private_network
            ipaddr = entry[1][:ip]
            hosts << [ipaddr, [name]]
          end
        end

        env_machine = env.machine(name, :openstack)
        os_network_settings = env_machine.ssh_info

        unless os_network_settings.nil?
          host = os_network_settings[:host]
          hosts << [host, [name]] if not nil?
        end
      end

      hosts
    end
  end
end
end
