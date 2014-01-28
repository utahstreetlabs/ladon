require 'active_model'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/date_time/conversions'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/time/zones'
require 'ladon/error_handling'
require 'ladon/logging'

# A base class for model objects that are persisted in remote services.
#
# Incorporates the following concerns from Active Model:
#
# * conversion
# * naming
# * serialization
# * validation
# * change tracking
#
# Model classes may define typecasting rules like so:
#
#   class Thing
#     attr_datetime :foo          # parses the value of foo as a DateTime
#     attr_symbol :bar            # parses the value of bar as a Symbol
#   end
#
# Attributes are defined by passing a hash of names and values into the constructor and/or by calling +attributes=+.
# Each attribute has accessor methods defined as per +attr_accessor+.
#
# The +id+ attribute is special in that it represents the unique identifer of the model. The id is assumed to be a
# UUID or other value that is naturally represented as a string rather than a number. The id value may be specified
# in an attributes hash as +_id+ as well. When the id attribute has a non-blank value, the model is considered to have
# been persisted by its owning service.
#
# The +created_at+ and +updated_at+ timestamp values are also supported out of the box.
#
# Using ActiveModel::Dirty, the model can then be checked if it's dirty by way of the +changed?+ method.
# This dirty bit is cleared automatically when the object is saved.  See ActiveModel::Dirty for more information.
module Ladon
  class Model
    include ActiveModel::Conversion
    extend ActiveModel::Naming
    include ActiveModel::Serialization
    include ActiveModel::Validations
    include ActiveModel::Dirty
    include Ladon::Logging
    include Ladon::ErrorHandling

    cattr_accessor :attr_datetimes, instance_writer: false
    @@attr_datetimes = []

    cattr_accessor :attr_symbols, instance_writer: false
    @@attr_symbols = []

    # Indicates that the values of these attributes should be cast to +DateTime+s
    def self.attr_datetime(*names)
      attr_datetimes.concat(names)
    end

    # Indicates that the values of these attributes should be cast to +Symbol+s
    def self.attr_symbol(*names)
      attr_symbols.concat(names)
    end

    attr_accessor :id, :created_at, :updated_at
    attr_datetime :created_at, :updated_at

    def initialize(attrs = {})
      @attributes = []
      @persisted = false
      set_attributes(attrs)
    end

    # Returns a hash of attribute names (as strings) and values
    def attributes
      @attributes.inject({}) {|rv, name| rv[name.to_s] = send(name); rv}
    end

    # Updates the specified attribute values
    def attributes=(attrs)
      set_attributes(attrs)
    end

    # Returns true if it has been determined that the model has been persisted to underlying storage. Currently this
    # is only true when an +_id+ attribute has been set.
    def persisted?
      @persisted
    end

    def save
      @changed_attributes.clear
    end

  private
    def read_attribute(name)
      instance_variable_get( "@#{name}" )
    end

    def write_attribute(name, val)
      self.send("#{name}_will_change!") unless val == self.send(name)
      instance_variable_set( "@#{name}", val)
    end

    def self.create_method(name, &block)
      self.send(:define_method, name, &block)
    end

    def self.create_attr_reader(name)
      create_method( name.to_sym ) do
        read_attribute(name)
      end
    end

    def self.create_attr_writer(name)
      define_attribute_method(name)
      create_method( "#{name}=".to_sym ) do |val|
        write_attribute(name, val)
      end
    end

    def set_attributes(attrs)
      attrs.each {|name, value| set_attribute(name, value)}
    end

    def set_attribute(name, value)
      name = name.to_sym

      if name == :_id && value.present?
        name = :id
        @persisted = true
      end

      if self.class.attr_datetimes.include?(name)
        if value.present?
          if value.is_a?(String)
            value = Time.zone.parse(value)
          elsif value.is_a?(Integer)
            value = Time.zone.at(value)
          end
          # If value is already a DateTime, perform no conversion.
        end
      elsif self.class.attr_symbols.include?(name)
        value = value.to_sym if value.present?
      end

      unless @attributes.include?(name)
        self.class.class_eval { create_attr_reader(name) } unless respond_to?(name)
        self.class.class_eval { create_attr_writer(name) } unless respond_to?("#{name}=".to_sym)
        @attributes << name
      end

      send("#{name}=", value)

      @attributes
    end

    # If we're passed a setter, go ahead and default back to creating the method on the fly.
    def method_missing(sym, *args, &block)
      m = sym.to_s.match /^([^=]+)=$/
      if m && m[1]
        set_attribute(m[1], *args)
      end
    end
  end
end
