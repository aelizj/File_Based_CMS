require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"


## CONFIG----------------------------------------------------------------------
configure do
  enable :sessions
  set :session_secret, 'very secret secret'
  set :erb, :escape_html => true
end

root = File.expand_path("..", __FILE__)

## METHODS---------------------------------------------------------------------
# Returns specific path based on environment
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
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

## BEFORE----------------------------------------------------------------------
before do 
  @files = Dir.glob(File.join(data_path, "*")).map { |path| File.basename(path) }
end

## ROUTES----------------------------------------------------------------------
# Load home page
get "/" do
  pattern = File.join(data_path, "*")
  erb :index, layout: :layout
end

# Add a new file
get "/new" do
  erb :new, layout: :layout
end

# Create new file
post "/create" do
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


# User login
post "/users/signin" do
  if params[:username] == "admin" && params[:password] == "secret"
    session[:username] = params[:username]
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid credentials"
    status 422
    erb :signin
  end  
end


# User logout
post "/users/signout" do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect "/"
end




# View a specific file
get "/:filename" do
  file_path = File.join(data_path, params[:filename])
  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end
# Edit an existing file
get "/:filename/edit" do

  file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)
  
  erb :edit, layout: :layout
end

# Update an existing file #!  could use validation
post "/:filename" do
  file_path = File.join(data_path, params[:filename])
  
  File.write(file_path, params[:content])

  session[:success] = "#{params[:filename]} has been updated."
  redirect "/"
end 

post "/:filename/delete" do
  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)

  session[:success] = "#{params[:filename]} has been deleted "
  redirect "/"
end
