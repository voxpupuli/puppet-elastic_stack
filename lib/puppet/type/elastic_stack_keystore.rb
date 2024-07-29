# frozen_string_literal: false

require 'puppet/parameter/boolean'

Puppet::Type.newtype(:elastic_stack_keystore) do
  desc 'Manages a keystore settings file (for either Elasticserach or Kibana service.'

  ensurable

  newparam(:service, namevar: true) do
    desc 'Service that manages the keystore (either "elasticsearch" or "kibana").'
    newvalues(:elasticsearch, :kibana)
    defaultto 'elasticsearch'
  end

  newparam(:purge, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc <<-EOS
      Whether to proactively remove settings that exist in the keystore but
      are not present in this resource's settings.
    EOS

    defaultto false
  end

  newproperty(:password) do
    desc 'Password to protect keystore.'

    defaultto ''

    def insync?(value)
      if resource[:service].to_s == 'kibana'
        true
      else
        value == @should.first
      end
    end
  end

  newproperty(:settings) do
    desc 'A key/value hash of settings names and values.'

    # The keystore utility can only retrieve a list of stored settings,
    # so here we only compare the existing settings (sorted) with the
    # desired settings' keys
    def insync?(value)
      if resource[:service].to_s == 'kibana'
        if resource[:purge]
          value.keys.sort == @should.first.keys.sort
        else
          (@should.first.keys.sort - value.keys.sort).empty?
        end
      elsif resource[:purge]
        value == @should.first
      elsif (@should.first.keys.sort - value.keys.sort).empty?
        # compare the values of keys in common
        (@should.first.values.sort - value.values.sort).empty?
      else
        false
      end
    end

    def is_to_s(value)
      debug("into is_to_s #{value}")
      # hide sensitive data
      value.to_h { |k, _| [k, 'xxxx'] }.inspect
    end

    def should_to_s(value)
      debug("into should_to_s #{value}")
      # hide sensitive data
      value.to_h { |k, _| [k, 'xxxx'] }.inspect
    end

    def change_to_s(currentvalue, newvalue)
      ret = ''

      added_settings = newvalue.keys - currentvalue.keys
      ret << "added: #{added_settings.join(', ')} " unless added_settings.empty?

      removed_settings = currentvalue.keys - newvalue.keys
      unless removed_settings.empty?
        ret << if resource[:purge]
                 "removed: #{removed_settings.join(', ')} "
               else
                 "would have removed: #{removed_settings.join(', ')}, but purging is disabled "
               end
      end

      changed = newvalue.map { |k, v| currentvalue[k] == v ? nil : k }.compact
      ret << "changed: #{changed.join(', ')}" unless changed.empty?

      ret
    end
  end

  autorequire(:augeas) do
    "defaults_#{self[:name]}"
  end
end
