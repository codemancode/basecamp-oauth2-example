module Launchpad
  class Basecamp < Sinatra::Base

    YAML::load(File.open('config/basecamp.yml'))['config'].each do |k,v|
      set k, v
    end

    set :views, 'views'
    set :raise_errors, Proc.new { false }

    enable :sessions, :logging

    # this must be set since we are using shotgun for request reloading
    set :session_secret, "My session secret"

    before do
      session[:oauth] ||= {}
      
      @client = client
  
      if !session[:oauth][:access_token].nil?
        @token = OAuth2::AccessToken.new(@client, 
                                         session[:oauth][:access_token], 
                                         {:refresh_token => session[:oauth][:refresh_token],
                                         :expires_at => session[:oauth][:expires_at],
                                         :expires_in => session[:oauth][:expires_in]})
        
         if @token.expired?
           @token = @token.refresh!(:refresh_token => @token.refresh_token, :type => 'refresh')
         end
      end
    end

    get '/' do
      if @token
        @companies = @token.get('https://launchpad.37signals.com/authorization.json').parsed
      end
      erb :index
    end

    get '/auth/basecamp' do
      redirect client.auth_code.authorize_url(:type => 'web_server',
                                              :redirect_uri => redirect_uri)
    end

    get settings.callback_url do
      if params[:code] != nil
        @token = client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri, :type => 'web_server')
        session[:oauth][:access_token] = @token.token
        session[:oauth][:refresh_token] = @token.refresh_token
        session[:oauth][:expires_at] = @token.expires_at
        session[:oauth][:expires_in] = @token.expires_in
        redirect '/'
      else
        raise "General Error"
      end
    end

    error do
      "error: #{request.env['sinatra.error'].to_s}"
    end

    def client
      OAuth2::Client.new(settings.client_id, settings.client_secret, {
        :site => 'https://launchpad.37signals.com',
        :token_url => '/authorization/token',
        :authorize_url => 'authorization/new'
      })
    end

    def redirect_uri
      uri = URI.parse(request.url)
      uri.path = settings.callback_url
      uri.query = nil
      uri.to_s
    end

  end

end