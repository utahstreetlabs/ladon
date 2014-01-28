require 'active_support/core_ext/module/delegation'

module Ladon
  module Context
    extend ActiveSupport::Concern

    delegate :ladon_context, :mixpanel_context, to: 'self.class'

    module ClassMethods
      def ladon_context
        Thread.current[:ladon_context] ||= {}
      end

      def clear_ladon_context!
        Thread.current[:ladon_context] = {}
      end
    end
  end
end
