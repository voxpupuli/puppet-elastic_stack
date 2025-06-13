# frozen_string_literal: true

Puppet::Type.type(:elastic_stack_keystore).provide(
  :elastic_stack_keystore
) do
  desc 'Provider for both `elasticsearch-keystore` and `kibana-keystore` based secret management.'

  mk_resource_methods

  def self.defaults_dir
    @defaults_dir ||= case Facter.value(:os)['family']
                      when 'RedHat'
                        '/etc/sysconfig'
                      else
                        '/etc/default'
                      end
  end

  def self.root_dir
    @root_dir ||= case Facter.value(:os)['family']
                  when 'OpenBSD'
                    '/usr/local'
                  else
                    '/usr/share'
                  end
  end

  def self.home_dir_kibana
    @home_dir_kibana ||= File.join(root_dir, 'kibana')
  end

  def self.home_dir_elasticsearch
    @home_dir_elasticsearch ||= File.join(root_dir, 'elasticsearch')
  end

  def self.elastic_keystore_password_file
    keystore_env = get_envvar('elasticsearch', 'ES_KEYSTORE_PASSPHRASE_FILE')
    @elastic_keystore_password_file ||= keystore_env.empty? ? "#{configdir('elasticsearch')}/.elasticsearch-keystore-password" : keystore_env
  end

  def self.elastic_keystore_password(password = '')
    if File.file?(elastic_keystore_password_file)
      @elastic_keystore_password ||= File.open(elastic_keystore_password_file, &:readline).strip
    else
      @elastic_keystore_password = password.empty? ? @elastic_keystore_password : password
    end
  end

  def self.elastic_keystore_password_file_bak
    @elastic_keystore_password_file_bak ||= "#{elastic_keystore_password_file}.puppet-bak"
  end

  def self.elastic_keystore_password_bak
    @elastic_keystore_password_bak ||= File.file?(elastic_keystore_password_file_bak) ? File.open(elastic_keystore_password_file_bak, &:readline).strip : ''
  end

  attr_accessor :defaults_dir, :root_dir, :home_dir_kibana, :home_dir_elasticsearch, :elastic_keystore_password_file, :elastic_keystore_password, :elastic_keystore_password_file_bak, :elastic_keystore_password_bak

  optional_commands kibana_keystore: "#{home_dir_kibana}/bin/kibana-keystore"
  optional_commands elasticsearch_keystore: "#{home_dir_elasticsearch}/bin/elasticsearch-keystore"

  def self.run_keystore(args, service, stdin = nil)
    options = {
      uid: service.to_s,
      gid: service.to_s,
      failonfail: true
    }

    password = case service
               when 'elasticsearch'
                 File.file?(elastic_keystore_password_file_bak) ? elastic_keystore_password_bak : elastic_keystore_password
               else
                 ''
               end

    cmd = [command("#{service}_keystore")]
    if args[0] == 'create' || args[0] == 'has-passwd'
      options[:failonfail] = false
      options[:combine] = true
    elsif args[0] == 'passwd'
      options[:combine] = true
      stdin = File.file?(elastic_keystore_password_file_bak) ? "#{elastic_keystore_password_bak}\n#{elastic_keystore_password}\n#{elastic_keystore_password}" : "#{elastic_keystore_password}\n#{elastic_keystore_password}"
    end

    unless args[0] == 'passwd' || args[0] == 'has-passwd'
      stdin = stdin.nil? ? password : "#{password}\n#{stdin}"
    end

    unless stdin.nil?
      stdinfile = Tempfile.new("#{service}-keystore")
      stdinfile << stdin
      stdinfile.flush
      options[:stdinfile] = stdinfile.path
    end

    begin
      stdout = execute(cmd + args, options)
    ensure
      unless stdin.nil?
        stdinfile.close
        stdinfile.unlink
      end
    end

    if stdout.exitstatus.zero?
      stdout
    else
      options[:failonfail] ? raise(Puppet::Error, stdout) : stdout
    end
  end

  def self.present_keystores(configdir, service, password = '')
    keystore_file = File.join(configdir, "#{service}.keystore")
    if File.file?(keystore_file)
      current_password = case service
                         when 'elasticsearch'
                           if passwd?(service) && File.file?(elastic_keystore_password_file_bak)
                             elastic_keystore_password_bak
                           elsif passwd?(service)
                             elastic_keystore_password(password.value)
                           else
                             elastic_keystore_password(password.value)
                             ''
                           end
                         else
                           ''
                         end
      settings = {}
      run_keystore(['list'], service).split("\n").each do |setting|
        settings[setting] = service == 'kibana' ? '' : run_keystore(['show', setting], service)
      end
      [{
        name: service,
        ensure: :present,
        provider: name,
        settings: settings,
        password: current_password,
      }]
    else
      []
    end
  end

  def self.configdir(service)
    dir = get_envvar(service, '(ES|KBN)_PATH_CONF')
    if dir.empty?
      File.join('/etc', service)
    else
      dir
    end
  end

  def self.get_envvar(service, env)
    defaults_file = File.join(defaults_dir, service)
    val = ''
    if File.file?(defaults_file)
      File.readlines(defaults_file).each do |line|
        next if line =~ %r{^#}

        key, value = line.split '='
        val = value.gsub(%r{"}, '').strip if key =~ %r{#{env}}
      end
    end
    val
  end

  def self.instances(password = '')
    keystores = []
    %w[kibana elasticsearch].each do |service|
      keystores.concat(present_keystores(configdir(service), service, password))
    end
    keystores.map do |keystore|
      new keystore
    end
  end

  def self.passwd?(service)
    has_passwd = run_keystore(['has-passwd'], service).split("\n").last
    has_passwd.match?(%r{^Keystore is password-protected})
  end

  def self.keystore_password_management(service)
    if passwd?(service)
      run_keystore(['passwd'], service) unless elastic_keystore_password_bak.strip.empty? || elastic_keystore_password == elastic_keystore_password_bak
    else
      run_keystore(['passwd'], service) unless elastic_keystore_password.empty?
    end
  end

  def self.prefetch(resources)
    password = resources.key?(:elasticsearch) ? resources[:elasticsearch].parameters[:password] : ''
    keystores = instances(password)
    resources.each_key do |name|
      provider = keystores.find { |keystore| keystore.name.to_sym == name }
      resources[name].provider = provider if provider
    end
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def flush
    configdir = self.class.configdir(resource[:service].to_s)
    service = resource[:service].to_s

    case @property_flush[:ensure]
    when :present
      debug(self.class.run_keystore(['create', '-s'], service, 'N'))
      @property_flush[:settings] = resource[:settings]
    when :absent
      File.delete(File.join([
                              configdir, "#{resource[:service]}.keystore"
                            ]))
      return
    end

    # Note that since the property is :array_matching => :all, we have to
    # expect that the hash is wrapped in an array.
    if @property_flush.key?(:settings) && !(@property_flush[:settings].empty? && @property_hash.nil? && @property_hash[:settings].nil?)
      # Flush properties that _should_ be present
      @property_flush[:settings].each do |setting, value|
        next if @property_hash.key?(:settings) && @property_hash[:settings].key?(setting) \
          && @property_hash[:settings][setting] == value

        args = ['add', '--force']
        args << '--stdin' if service == 'kibana'
        args << setting
        debug(self.class.run_keystore(args, service, value))
      end

      # Remove properties that are no longer present
      if resource[:purge]
        (@property_hash[:settings].keys.sort - @property_flush[:settings].keys.sort).each do |setting|
          debug(self.class.run_keystore(
                  ['remove', setting], service
                ))
        end
      end
    end

    keystore_settings = {}
    self.class.run_keystore(['list'], service).split("\n").each do |setting|
      keystore_settings[setting] = service == 'kibana' ? '' : self.class.run_keystore(['show', setting], service)
    end

    # if service == 'elasticsearch' && @property_flush.key?(:password)
    if service == 'elasticsearch'
      # set and update keystore password if needed
      self.class.keystore_password_management(service)
      # unlink backup file containing keystore password (synced)
      File.unlink(self.class.elastic_keystore_password_file_bak) if File.file?(self.class.elastic_keystore_password_file_bak)
    end

    @property_hash = {
      name: service,
      ensure: :present,
      provider: resource[:name],
      settings: keystore_settings,
      password: self.class.elastic_keystore_password,
    }
  end

  # settings property setter
  #
  # @return [Hash] settings
  def settings=(new_settings)
    @property_flush[:settings] = new_settings
  end

  # settings property getter
  #
  # @return [Hash] settings
  def settings
    @property_hash[:settings]
  end

  # settings property setter
  #
  # @return [String] password
  def password=(new_password)
    @property_flush[:password] = new_password
  end

  # settings property getter
  #
  # @return [Hash] password
  def password
    @property_hash[:password]
  end

  # Sets the ensure property in the @property_flush hash.
  #
  # @return [Symbol] :present
  def create
    @property_flush[:ensure] = :present
  end

  # Determine whether this resource is present on the system.
  #
  # @return [Boolean]
  def exists?
    @property_hash[:ensure] == :present
  end

  # Set flushed ensure property to absent.
  #
  # @return [Symbol] :absent
  def destroy
    @property_flush[:ensure] = :absent
  end
end
