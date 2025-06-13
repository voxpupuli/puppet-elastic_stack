# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'elastic_stack::repo' do
  context 'with defaults' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'elastic_stack::repo': }
        PUPPET
      end
    end
  end
end
