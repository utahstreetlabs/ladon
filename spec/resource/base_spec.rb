require 'spec_helper'

describe Ladon::Resource::Base do
  before { Ladon::Resource::Base.base_url = 'http://test.host:12345' }

  it "queues a request" do
    url = Ladon::Resource::Base.absolute_url('/songs/1')
    title = 'Brothers in Arms'
    Ladon.hydra.stub(:get, url).and_return(stub_response(title))
    Ladon::Resource::Base.queue_request(url) do |data|
      data['title'].should == title
    end
    Ladon.hydra.run
  end

  it "fires a get" do
    url = Ladon::Resource::Base.absolute_url('/songs/1')
    title = 'Didgeridoo Madness'
    Typhoeus::Hydra.hydra.stub(:get, url).and_return(stub_response(title))
    data = Ladon::Resource::Base.fire_get(url)
    data['title'].should == title
  end

  it "fires a get with a query" do
    url = Ladon::Resource::Base.absolute_url('/songs/1', params: {volume: 'loud'})
    title = 'Didgeridoo Madness'
    Typhoeus::Hydra.hydra.stub(:get, url).and_return(stub_response(title))
    data = Ladon::Resource::Base.fire_get('/songs/1', params: {volume: 'loud'})
    data['title'].should == title
  end

  it "fires a post" do
    url = Ladon::Resource::Base.absolute_url('/songs')
    title = 'Swingset Chain'
    Typhoeus::Hydra.hydra.stub(:post, url).and_return(stub_response(title, 201))
    data = Ladon::Resource::Base.fire_post(url, {:title => title})
    data['title'].should == title
  end

  it "fires a put" do
    url = Ladon::Resource::Base.absolute_url('/songs/1')
    title = 'Blue Balloon'
    Typhoeus::Hydra.hydra.stub(:put, url).and_return(stub_response(title))
    data = Ladon::Resource::Base.fire_put(url, {:title => title})
    data['title'].should == title
  end

  it "fires a delete" do
    url = Ladon::Resource::Base.absolute_url('/songs/1')
    Typhoeus::Hydra.hydra.stub(:delete, url).and_return(stub_response(nil, 204))
    data = Ladon::Resource::Base.fire_delete(url)
    data.should be_nil
  end

  it "fires a patch" do
    url = Ladon::Resource::Base.absolute_url('/songs/1')
    title = 'Blue Balloon'
    Typhoeus::Hydra.hydra.stub(:patch, url).and_return(stub_response(title))
    data = Ladon::Resource::Base.fire_patch(url, [{:add => '/foo', :value => title}])
    data['title'].should == title
  end

  it "handles a success response" do
    title = 'Jump'
    Ladon::Resource::Base.expects(:handle_success_response).once
    Ladon::Resource::Base.handle_response(stub_response(title)) do |data|
      data['title'].should == title
    end
  end

  context 'error responses' do
    let(:code) { 0 }
    let(:response) { Typhoeus::Response.new(code: code) }
    let(:dd) { stub('data') }

    context 'with a timeout' do
      before do
        response.stubs(:timed_out?).returns(true)
        Ladon::Resource::Base.expects(:err).once
      end

      it 'handles it and returns default data' do
        expect(Ladon::Resource::Base.handle_response(response, default_data: dd)).to eq(dd)
      end

      it 'raises when asked' do
        expect { Ladon::Resource::Base.handle_response(response, raise_on_error: true) }.
          to raise_exception(Ladon::Resource::TimeoutException)
      end
    end

    context "with a failed response" do
      before { Ladon::Resource::Base.expects(:err).once }

      it 'handles it and returns default data' do
        expect(Ladon::Resource::Base.handle_response(response, default_data: dd)).to eq(dd)
      end

      it 'raises when asked' do
        expect { Ladon::Resource::Base.handle_response(response, raise_on_error: true) }.
          to raise_exception(Ladon::Resource::FailureException)
      end
    end

    context 'with a server error' do
      let(:code) { 500 }
      before { Ladon::Resource::Base.expects(:err).once }

      it 'handles it and returns default data' do
        expect(Ladon::Resource::Base.handle_response(response, default_data: dd)).to eq(dd)
      end

      it 'raises when asked' do
        expect { Ladon::Resource::Base.handle_response(response, raise_on_error: true) }.
          to raise_exception(Ladon::Resource::ServerError)
      end
    end

    context 'with a client error' do
      let(:code) { 400 }
      before { Ladon::Resource::Base.expects(:wrn).once }

      it 'handles it and returns default data' do
        expect(Ladon::Resource::Base.handle_response(response, default_data: dd)).to eq(dd)
      end

      it 'raises when asked' do
        expect { Ladon::Resource::Base.handle_response(response, raise_on_error: true) }.
          to raise_exception(Ladon::Resource::ClientError)
      end
    end

    context 'with an unacceptable entity' do
      let(:response) do
        Typhoeus::Response.new(code: 500, headers_hash: {'Content-Type' => 'text/plain'}, body: 'HI')
      end
      before { Ladon::Resource::Base.expects(:err).once }

      it 'handles it and returns default data' do
        expect(Ladon::Resource::Base.handle_response(response, default_data: dd)).to eq(dd)
      end

      it 'raises when asked' do
        expect { Ladon::Resource::Base.handle_response(response, raise_on_error: true) }.
          to raise_exception(Ladon::Resource::UnacceptableEntityException)
      end
    end
  end

  it "absolutizes path" do
    Ladon::Resource::Base.absolute_url('/songs/1').should =~ /^#{Ladon::Resource::Base.base_url}/
  end

  it 'leaves absolute url untouched' do
    url = "#{Ladon::Resource::Base.base_url}/songs/1"
    Ladon::Resource::Base.absolute_url(url).should == url
  end

  it "adds query string to url" do
    url = "#{Ladon::Resource::Base.base_url}/songs/1?foo=bar&foo=baz"
    Ladon::Resource::Base.absolute_url('/songs/1', params: {foo: ['bar', 'baz']}).should == url
  end

  it "adds escapes url unsafe params in the query string" do
    url = "#{Ladon::Resource::Base.base_url}/songs/1?foo%5B%5D=bar%5D&foo%5B%5D=baz%5B"
    Ladon::Resource::Base.absolute_url('/songs/1', params: {'foo[]' => ['bar]', 'baz[']}).should == url
  end

  it "encodes an entity" do
    Ladon::Resource::Base.encode_entity({foo: 'bar'}).should == %Q/{"foo":"bar"}/
  end

  it "parses an entity" do
    Ladon::Resource::Base.parse_entity(%Q/{"foo":"bar"}/).should == {'foo' => 'bar'}
  end

  it "silences a silenced error" do
    url = Ladon::Resource::Base.absolute_url('/404')
    Typhoeus::Hydra.hydra.stub(:get, url).and_return(Typhoeus::Response.new(code: 404))
    Ladon::Resource::Base.expects(:err).never
    Ladon::Resource::Base.fire_get(url)
  end

  it "logs an unsilenced error" do
    url = Ladon::Resource::Base.absolute_url('/502')
    Typhoeus::Hydra.hydra.stub(:get, url).and_return(Typhoeus::Response.new(code: 502))
    Ladon::Resource::Base.expects(:err)
    Ladon::Resource::Base.fire_get(url)
  end

  it "parses a media type with parameters" do
    media_type = "text/html; charset=Shift-JIS"
    Ladon::Resource::Base.parse_media_type(media_type).should == ['text/html', {charset: 'Shift-JIS'}]
  end

  it "parses a media type with outparameters" do
    media_type = "application/octet-stream"
    Ladon::Resource::Base.parse_media_type(media_type).should == ['application/octet-stream']
  end

  describe '#field_params' do
    it 'should return a filled hash when the needed option is provided' do
      Ladon::Resource::Base.field_params(fields: [:lat, :lng]).should == {'fields[]' => ['lat', 'lng']}
    end

    it 'should return an empty hash when the needed option is not provided' do
      Ladon::Resource::Base.field_params({}).should == {}
    end
  end

  describe '#mapped_params' do
    it 'should return a filled hash when the needed option is provided' do
      Ladon::Resource::Base.mapped_params(params_map: {foo: :f, bar: :b}, foo: 123, bar: [:schmoo, :zoo]).
        should == {"f" => "123", "b[]" => ["schmoo", "zoo"]}
    end

    it 'should return an empty hash when the needed option is not provided' do
      Ladon::Resource::Base.mapped_params({}).should == {}
    end
  end

  describe '#pager' do
    it 'should return the provided pager in preference to any other options' do
      pager = Ladon::Pager.new
      Ladon::Resource::Base.pager(pager: pager, page: 1, per: 25).should == pager
    end

    it 'should return a pager when :paged is provided' do
      Ladon::Resource::Base.pager(paged: true).should be_a(Ladon::Pager)
    end

    it 'should return a pager when :page is provided' do
      Ladon::Resource::Base.pager(page: 5).should be_a(Ladon::Pager)
    end

    it 'should return a pager when :per is provided' do
      Ladon::Resource::Base.pager(per: 3).should be_a(Ladon::Pager)
    end

    it 'should not return a pager when no known options are provided' do
      Ladon::Resource::Base.pager({}).should be_nil
    end
  end

  describe '#paged_data' do
    it 'should return a paged array of transformed results when a mapping function is provided' do
      pager = Ladon::Pager.new
      data = {results: [:foo, :bar], total: 5}
      paged_data = Ladon::Resource::Base.paged_data(pager, data, results_mapper: lambda {|x| x.to_s})
      paged_data.should be_a(Ladon::PaginatableArray)
      paged_data.total_count.should == 5
      paged_data.should == ['foo', 'bar']
    end

    it 'should return a paged array of the original results when no mapping function is provided' do
      pager = Ladon::Pager.new
      data = {results: [:foo, :bar], total: 5}
      paged_data = Ladon::Resource::Base.paged_data(pager, data)
      paged_data.should be_a(Ladon::PaginatableArray)
      paged_data.total_count.should == 5
      paged_data.should == [:foo, :bar]
    end
  end

  def stub_response(title = nil, code = 200)
    body = title ? %Q/{"title":"#{title}"}/ : nil
    headers = {}
    headers['Content-Type'] = Ladon::Resource::ENCODED_MEDIA_TYPE_JSON if body
    Typhoeus::Response.new(:code => code, :headers_hash => headers, :body => body, :time => 0.3)
  end
end
