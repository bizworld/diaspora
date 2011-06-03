require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'httparty'
require 'json'

def resource_host
  url = "http://localhost:"
  if ENV["DIASPORA_PORT"]
    url << ENV["DIASPORA_PORT"]
  else
    url << "3000"
  end
  url
end

@@client_id = nil
@@client_secret = nil
RESOURCE_HOST = resource_host

enable :sessions

helpers do
  def redirect_uri
    "http://" + request.host_with_port + "/callback" << "?diaspora_handle=#{params['diaspora_handle']}"
  end

  def access_token
    session[:access_token]
  end

  def get_with_access_token(path)
    HTTParty.get('http://' + domain_from_handle + path, :query => {:oauth_token => access_token})
  end

  def authorize_url
    "http://" + domain_from_handle + "/oauth/authorize?client_id=#{@@client_id}&client_secret=#{@@client_secret}&redirect_uri=#{redirect_uri}"
  end

  def token_url
    "http://" + domain_from_handle + "/oauth/token"
  end

  def access_token_url
    "http://" + domain_from_handle + "/oauth/access_token"
  end
end

get '/' do
  haml :home
end

get '/callback' do
  unless params["error"]

   if(params["client_id"] && params["client_secret"])
      @@client_id = params["client_id"]
      @@client_secret = params["client_secret"]
      redirect '/account'

    else
      response = HTTParty.post(access_token_url, :body => {
        :client_id => @@client_id,
        :client_secret => @@client_secret,
        :redirect_uri => redirect_uri,
        :code => params["code"],
        :grant_type => 'authorization_code'}
      )

      session[:access_token] = response["access_token"]
      redirect "/account?diaspora_handle=#{params['diaspora_handle']}"
    end
  else
    "What is your major malfunction?"
  end
end

get '/account' do
  if !@@client_id && !@@client_secret
    register_with_pod
  end

  if access_token
    @resource_response = get_with_access_token("/api/v0/me")
    haml :response
  else
    redirect authorize_url
  end
end

get '/manifest' do
  {
    :name => "Chubbies",
    :description => "Chubbies tests Diaspora's OAuth capabilities.",
    :homepage_url => "http://" + request.host_with_port,
    :icon_url => "http://" + request.host_with_port + "/chubbies.jpeg"
  }.to_json
end

get '/reset' do
  @@client_id = nil
  @@client_secret = nil
end


#=============================
#helpers
#
def domain_from_handle
 m = params['diaspora_handle'].match(/\@(.+)/) 
 m = m[1] if m
end

def register_with_pod
  response = HTTParty.post(token_url, :body => {
    :type => :client_associate,
    :manifest_url => "http://" + request.host_with_port + "/manifest"
  })

  json = JSON.parse(response.body)

  @@client_id = json["client_id"]
  @@client_secret = json["client_secret"]
end


