# Chronos Ruby

Chronos Ruby will be the official Chronos client for Ruby applications. The project is in its initial stage and will serve as the foundation for exception capture, telemetry, and observability in legacy applications.

This initial commit contains only the gem structure. Event capture and delivery have not been implemented yet.

## Requirements

- Ruby 2.2.10 through Ruby 2.6
- RubyGems 2.0 or later
- Bundler 1.17

## Dependencies

The gem has no runtime dependencies at this initial stage.

The development environment uses:

- `bundler ~> 1.17`: dependency management and gem packaging
- `rake ~> 10.0`: project task execution
- `rspec ~> 3.0`: test execution
- `IRB`: interactive console provided by the Ruby standard library

## Local development

After cloning the repository, open the project directory and install the Bundler version used by the legacy branch:

```bash
gem install bundler -v 1.17.3
```

Install the dependencies:

```bash
bin/setup
```

Open a console with the gem loaded:

```bash
bin/console
```

Run the tests:

```bash
bundle _1.17.3_ exec rake
```

Install the local version of the gem in the current Ruby environment:

```bash
bundle _1.17.3_ exec rake install
```

After installation, load the library with:

```ruby
require "chronos/ruby"

Chronos::VERSION
```

## Installation from RubyGems

When the first version is published on RubyGems, add the gem to the application's `Gemfile`:

```ruby
gem "chronos-ruby"
```

Then install the dependencies with the Bundler version used by the project:

```bash
bundle _1.17.3_ install
```

To install the gem without Bundler:

```bash
gem install chronos-ruby
```

## License

Chronos Ruby is distributed under the terms of the MIT License.
