require 'active_support/core_ext/module/attribute_accessors'
require 'ladon/error_handling'
require 'ladon/logging'
require 'log_weasel'
require 'typhoeus'
require 'yajl'

module Ladon
  mattr_accessor :hydra, instance_writer: false

  mattr_accessor :default_request_timeout, instance_writer: false
  @@default_request_timeout = 500 # ms

  module Resource
    class LadonResourceException < Exception; end
    class TimeoutException < LadonResourceException; end
    class FailureException < LadonResourceException; end
    class ClientError < LadonResourceException; end
    class ServerError < LadonResourceException; end
    class UnacceptableEntityException < LadonResourceException; end

    MEDIA_TYPE_JSON = 'application/json'
    ENCODED_MEDIA_TYPE_JSON = "#{MEDIA_TYPE_JSON}; charset=UTF-8"
    MEDIA_TYPE_JSON_PATCH = 'application/patch+json'
    ENCODED_MEDIA_TYPE_JSON_PATCH = "#{MEDIA_TYPE_JSON_PATCH}; charset=UTF-8"

    # The base class for client proxies to server resources. Subclasses provide wrapper methods that encapsulate the
    # communications with the server and the conversion of models and other data to and from the representations sent
    # over the wire (JSON objects).
    #
    # A number of class methods are provided to aid in communicating with the server. If an API wrapper method is meant
    # to queue up a request to be executed in parallel with other requests, the +#queue_request+ method can be used, and
    # a callback provided to be fired when the response returns. Synchronous requests can be made directly by the
    # client; in these cases, +#handle_request+ is handy for dealing with the various response states.
    class Base
      include Ladon::ErrorHandling
      include Ladon::Logging

      class << self
        attr_accessor :base_url

        # Sets the base url for this class. Note that it will not be inherited by subclasses.
        def set_base_url(url)
          base_url = url
        end

        # Builds a new HTTP request and adds it to the +Config.hydra+ request queue. Registers a callback that invokes
        # +#handle_response+ when the request completes. Recognizes the following options:
        #
        # +headers+ - a hash to add or update the request headers
        # +timeout+ - the timeout for the request (defaults to +Ladon.default_request_timeout+)
        # +default_data+ - passes this on to +#handle_response+
        def queue_request(url_or_path, options = {}, &block)
          url = absolute_url(url_or_path)
          headers = {:Accept => MEDIA_TYPE_JSON}.merge(options.fetch(:headers, {}))
          headers = merge_log_weasel_header(headers)
          timeout = options.fetch(:timeout, Ladon.default_request_timeout)
          request = Typhoeus::Request.new(url, headers: headers, timeout: timeout)
          request.on_complete do |response|
            handle_response(response, request: request, default_data: options[:default_data], &block)
          end
          Ladon.hydra.queue(request)
        end

        # Sends a synchronous GET request. On success, yields any returned data (as a paged array if paging was
        # requested). On error, yields any provided default data; if none was provided, yields an empty paged array
        # if paging was requested or +nil+ otherwise.
        #
        # See +#field_params+, +#mapped_params+, and +#pager# for additional options that can be provided to control
        # the behavior of this method. See +#paged_data+ for additional options that can be provided to control the
        # form of the returned data.
        #
        # @param [String] url_or_path the URL or path to send the request to - will be normalized to an absolute URL if
        # necessary
        # @param [Hash] options
        # @option options [Hash] :headers augments the basic request headers
        # @option options [Integer] :timeout (Ladon.default_request_timeout) the timeout for the request in
        #   milliseconds
        # @option options [Hash] :default_data the data to be returned whenever the request does not succeed (when
        #   paging is requested, defaults to +{total: 0, results: []})
        # @option options [Hash] :params pre-computed query string parameters added to the request URL via
        #   +#absolute_url#
        # @return [Ladon::PaginatableArray] when paging is requested
        # @return [Object] when paging is not requested
        def fire_get(url_or_path, options = {}, &block)
          params = options.fetch(:params, {})
          params.merge!(field_params(options))
          params.merge!(mapped_params(options))

          default_data = options[:default_data]
          pager = pager(options)
          if pager
            params.merge!(pager.to_params)
            default_data ||= {total: 0, results: []}
          end

          url = absolute_url(url_or_path, params: params)
          headers = options.fetch(:headers, {})
          headers = merge_log_weasel_header(headers)
          timeout = options.fetch(:timeout, Ladon.default_request_timeout)
          response = Typhoeus::Request.get(url, headers: headers, timeout: timeout)

          data = handle_response(response, method: :get, default_data: default_data, url: url, silence_errors: [404],
                                 raise_on_error: options[:raise_on_error], &block)
          pager ? paged_data(pager, data, options) : data
        end

        # Sends a synchronous POST request. On success, yields any returned data; on error, yields any provided default
        # data or +nil+. Recognizes the following options:
        #
        # +headers+ - a hash to add or update the request headers
        # +timeout+ - the timeout for the request (defaults to +Ladon.default_request_timeout+)
        # +default_data+ - passes this on to +#handle_response+
        def fire_post(url_or_path, entity, options = {}, &block)
          url = absolute_url(url_or_path)
          headers = {:Accept => MEDIA_TYPE_JSON, :'Content-type' => ENCODED_MEDIA_TYPE_JSON}.
            merge(options.fetch(:headers, {}))
          headers = merge_log_weasel_header(headers)
          timeout = options.fetch(:timeout, Ladon.default_request_timeout)
          body = encode_entity(entity)
          response = Typhoeus::Request.post(url, headers: headers, timeout: timeout, body: body)
          handle_response(response, method: :post, url: url, default_data: options[:default_data],
                          raise_on_error: options[:raise_on_error], &block)
        end

        # Sends a synchronous PUT request. On success, yields any returned data; on error, yields any provided default
        # data or +nil+. Recognizes the following options:
        #
        # +headers+ - a hash to add or update the request headers
        # +timeout+ - the timeout for the request (defaults to +Ladon.default_request_timeout+)
        # +default_data+ - passes this on to +#handle_response+
        def fire_put(url_or_path, entity, options = {}, &block)
          url = absolute_url(url_or_path)
          headers = {:Accept => MEDIA_TYPE_JSON, :'Content-type' => ENCODED_MEDIA_TYPE_JSON}.
            merge(options.fetch(:headers, {}))
          headers = merge_log_weasel_header(headers)
          timeout = options.fetch(:timeout, Ladon.default_request_timeout)
          body = encode_entity(entity)
          response = Typhoeus::Request.put(url, headers: headers, timeout: timeout, body: body)
          handle_response(response, method: :put, url: url, default_data: options[:default_data],
                          raise_on_error: options[:raise_on_error], &block)
        end

        # Sends a synchronous DELETE request. On success, yields any returned data; on error, yields any provided
        # default data or +nil+. Recognizes the following options:
        #
        # +headers+ - a hash to add or update the request headers
        # +timeout+ - the timeout for the request (defaults to +Ladon.default_request_timeout+)
        # +default_data+ - passes this on to +#handle_response+
        def fire_delete(url_or_path, options = {}, &block)
          params = options.fetch(:params, {})
          params.merge!(mapped_params(options))

          url = absolute_url(url_or_path, params: params)
          headers = {:Accept => MEDIA_TYPE_JSON}.merge(options.fetch(:headers, {}))
          headers = merge_log_weasel_header(headers)
          timeout = options.fetch(:timeout, Ladon.default_request_timeout)
          response = Typhoeus::Request.delete(url, headers: headers, timeout: timeout)
          handle_response(response, method: :delete, default_data: options[:default_data], url: url,
                          raise_on_error: options[:raise_on_error], &block)
        end

        # Sends a synchronous PATCH request. On success, yields any returned data; on error, yields any provided default
        # data or +nil+. Recognizes the following options:
        #
        # +headers+ - a hash to add or update the request headers
        # +timeout+ - the timeout for the request (defaults to +Ladon.default_request_timeout+)
        # +default_data+ - passes this on to +#handle_response+
        def fire_patch(url_or_path, entity, options = {}, &block)
          url = absolute_url(url_or_path)
          headers = {:Accept => MEDIA_TYPE_JSON, :'Content-type' => ENCODED_MEDIA_TYPE_JSON_PATCH}.
            merge(options.fetch(:headers, {}))
          headers = merge_log_weasel_header(headers)
          timeout = options.fetch(:timeout, Ladon.default_request_timeout)
          body = encode_entity(entity)
          response = Typhoeus::Request.run(url, headers: headers, timeout: timeout, body: body, method: :patch)
          handle_response(response, method: :patch, url: url, default_data: options[:default_data],
                          raise_on_error: options[:raise_on_error], &block)
        end

        # Negotiates the murky waters of HTTP response state. On success, parses the response body as a JSON object; on
        # timeout or error, uses the default data instead. If a block is given, the data is yielded to it, and the
        # block's return value is returned. IF no block is given, the data is returned directedly.
        #
        # Recognizes the following options:
        #
        # +request+ - the Typhoeus request (optional)
        # +method+ - the HTTP method, handy if no request is provided
        # +url+ - the request URL, handy if no request is provided
        # +default_data+ - yielded or returned in case of timeout or error
        # +silence_errors+ - an array or range of status codes for which errors are not logged
        def handle_response(response, options = {}, &block)
          request = options[:request]
          method = (request ? request.method : options[:method]) || '?'
          url = (request ? request.url : options[:url]) || '?'
          default_data = options[:default_data]
          default_data = HashWithIndifferentAccess.new(default_data) if default_data && default_data.is_a?(Hash)
          handler_options = {default_data: default_data, raise_on_error: options[:raise_on_error]}
          if response.timed_out?
            handle_timeout(response, method, url, handler_options, &block)
          elsif response.code == 0
            handle_failure(response, method, url, handler_options, &block)
          else
            if !has_entity?(response) || acceptable?(response)
              entity = parse_entity(response.body) if response.body
              if response.success?
                handle_success_response(response, method, url, entity, &block)
              else
                handler_options[:silence_errors] = options[:silence_errors]
                handle_error_response(response, method, url, entity, handler_options, &block)
              end
            else
              handle_unacceptable_entity(response, method, url, handler_options, &block)
            end
          end
        end

        def handle_timeout(response, method, url, options = {}, &block)
          err(method, url, response.time, nil, 'timed out')
          raise Ladon::Resource::TimeoutException.new if options[:raise_on_error]
          if block_given?
            yield(options[:default_data])
          else
            options[:default_data]
          end
        end

        def handle_failure(response, method, url, options = {}, &block)
          err(method, url, response.time, nil, "failed (#{response.curl_error_message})")
          raise Ladon::Resource::FailureException.new if options[:raise_on_error]
          if block_given?
            yield(options[:default_data])
          else
            options[:default_data]
          end
        end

        def handle_success_response(response, method, url, entity, &block)
          logger.info(trace_message(method, url, response.time))
          if block_given?
            yield(entity)
          else
            entity
          end
        end

        def handle_error_response(response, method, url, entity, options = {}, &block)
          is_client_error = response.code >= 400 && response.code <= 499
          if not (options[:silence_errors] and options[:silence_errors].include?(response.code))
            msg = is_client_error ? "returned a client error" : "returned a server error"
            msg += " (#{response.code})"
            msg += "[#{entity}]" if entity
            if is_client_error
              wrn(method, url, response.time, msg)
              raise Ladon::Resource::ClientError.new if options[:raise_on_error]
            else
              err(method, url, response.time, entity, msg)
              raise Ladon::Resource::ServerError.new if options[:raise_on_error]
            end
          end
          if block_given?
            yield(options[:default_data])
          else
            options[:default_data]
          end
        end

        def handle_unacceptable_entity(response, method, url, options = {}, &block)
          msg = "returned an unacceptable entity of type #{content_type(response)} (status #{response.code})"
          err(method, url, response.time, response.body, msg)
          raise Ladon::Resource::UnacceptableEntityException.new if options[:raise_on_error]
          if block_given?
            yield(options[:default_data])
          else
            options[:default_data]
          end
        end

        def trace_message(method, url, time, msg = nil)
          out = [method.upcase, url]
          out << msg if msg
          out << "[#{sprintf("%.02f", (time || 0) * 1000)} ms]"
          out.join(' ')
        end

        def err(method, url, response_time, content, msg)
          message = trace_message(method, url, response_time, msg)
          handle_error('Service error', message, content: content)
        end

        def wrn(method, url, response_time, msg)
          message = trace_message(method, url, response_time, msg)
          handle_warning('Service warning', message)
        end

        # Returns a copy of +headers+ that includes a LogWeasel header if a LogWeasel transaction is in progress.
        def merge_log_weasel_header(headers)
          if LogWeasel::Transaction.id
            headers.merge(LogWeasel::Middleware::KEY_HEADER => LogWeasel::Transaction.id)
          else
            headers
          end
        end

        # Returns the URL created by appending +url_or_path+ to the server's base URL, unless +url_or_path+ is alrady
        # absolute.
        def absolute_url(url_or_path, options= {})
          url = url_or_path =~ /^#{base_url}/ ? url_or_path : "#{base_url}#{url_or_path}"
          params = options.fetch(:params, {})
          query = params.inject([]) do |rv, param|
            rv.concat((param[1].is_a?(Array) ? param[1] : [param[1]]).map {|v| "#{uri_escape(param[0])}=#{uri_escape(v)}"})
            rv
          end
          url += "?#{query.join('&')}" if query.any?
          url
        end

        def uri_escape(s)
          URI.escape(s.to_s, /[^#{URI::REGEXP::PATTERN::UNRESERVED}]/)
        end

        # Encodes +entity_ as a JSON string.
        def encode_entity(entity)
          Yajl::Encoder.encode(entity)
        end

        def content_length(response)
          response.headers_hash.fetch('Content-Length', 0).to_i
        end

        def has_entity?(response)
          cl = content_length(response)
          cl > 0 || (response.body && response.body.size > 0)
        end

        def content_type(response)
          response.headers_hash.fetch('Content-Type', nil)
        end

        def acceptable?(response)
          ct = content_type(response)
          return false unless ct
          (type_subtype, parameters) = parse_media_type(ct)
          type_subtype == MEDIA_TYPE_JSON && (!parameters[:charset] || parameters[:charset] =~ /\Autf(\-?)8\Z/i)
        end

        # Converts +entity+ from a JSON string to an object.
        def parse_entity(entity)
          entity = Yajl::Parser.parse(entity)
          entity.is_a?(Hash) ? HashWithIndifferentAccess.new(entity) : entity
        end

        def parse_media_type(str)
          (type_subtype, parameters) = str.split(/\s*;\s*/)
          parts = [type_subtype]
          parts << parse_http_parameter_list(parameters) if parameters.present?
          parts
        end

        def parse_http_parameter_list(str)
          str.split(';').each_with_object({}) do |p, m|
            (a, v) = p.split('=')
            m[a.to_sym] = v
          end
        end

        # Returns query parameters specifying the fields to include in the objects returned from the server. Keys and
        # values of returned query parameters are strings regardless of input type.
        #
        # Example:
        #
        #    field_params(fields: [:lat, :lng])
        #    # => {"fields[]" => ["lat", "lng"]}
        #
        # Note that the query parameter keys and values are not encoded.
        #
        # @param [Hash] options
        # @option options [Array] :fields the names of the fields to include
        # @return [Hash] the computed query parameters
        def field_params(options)
          params = {}
          params['fields[]'] = options[:fields].map(&:to_s) if options[:fields]
          params
        end

        # Converts options into query parameters based on a map from option key to parameter key. The provided options hash must include a hash with the key
        # +:mapped_params+. For each entry in this hash, if +options+ provides an entry under that key, then a query
        # parameter is created with that key and the value from the +options+ entry. Keys and values are all strings
        # regardless of input type. If the value is an +Array+, then the query parameter key is suffixed with +[]}.
        #
        # Example:
        #
        #    mapped_params(params_map: {foo: :f, bar: :b}, foo: 123, bar: [:schmoo, :zoo])
        #    # => {"f" => "123", "b[]" => ["schmoo", "zoo"]}
        #
        # Note that the query parameter keys and values are not encoded.
        #
        # @param [Hash] options
        # @option options [Hash] :params_map maps option keys to parameter keys
        # @return [Hash] the computed query parameters
        def mapped_params(options)
          params = {}
          options.fetch(:params_map, {}).each_pair do |from, to|
            if options.include?(from)
              if options[from].is_a?(Array)
                params["#{to}[]"] = options[from].map(&:to_s)
              else
                params[to.to_s] = options[from].to_s
              end
            end
          end
          params
        end

        # Converts options to a pager. If none of the below described options is provided, returns +nil+.
        #
        # @param [Hash] options
        # @option options [Integer] :page specifies the (1-indexed) page number directly
        # @option options [Integer] :per specifies the number of results to be included in a page
        # @option options [Boolean] :paged signifies that paging should be performed with default options even if none
        #   were specified in +options+
        # @option options [Ladon::Pager] :pager an existing pager - overrides any other pagination options
        # @return [Ladon::Pager] the computed pager
        def pager(options)
          pager = if options.include?(:pager)
            options[:pager]
          elsif options[:paged] || options[:pre_paged] || options[:page].present? || options[:per].present?
            Ladon::Pager.new(options)
          end
        end

        # Packages the raw data extracted from a server response into a paged array. If an optional mapping function
        # is provided, it is used to transform each individual result. The mapping function is yielded an individual
        # results hash.
        #
        # Example:
        #
        #    paged_data(pager, data, results_mapper: lambda {|result| Thing.new(result)})
        #    # => Ladon::PaginatableArray of Things
        #
        # @param [Ladon::Pager] the pager describing the paging parameters used to compute the server response
        # @param data [Hash] the raw data from the server response in the standard paged results format
        # @option data [Array] :results the paged subset of results
        # @option data [Integer] :total the total number of matching results
        # @param [Hash] options
        # @option options [Proc] :results_mapper a function to call on each result value when paging is requested
        # @return [Ladon::PaginatableArray]
        def paged_data(pager, data, options = {})
          results = data[:results] || data[:collection]
          results = results.map {|d| options[:results_mapper].call(d)} if options.include?(:results_mapper)
          Ladon::PaginatableArray.new(results, pager: pager, total: data[:total])
        end
      end
    end
  end
end
