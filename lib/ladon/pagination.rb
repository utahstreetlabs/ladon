require 'active_support/core_ext/module/attribute_accessors'

module Ladon
  mattr_accessor :default_per_page, instance_writer: false
  @@default_per_page = 100

  # Simple helper that maps string paging options (+page+, +per+) to integral query parameters (+limit+,
  # +offset+). Model classes can use these to convert finder method options into a request parameters.
  # If +limit+ or +offset+ are passes as query parameters, these values take precendence over +page+ and +per+
  class Pager
    attr_accessor :offset, :limit, :page, :per, :pre_paged

    def initialize(options = {})
      @page = options.fetch(:page, 1).to_i
      @per = options.fetch(:per, Ladon.default_per_page).to_i
      @limit = options.fetch(:limit, @per).to_i
      @offset = options.fetch(:offset, @limit * ([@page, 1].max - 1)).to_i
      @pre_paged = options[:pre_paged]
    end

    def to_params
      if pre_paged
        {page: @page, per: @per}
      else
        {limit: @limit, offset: @offset}
      end
    end
  end

  # Ripped off of Kaminari::PaginatableArray - we can't use Kaminari directly because it drags in Rails and bunch of
  # other baggage we don't want. The important thing is that our paginatable array quacks like Kaminari's so that we
  # can use it like Kaminari's view helpers.
  class PaginatableArray < Array
    attr_reader :limit_value, :offset_value, :default_limit

    def initialize(original, options = {})
      @original = original
      @default_limit = options.fetch(:default_limit, Ladon.default_per_page)
      if options.include?(:pager)
        @offset_value = options[:pager].offset
        @limit_value = options[:pager].limit
      else
        @offset_value = options.fetch(:offset).to_i # usually comes in as a string
        @limit_value = options.fetch(:limit, default_limit).to_i # usually comes in as a string
      end
      @total_count = options[:total]
      if @total_count
        super(@original)
      else
        super(@original[@offset_value, @limit_value])
      end
    end

    def map(&block)
      mapped = super
      self.class.new(mapped, default_limit: self.default_limit, offset: self.offset_value, limit: self.limit_value,
        total: self.total_count)
    end

    def total_count
      @total_count || @original.size
    end

    def num_pages
      (total_count.to_f / limit_value) .ceil
    end

    def current_page
      (offset_value / limit_value) + 1
    end

    def first_page?
      current_page == 1
    end

    def last_page?
      current_page >= num_pages
    end
  end

  # Wraps a paged resource to treat it as a single contiguous collection.
  # Should be created with a block that expects a hash of paging parameters
  # including :per and :page and returns a Ladon::PaginatableArray.
  #
  # For example:
  # => Ladon::PaginatedCollection.new {|paging_opts| u.likes(paging_opts.merge(attr: [:listing_id], per: 5))}.
  #      map(&:listing_id)
  # >  [817, 816, 815, 818, 820, 821, 825, 823, 822, 827]
  class PaginatedCollection
    include Enumerable

    def initialize(&fetcher)
      @fetcher = fetcher
    end

    def each
      current_page = nil
      page = 1
      until current_page && current_page.last_page?
        current_page = @fetcher.call(page: page)
        current_page.each { |e| yield e }
        page += 1
      end
    end
  end
end
