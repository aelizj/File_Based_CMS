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
  
  def test_index
    create_document("about.md")
    create_document("changes.txt")

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

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

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.ext does not exist"

    get "/"
    refute_includes last_response.body, "notafile.ext does not exist"
  end
  
  def test_viewing_markdown_file
    create_document("about.md" , "# Header")

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Header"
  end

  def test_editing_file
    create_document("changes.txt")

    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(button type="submit")
  end

  def test_updating_file
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status
    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_add_file
    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_create_new_file
    post "/create", filename: "test.txt"
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been created"

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_new_file_without_filename
    post "/create", filename: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_deleting_file
    create_document("test.txt")

    post "test.txt/delete"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been deleted"

    get "/"
    refute_includes last_response.body, "test.txt"
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "Welcome"
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "1234"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_logout
    post "/users/login", username: "admin", password: "secret"
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"

    post "/users/signout"
    get last_response["Locataion"]
    
    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Login"
  end
end
