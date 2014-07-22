require 'red_storm'
require 'protobuf'

class SampleProto < Protobuf::Message
  required :string, :my_str, 1
end

class HelloWorldSpout < RedStorm::DSL::Spout
  on_init {@words = ["hello", "world"] }
  on_send {@words.shift unless @words.empty?}
end

class HelloWorldBolt < RedStorm::DSL::Bolt
  output_fields :word

  on_receive :emit => false do |tuple|
    log.info "NAME: #{self.class}"
    log.info(tuple[0]) # tuple[:word] or tuple["word"] are also valid

    p = SampleProto.new(:my_str => 'some string')

    if ENV['TO_JAVA_OBJECT']
      s = p.encode.to_java_bytes.to_java_object # Works
    else
      s = p.encode.to_java_bytes # Doesn't work
    end

    anchored_emit(tuple, s)
    ack(tuple)
  end
end

class SecondBolt < RedStorm::DSL::Bolt
  on_receive :emit => false do |tuple|
    log.info "NAME: #{self.class}"
    pb = tuple[:word].to_s

    begin
      p = SampleProto.decode(pb.to_s)
    rescue => e
      log.error "E: #{e.inspect}"
    end

    ack(tuple)
  end
end

class HelloWorldTopology < RedStorm::DSL::Topology
  spout HelloWorldSpout do
    output_fields :word
  end

  bolt HelloWorldBolt do
    source HelloWorldSpout, :global
  end

  bolt SecondBolt do
    source HelloWorldBolt, :global
  end

  configure do
    debug false
    max_task_parallelism 4
    num_workers 1
    max_spout_pending 1000
  end
end
