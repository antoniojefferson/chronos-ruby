require "tmpdir"
require "rails/generators"
require "chronos"
require "generators/chronos/deploy/install/install_generator"

Dir.mktmpdir do |root|
  generator = Chronos::Generators::Deploy::InstallGenerator
  path = File.join(root, ".kamal/hooks/post-deploy")
  generator.start(["--provider=kamal", "--dry-run"], :destination_root => root)
  abort "dry-run wrote a hook" if File.exist?(path)
  generator.start(["--provider=kamal"], :destination_root => root)
  abort "hook missing" unless File.file?(path)
  original = File.read(path)
  generator.start(["--provider=kamal", "--check"], :destination_root => root)
  abort "check changed hook" unless original == File.read(path)
  abort "generator booted agent" if Chronos.configured?
end
