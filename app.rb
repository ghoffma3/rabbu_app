require 'bundler/setup'
require 'sinatra'
require 'oauth2'
require 'json'
require "net/http"
require "uri"

class SmartApp < Sinatra::Base
    # Our client ID and secret, used to get the access token
    CLIENT_ID = '3ca4bb57-753a-42bf-8cea-aa5ace621132'
    CLIENT_SECRET = '0f941e3d-cacb-40f0-9ea6-e8d9b65da3e0'
    
    # We'll store the access token in the session
    use Rack::Session::Pool, :cookie_only => false
    
    # This is the URI that will be called with our access
    # code after we authenticate with our SmartThings account
    redirect_uri = 'https://rabbu-app-ghoffma3.c9users.io/oauth/callback'
    
    # This is the URI we will use to get the endpoints once we've received our token
    endpoints_uri = 'https://graph.api.smartthings.com/api/smartapps/endpoints'
    
    options = {
      site: 'https://graph.api.smartthings.com',
      authorize_url: '/oauth/authorize',
      token_url: '/oauth/token'
    }
    
    # use the OAuth2 module to handle OAuth flow
    client = OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET, options)
    
    # helper method to know if we have an access token
    def authenticated?
      session[:access_token]
    end
    
    # handle requests to the application root
    get '/' do
      %(<a href="/authorize">Connect with SmartThings</a>)
    end
    
    # handle requests to /authorize URL
    get '/authorize' do
        url = client.auth_code.authorize_url(code: CLIENT_SECRET, client_id: CLIENT_ID, redirect_uri: redirect_uri, scope: 'app')
        redirect url
    end
    
    # handle requests to /oauth/callback URL. We
    # will tell SmartThings to call this URL with our
    # authorization code once we've authenticated.
    get '/oauth/callback' do
        codeToSend = params[:code]
        # Use the code to get the token.
        response = client.auth_code.get_token(codeToSend, client_id: CLIENT_ID, client_secret: CLIENT_SECRET, redirect_uri: redirect_uri)

        # now that we have the access token, we will store it in the session
        session[:access_token] = response.token
    
        # debug - inspect the running console for the
        # expires in (seconds from now), and the expires at (in epoch time)
        puts 'TOKEN EXPIRES IN ' + response.expires_in.to_s
        puts 'TOKEN EXPIRES AT ' + response.expires_at.to_s
        redirect '/getswitch'
    end
    
    # handle requests to the /getSwitch URL. This is where
    # we will make requests to get information about the configured
    # switch.
    get '/getswitch' do
      # If we get to this URL without having gotten the access token
      # redirect back to root to go through authorization
      if !authenticated?
        redirect '/'
      end
    
      token = session[:access_token]
    
      # make a request to the SmartThins endpoint URI, using the token,
      # to get our endpoints
      url = URI.parse(endpoints_uri)
      req = Net::HTTP::Get.new(url.request_uri)
    
      # we set a HTTP header of "Authorization: Bearer <API Token>"
      req['Authorization'] = 'Bearer ' + token
    
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")
    
      response = http.request(req)
      json = JSON.parse(response.body)
    
      # debug statement
      puts json
      
      # get the endpoint from the JSON:
      uri = json[0]['uri']

    '<h3>JSON Response</h3><br/>' + JSON.pretty_generate(json) + '<h3>Endpoint</h3><br/>' + uri
    end
end