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

#! ROUTES----------------------------------------------------------------------
# Load home page
get "/" do
  pattern = File.join(data_path, "*")
  erb :index, layout: :layout
end

# Add a new file
get "/new" do
  erb :new, layout: :layout
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



# Create new file
post "/" do
  if params[:new_file].nil?
    session[:error] = "Invalid"
    erb :new, layout: :layout
  else
    # @files << params[:new_file]
    # session[:success] = "#{params[:new_file]} was created."
    redirect "/"
  end
end
