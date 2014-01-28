require 'ladon/error_handling'
require 'ladon/logging'
require 'ladon/q'
require 'ladon/acts_as_unique_job'
require 'ladon/acts_as_retryable_job'

module Ladon
  class Job
    include Ladon::Logging
    include Ladon::ErrorHandling
    include Ladon::ActsAsUniqueJob
    include Ladon::ActsAsRetryableJob
    include Ladon::Context

    # Extracts :ladon_context from named arguments, stashes it in the Ladon Context
    # and calls the #work method of the subclass
    def self.perform(*args)
      args = args.each { |arg| arg.recursive_symbolize_keys! if arg.respond_to?(:recursive_symbolize_keys!) }
      opts = args.extract_options!
      ladon_context.merge!(opts.delete(:ladon_context) || {})
      begin
        if opts.empty?
          work(*args)
        else
          work(*args, opts)
        end
      ensure
        clear_ladon_context!
      end
    end

    # override in subclasses to suppress ladon context passing
    def self.include_ladon_context?
      true
    end

    def self.add_ladon_context(args)
      opts = args.extract_options!
      opts[:ladon_context] = ladon_context if include_ladon_context?
      if opts.empty?
        args
      else
        args << opts
      end
    end

    def self.enqueue(*args)
      logger.debug("Enqueuing job #{self}: #{args.inspect}")
      Ladon::Q.enqueue(self, *add_ladon_context(args))
    end

    def self.enqueue_in(delay, *args)
      logger.debug("Scheduling delayed job #{self}: #{args.inspect} in #{delay} seconds")
      Ladon::Q.enqueue_in(delay, self, *add_ladon_context(args))
    end

    def self.enqueue_at(time, *args)
      logger.debug("Scheduling delayed job #{self}: #{args.inspect} at #{time}")
      Ladon::Q.enqueue_at(time, self, *add_ladon_context(args))
    end

    def self.enqueue_to(queue, *args)
      logger.debug("Enqueuing job #{self}: #{args.inspect} in queue #{queue}")
      Ladon::Q.enqueue_to(queue, self, *add_ladon_context(args))
    end
  end
end
