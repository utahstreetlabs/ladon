require 'resque/plugins/unique_job'

module Ladon
  module ActsAsUniqueJob
    extend ActiveSupport::Concern

    module ClassMethods
      def acts_as_unique_job(options = {})
        self.send :extend, Resque::Plugins::UniqueJob
      end
    end
  end
end
