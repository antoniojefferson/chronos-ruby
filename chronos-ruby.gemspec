
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "chronos/version"

Gem::Specification.new do |spec|
  spec.name          = "chronos-ruby"
  spec.version       = Chronos::VERSION
  spec.authors       = ["Antonio Jefferson"]
  spec.email         = ["antoniojeferson96@gmail.com"]

  spec.summary       = "Monitoramento de exceções, métricas e telemetria para Ruby e Rails"
  spec.description   = "Cliente oficial do Chronos para capturar e enviar exceções, métricas e " \
                       "dados de telemetria de aplicações Ruby e Rails. A gem centraliza sinais " \
                       "de observabilidade para facilitar o monitoramento, a análise de desempenho " \
                       "e o diagnóstico de falhas no Chronos Monitor. Conheça a plataforma oficial " \
                       "de recebimento e visualização dos dados em https://chronosmonitor.com.br."
  spec.homepage      = "https://github.com/antoniojefferson/chronos-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.2.10", "< 2.7")

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = spec.homepage
    spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir[
    "CHANGELOG.md",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "LICENSE.txt",
    "README.md",
    "SECURITY.md",
    "contracts/*.json",
    "docs/**/*.md",
    "lib/**/*.rb"
  ]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 12.3", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 0.49.0"
  spec.add_development_dependency "parallel", "1.19.2"
end
