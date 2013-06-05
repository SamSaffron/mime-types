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

  s.add_development_dependency(%q<minitest>, ["~> 4.7"])
  s.add_development_dependency(%q<rdoc>, ["~> 4.0"])
  s.add_development_dependency(%q<hoe-bundler>, ["~> 1.2"])
  s.add_development_dependency(%q<hoe-doofus>, ["~> 1.0"])
  s.add_development_dependency(%q<hoe-gemspec2>, ["~> 1.1"])
  s.add_development_dependency(%q<hoe-git>, ["~> 1.5"])
  s.add_development_dependency(%q<hoe-rubygems>, ["~> 1.0"])
  s.add_development_dependency(%q<hoe-travis>, ["~> 1.2"])
  s.add_development_dependency(%q<nokogiri>, ["~> 1.5"])
  s.add_development_dependency(%q<rake>, ["~> 10.0"])
  s.add_development_dependency(%q<hoe>, ["~> 3.6"])
end
