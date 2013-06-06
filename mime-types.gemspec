Gem::Specification.new do |s|
  s.name = "mime-types"
  s.version = "1.24.dev"

  s.authors = ["Charlie Somerville", "Austin Ziegler"]
  s.description = "This library allows for the identification of a file's likely MIME content type."
  s.summary = "This library allows for the identification of a file's likely MIME content type"

  s.email = ["charlie@charliesomerville.com"]
  s.files = `git ls-files`.split($/)
  s.homepage = "https://github.com/charliesome/mime-types"
  s.licenses = ["MIT", "Artistic 2.0", "GPL-2"]
  s.add_dependency("lru_redux", ["~> 0.0.6"])

  s.add_development_dependency("minitest", ["~> 4.7"])
  s.add_development_dependency("rake", ["~> 10.0"])
end
