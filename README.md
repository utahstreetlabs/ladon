# Ladon

Ladon is a framework for HTTP service clients. It uses the [Typhoeus](https://github.com/dbalatero/typhoeus) library to make parallel requests to the server. It converts the JSON data returned from the server to objects based on Active Model.

As Ladon is built atop Typhoeus, it seems fitting that we name it after one of the giant's famed descendents, the [dragon](http://en.wikipedia.org/wiki/Ladon_\(mythology\)) which guarded the golden apples in the garden of the Hesperides and was slain by Heracles.

## Usage

    require 'ladon'

    Ladon.hydra = Typhoeus::Hydra.new
    Ladon.logger = Logger.new(*STDOUT)

    class Song < Ladon::Resource::Base
      set_base_url 'http://localhost:12345'

      # Finds all songs, yielding them to the provided block
      def self.find(&block)
        queue_request('/songs', default_data: []) do |data|
          yield(data.map {|attrs| Ladon::Model.new(attrs)}) if block_given?
        end
      end

      # Creates and returns a song.
      def self.create(attrs = {})
        song = nil
        fire_post('/songs, attrs) { |data| song = Ladon::Model.new(data) }
        song
      end

      # Deletes a song.
      def self.delete(id)
        fire_delete("/songs/#{id}")
      end
    end

    Song.find do |songs|
      songs.each do |song|
        puts "#{song.title}"
      end
    end
    Ladon::Config.hydra.run

    Song.create(title: 'Skeletons') do |song|
      puts "Created #{song.title}"
    end

## Resources

Resources are conceptually similar to Active Record's models and Active Resource's resources. A resource provides a higher level interface to a server resource. It can either queue up a request to be sent later, perhaps in parallel with other requests to the same service or others, or it can fire off a request immediately and wait on the response.

Since this library is so new, there are many limitations to the resource API which will be removed over time. For example, while `#queue_request` hides the details of interacting with the Typhoeus pretty well, it only allows GET requests to be queued.

### Error handling

Ladon takes the approach that errors should be handled as gracefully as possible. If some specific piece of data isn't available, an application should still be able to build a web page, and application code shouldn't have to be peppered with lots of exception handlers.

For read requests, this typically means returning some default data that allows a consumer to continue along with any other operations it requires. For write requests, it means returning nil when a return value is expected or just silently failing.

Of course, Ladon does log all request timeouts, errors and non-success responses, but it doesn't make any provision for applications to react in detailed ways to these conditions. We'll see how well this design approach works out over time.

## Models

Models are simple value objects that can be used to provide safe access to the raw data returned from the service. Response entities are not automatically converted to value objects, although I can imagine adding some kind of factory registration capability eventually. It will probably also prove useful to add Active Model features like validations and callbacks sooner or later. For now, though, a model is basically just a struct with an accessor for each attribute.

## To do

* Retries
* Model validations
* Model callbacks
* Model type conversions
* Conditional requests (ETag, Last-Modified handling)
* Streamed request entity encoding
* Streamed response entity parsing

# Contributors

Since the git history was compacted, the awesome people responsible for this
codebase are listed below:

* [Brian Moseley](http://github.com/bcm)
* [Cutter Brown](http://github.com/cutter)
* [David LaMacchia](http://github.com/dlamacchia)
* [Ken Chong](http://github.com/kenchong)
* [Rob Zuber](http://github.com/z00b)
* [Travis Vachon](http://github.com/travis)
* [Zhihao Jia](http://github.com/zhihaojia)
