
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "chronos/ruby/version"

Gem::Specification.new do |spec|
  spec.name          = "chronos-ruby"
  spec.version       = Chronos::VERSION
  spec.authors       = ["Antonio Jefferson"]
  spec.email         = ["antoniojeferson96@gmail.com"]

  spec.summary       = "Cliente Ruby para captura de eventos do Chronos"
  spec.description   = "Base do cliente Chronos para excecoes, telemetria e observabilidade em aplicacoes Ruby legadas."
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.2.10", "< 2.7")

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
