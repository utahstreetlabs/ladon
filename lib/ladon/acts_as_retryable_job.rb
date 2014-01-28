require 'active_support'
require 'resque-retry'

module Ladon
  module ActsAsRetryableJob
    extend ActiveSupport::Concern

    module ClassMethods
      def acts_as_retryable_job(options = {})
        @retry_limit = options[:limit] || 3
        @retry_delay = options[:delay] || 60
        @retry_exceptions = options[:exceptions] || []
        self.send :extend, Resque::Plugins::Retry
      end
    end
  end
end
