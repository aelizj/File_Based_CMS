ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "rack/test"

require_relative "../cms.rb"



class AppTest < MiniTest::Test #?----------------------------------------------
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end


  def setup
    FileUtils.mkdir_p(data_path)
  end


  def teardown
    FileUtils.rm_rf(data_path)
  end


  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end


  def session
    last_request.env["rack.session"]

    # def test_sets_session_value
    #   get "/path_that_sets_session_value"
    #   assert_equal "expected value", session[:key]
    # end
  end


  def admin_session
    { "rack.session" => { username: "admin" } }
  end
  

  def test_index
    create_document("about.md")
    create_document("changes.txt")

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end


##GETTING FILES
  def test_get_file
    create_document("history.txt", "Pothos")

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Pothos"
  end


  def test_get_nonexistent_file
    get "/notafile.ext"
    assert_equal 302, last_response.status
    assert_equal "notafile.ext does not exist", session[:error]
  end
  

  def test_viewing_markdown_file
    create_document("about.md" , "# Header")

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Header"
  end


## EDITING FILES
  def test_editing_file
    create_document("changes.txt")

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(button type="submit")
  end



  def test_editing_file_logged_out
    create_document("changes.txt")

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:error]
  end



  def test_updating_file
    post "/changes.txt", {content: "new content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:success]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end



  def test_updating_file_logged_out
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:error]
  end


## CREATING FILES
  def test_view_add_file_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_add_file_form_logged_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:error]
  end
  

  def test_create_file
    post "/create", {filename: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been created.", session[:success]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_file_logged_out
    post "/create", {filename: "test.txt"}
    
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:error]
  end

  def test_new_file_without_filename
    post "/create", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

## DELETING FILES
  def test_deleting_file
    create_document("test.txt")

    post "test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted", session[:success]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_deleting_file_logged_out
    create_document("test.txt")

    post "test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that", session[:error]
  end


## LOGIN & LOGOUT
  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end


  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end


  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "1234"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
  end


  def test_logout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have been signed out", session[:success]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Login"
  end
end
