require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"


#* CONFIG----------------------------------------------------------------------
configure do
  enable :sessions
  set :session_secret, 'very secret secret'
  set :erb, :escape_html => true
end

root = File.expand_path("..", __FILE__)

#* METHODS---------------------------------------------------------------------
# Returns specific path based on environment
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users/yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

# Given markdown text, returns HTML text 
def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

# Given a file path, returns file content
def load_file_content(path)
  content = File.read(path)
  
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def user_signed_in?
  session.key?(:username)
end

def restrict_access
  unless user_signed_in?
    session[:error] = "You must be signed in to do that"
    redirect "/"
  end
end

#* BEFORE----------------------------------------------------------------------
before do 
  @files = Dir.glob(File.join(data_path, "*")).map { |path| File.basename(path) }
end

#* ROUTES----------------------------------------------------------------------
# Load home page
get "/" do
  pattern = File.join(data_path, "*")
  erb :index, layout: :layout
end

# Add a new file
get "/new" do
  restrict_access
  erb :new, layout: :layout
end

# Create new file
post "/create" do
  restrict_access

  filename = params[:filename].to_s

  if filename.size == 0
    session[:error] = "A name is required"
    status 422
    erb :new, layout: :layout
  elsif File.extname(filename).empty?
    session[:error] = "Please enter a valid file name."
    status 422
    erb :new, layout: :layout
  elsif @files.include?(filename)
    session[:error] = "FIle name must be unique."
    status 422
    erb :new, layout: :layout
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    @files << filename
    session[:success] = "#{filename} has been created."
    redirect "/"
  end
end

# Render login form
get "/users/signin" do
  erb :signin, layout: :layout
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password = password
  else
    false
  end
end

# User login
post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :signin, layout: :layout
  end
end

# User logout
post "/users/signout" do
  session.delete(:username)
  session[:success] = "You have been signed out"
  redirect "/"
end

# View a specific file
get "/:filename" do
  file_path = File.join(data_path, File.basename(params[:filename]))
  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist"
    redirect "/"
  end
end

# Edit an existing file
get "/:filename/edit" do
  restrict_access

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)
  
  erb :edit, layout: :layout
end

# Update an existing file #!  could use validation
post "/:filename" do
  restrict_access
  file_path = File.join(data_path, params[:filename])
  
  File.write(file_path, params[:content])

  session[:success] = "#{params[:filename]} has been updated."
  redirect "/"
end 

# Delete an existing file
post "/:filename/delete" do
  restrict_access
  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)

  session[:success] = "#{params[:filename]} has been deleted"
  redirect "/"
end
