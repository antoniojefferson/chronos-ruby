class FakeTransport
  attr_reader :events

  def initialize(results = nil, &delivery)
    @events = []
    @results = Array(results)
    @delivery = delivery
    @closed = false
    @mutex = Mutex.new
  end

  def send_event(event)
    @delivery.call(event) if @delivery
    @mutex.synchronize do
      @events << event
      @results.shift || Chronos::Ports::TransportResult.new(:success, :status_code => 202)
    end
  end

  def send_batch(events)
    events.map { |event| send_event(event) }
  end

  def healthy?
    !@closed
  end

  def close
    @closed = true
    true
  end
end

class RaisingTransport < FakeTransport
  def send_event(_event)
    raise "transport failed"
  end
end
