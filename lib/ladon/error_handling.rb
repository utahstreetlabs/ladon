require 'active_support/concern'
require 'airbrake'
require 'ladon/logging'

module Ladon
  module ErrorHandling
    extend ActiveSupport::Concern
    include Ladon::Logging

    module ClassMethods
      def handle_error(error_class, exception_or_message, parameters = {})
        notify_opts = {parameters: parameters}
        if exception_or_message.is_a?(Exception)
          exception = exception_or_message
        else
          exception = Exception.new(exception_or_message)
          notify_opts[:error_class] = error_class
        end
        logger.error(stringify_exception(error_class, exception_or_message))
        Airbrake.notify(exception, notify_opts)
      end

      def handle_warning(error_class, exception_or_message)
        logger.warn(stringify_exception(error_class, exception_or_message))
      end

      def with_error_handling(message, parameters = {}, &block)
        parameters = parameters.dup
        begin
          yield
        rescue Exception => e
          retry_count = parameters.delete(:retry_count) || 0
          if (retry_count > 0)
            logger.warn(%Q/Operation "#{message}" failed, retrying #{retry_count} more times/)
            with_error_handling(message, parameters.merge(retry_count: retry_count-1), &block)
          else
            additionally = parameters.delete(:additionally)
            handle_error(message, e, parameters)
            additionally.call if additionally
          end
        end
      end

      protected
        def stringify_exception(error_class, exception_or_message)
          if exception_or_message.is_a?(Exception)
            "#{error_class}: #{exception_or_message.message}\n#{exception_or_message.backtrace.join("\n")}"
          else
            "#{error_class}: #{exception_or_message}"
          end
        end
    end
  end
end
