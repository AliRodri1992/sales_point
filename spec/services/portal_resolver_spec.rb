# frozen_string_literal: true

RSpec.describe PortalResolver do
  describe '#path' do
    it 'resolves delta users to the Delta portal' do
      user = instance_double(User, user_type: 'delta')

      expect(described_class.new(user).path).to eq('/dashboard')
    end

    it 'resolves employee users to the organization admin portal' do
      user = instance_double(User, user_type: 'employee')

      expect(described_class.new(user).path).to eq('/admin/dashboard')
    end

    it 'rejects customer users until their portal is enabled' do
      user = instance_double(User, user_type: 'customer')

      expect { described_class.new(user).path }
        .to raise_error(PortalAccessDeniedError)
    end

    it 'rejects supplier users until their portal is enabled' do
      user = instance_double(User, user_type: 'supplier')

      expect { described_class.new(user).path }
        .to raise_error(PortalAccessDeniedError)
    end

    it 'rejects users with an unsupported type' do
      user = instance_double(User, user_type: 'unknown')

      expect { described_class.new(user).path }
        .to raise_error(PortalAccessDeniedError)
    end
  end
end
