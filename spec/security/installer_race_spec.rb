require "tmpdir"
require "fileutils"
require "chronos/deploy/installer"
require "chronos/deploy/secure_directory"

RSpec.describe "Descriptor-anchored deploy installation" do
  around do |example|
    Dir.mktmpdir do |base|
      @root = File.join(base, "customer espaço with spaces")
      @outside = File.join(base, "outside")
      FileUtils.mkdir_p(File.join(@root, ".kamal/hooks"))
      FileUtils.mkdir_p(@outside)
      example.run
    end
  end

  def install(force = false)
    Chronos::Deploy::Installer.new.install(:root => @root, :provider => "kamal", :force => force)
  end

  def swap_parent
    parent = File.join(@root, ".kamal/hooks")
    File.rename(parent, File.join(@root, ".kamal/hooks-original"))
    File.symlink(@outside, parent)
  end

  it "does not create external directories when a parent is replaced before mkdirat" do
    FileUtils.rmdir(File.join(@root, ".kamal/hooks"))
    allow(Chronos::Deploy::SecureDirectory::Native).to receive(:mkdirat).and_wrap_original do |native, *args|
      parent = File.join(@root, ".kamal")
      File.rename(parent, File.join(@root, ".kamal-original"))
      File.symlink(@outside, parent)
      native.call(*args)
    end

    install

    expect(Dir.entries(@outside) - %w(. ..)).to eq([])
    expect(File.file?(File.join(@root, ".kamal-original/hooks/post-deploy"))).to eq(true)
  end

  [:linkat, :renameat].each do |operation|
    it "does not redirect #{operation} when the parent changes immediately before commit" do
      sentinel = File.join(@outside, "post-deploy")
      File.write(sentinel, "external sentinel")
      allow(Chronos::Deploy::SecureDirectory::Native).to receive(operation).and_wrap_original do |native, *args|
        swap_parent
        native.call(*args)
      end

      install(operation == :renameat)

      expect(File.read(sentinel)).to eq("external sentinel")
      expect(File.file?(File.join(@root, ".kamal/hooks-original/post-deploy"))).to eq(true)
      expect(Dir.entries(@outside) - %w(. ..)).to eq(["post-deploy"])
    end
  end

  it "rejects a symlink introduced after directory creation but before opening it" do
    FileUtils.rmdir(File.join(@root, ".kamal/hooks"))
    allow(Chronos::Deploy::SecureDirectory::Native).to receive(:mkdirat).and_wrap_original do |native, *args|
      status = native.call(*args)
      swap_parent
      status
    end

    expect { install }.to raise_error(Chronos::Deploy::Error)
    expect(Dir.entries(@outside) - %w(. ..)).to eq([])
  end

  it "preserves a customer file created concurrently with an exclusive installation" do
    target = File.join(@root, ".kamal/hooks/post-deploy")
    allow(Chronos::Deploy::SecureDirectory::Native).to receive(:linkat).and_wrap_original do |native, *args|
      File.write(target, "customer content")
      native.call(*args)
    end

    expect { install }.to raise_error(Chronos::Deploy::Error)
    expect(File.read(target)).to eq("customer content")
    expect(Dir.glob(File.join(@root, ".kamal/hooks/.chronos-deploy-*"))).to eq([])
  end
end
