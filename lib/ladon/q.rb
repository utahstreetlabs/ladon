require 'active_support/concern'
require 'active_support/core_ext/module/attribute_accessors'
require 'ladon/error_handling'
require 'ladon/context'
require 'resque'

module Ladon
  mattr_accessor :q, instance_writer: false
  @@q = Resque

  class Q
    include Ladon::ErrorHandling

    class << self
      # Enqueues a background job, passing it the remainder of the arguments. If the job cannot be enqueued, logs an
      # error and notifies Airbrake.
      def enqueue(job_class, *args)
        with_error_handling("Unable to enqueue #{job_class} job", args: args) do
          Ladon.q.enqueue(job_class, *args)
        end
      end

      # Enqueues a scheduled background job, passing it the remainder of the arguments. If the job cannot be enqueued,
      # logs an error and notifies Airbrake.
      def enqueue_in(delay, job_class, *args)
        with_error_handling("Unable to enqueue #{job_class} job", args: args) do
          Ladon.q.enqueue_in(delay, job_class, *args)
        end
      end

      # Enqueues a scheduled background job, passing it the remainder of the arguments. If the job cannot be enqueued,
      # logs an error and notifies Airbrake.
      def enqueue_at(time, job_class, *args)
        with_error_handling("Unable to enqueue #{job_class} job", args: args) do
          Ladon.q.enqueue_at(time, job_class, *args)
        end
      end

      # Enqueues a background job to a custom queue (not the one defined by the job), passing it the remainder of the
      # arguments. If the job cannot be enqueued, logs an error and notifies Airbrake.
      def enqueue_to(queue, job_class, *args)
        with_error_handling("Unable to enqueue #{job_class} job", args: args) do
          Ladon.q.enqueue_to(queue, job_class, *args)
        end
      end
    end
  end
end
