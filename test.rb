require "yaml"
require "bcrypt"

data = Psych.load_file("../File-based_CMS/users.yml")

p data
p data["anne"]

p BCrypt::Password.create(data["max"])