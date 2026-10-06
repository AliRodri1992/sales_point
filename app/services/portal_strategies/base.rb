# frozen_string_literal: true

module PortalStrategies
  class Base
    def path
      raise NotImplementedError
    end
  end
end
