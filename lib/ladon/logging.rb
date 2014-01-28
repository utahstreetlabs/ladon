require 'active_support/concern'
require 'logger'

module Ladon
  class << self
    def default_logger
      defined?(Rails) ? Rails.logger : ::Logger.new($stdout)
    end

    def logger
      @logger = default_logger unless defined?(@logger)
      @logger
    end

    def logger=(logger)
      @logger = logger
    end
  end

  module Logging
    extend ActiveSupport::Concern

    def logger
      self.class.logger
    end

    module ClassMethods
      def logger
        Ladon.logger
      end
    end
  end
end
