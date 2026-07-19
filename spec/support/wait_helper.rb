module WaitHelper
  def wait_until(timeout = 1.0)
    deadline = Time.now.to_f + timeout
    until yield
      raise "condition not reached" if Time.now.to_f >= deadline
      sleep(0.01)
    end
  end
end

RSpec.configure do |config|
  config.include WaitHelper
end
