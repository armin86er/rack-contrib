require 'minitest/autorun'
require 'rack/mock'
require 'rack/contrib/lazy_conditional_get'

$lazy_conditional_get_cache = {}

describe 'Rack::LazyConditionalGet' do

  def core_app
    lambda { |env| [200, core_app_headers, ['data']] }  
  end

  def core_app_headers
    { 
      'Content-Type' => 'text/plain', 
      'Rack-Lazy-Conditional-Get' => rack_lazy_conditional_get 
    } 
  end

  def rack_lazy_conditional_get; 'yes'; end

  def app
    Rack::LazyConditionalGet.new core_app, cache_object
  end

  def env env_headers={}
    Rack::MockRequest.env_for path, env_headers
  end

  def path; '/'; end
  def cache_object; $lazy_conditional_get_cache; end

  def global_last_modified
    cache_object[Rack::LazyConditionalGet::KEY]
  end

  def set_global_last_modified val
    cache_object[Rack::LazyConditionalGet::KEY] = val
  end

  def request_with_stamp stamp=nil
    myapp = app
    myenv = case stamp
            when nil
              {}
            when :up_to_date
              {'HTTP_IF_MODIFIED_SINCE' => global_last_modified}
            else
              {'HTTP_IF_MODIFIED_SINCE' => stamp}
            end
    myapp.call(env(myenv))
  end
  def request_without_stamp
    request_with_stamp nil
  end

  describe 'When the resource has Rack-Lazy-Conditional-Get' do

    it 'Should set right headers' do
      status, headers, body = request_without_stamp
      status.must_equal 200
      headers['Rack-Lazy-Conditional-Get'].must_equal 'yes'
      headers['Last-Modified'].must_equal global_last_modified
    end

    describe 'When the resource already has a Last-Modified header' do

      def core_app_headers
        super.merge({'Last-Modified' => (Time.now-3600).httpdate})
      end

      it 'Does not update Last-Modified with the global one' do
        status, headers, body = request_without_stamp
        status.must_equal 200
        headers['Rack-Lazy-Conditional-Get'].must_equal 'yes'
        headers['Last-Modified'].wont_equal global_last_modified
      end

    end

    describe 'When loading a resource for the second time' do

      def core_app; lambda { |env| raise }; end

      it 'Should not render resource the second time' do
        status, headers, body = request_with_stamp :up_to_date
        status.must_equal 304
      end

    end

  end

  describe 'When a request is potentially changing data' do

    it 'Updates the global_last_modified' do
      myapp = app
      set_global_last_modified (Time.now-3600).httpdate
      stamp = global_last_modified
      status, headers, body = myapp.call(env({'REQUEST_METHOD' => 'POST'}))
      global_last_modified.wont_equal stamp
    end

    describe 'When the skip header is returned' do
      
      def core_app_headers
        super.merge({'Rack-Lazy-Conditional-Get' => 'skip'})
      end

      it 'Does not update the global_last_modified' do
        myapp = app
        set_global_last_modified (Time.now-3600).httpdate
        stamp = global_last_modified
        status, headers, body = myapp.call(env({'REQUEST_METHOD' => 'POST'}))
        headers['Rack-Lazy-Conditional-Get'].must_equal 'skip'
        global_last_modified.must_equal stamp
      end

    end

  end

  describe 'When the ressource does not have Rack-Lazy-Conditional-Get' do

    def rack_lazy_conditional_get; 'no'; end

    it 'Should set right headers' do
      status, headers, body = request_without_stamp
      status.must_equal 200
      headers['Rack-Lazy-Conditional-Get'].must_equal 'no'
      headers['Last-Modified'].must_be :nil?
    end

  end

end
