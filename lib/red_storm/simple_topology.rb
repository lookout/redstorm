module RedStorm

  class SimpleTopology
    attr_reader :cluster # LocalCluster reference usable in on_submit block for example

    class BoltDefinition
      attr_reader :clazz, :parallelism
      attr_accessor :id, :sources

      def initialize(bolt_class, id, parallelism)
        @clazz = bolt_class
        @id = id
        @parallelism = parallelism
        @sources = []
      end

      def source(source_id, grouping)
        @sources << [source_id.is_a?(Class) ? SimpleTopology.underscore(source_id) : source_id, grouping.is_a?(Hash) ? grouping : {grouping => nil}]
      end

      def define_grouping(declarer)
        @sources.each do |source_id, grouping|
          grouper, params = grouping.first

          case grouper
          when :fields
            declarer.fieldsGrouping(source_id, Fields.new(*params))
          when :global
            declarer.globalGrouping(source_id)
          when :shuffle
            declarer.shuffleGrouping(source_id)
          when :none
            declarer.noneGrouping(source_id)
          when :all
            declarer.allGrouping(source_id)
          when :direct
            declarer.directGrouping(source_id)
          else
            raise("unknown grouper=#{grouper.inspect}")
          end
        end
      end
    end

    class SpoutDefinition
      attr_reader :clazz, :parallelism
      attr_accessor :id

      def initialize(spout_class, id, parallelism)
        @clazz = spout_class
        @id = id
        @parallelism = parallelism
      end
    end

    class Configurator
      attr_reader :config

      def initialize
        @config = Config.new
      end

      def method_missing(sym, *args)
        config_method = "set#{self.class.camel_case(sym)}"
        @config.send(config_method, *args)
      end

      private

      def self.camel_case(s)
        s.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      end
    end


    def self.spout(spout_class, options = {})
      spout_options = {:id => self.underscore(spout_class), :parallelism => 1}.merge(options)
      spout = SpoutDefinition.new(spout_class, spout_options[:id], spout_options[:parallelism])
      self.components << spout
    end

    def self.bolt(bolt_class, options = {}, &bolt_block)
      bolt_options = {:id => self.underscore(bolt_class), :parallelism => 1}.merge(options)
      bolt = BoltDefinition.new(bolt_class, bolt_options[:id], bolt_options[:parallelism])
      bolt.instance_exec(&bolt_block)
      self.components << bolt
    end

    def self.configure(name = nil, &configure_block)
      @topology_name = name if name
      @configure_block = configure_block if block_given?
    end

    def self.on_submit(method_name = nil, &submit_block)
      @submit_block = block_given? ? submit_block : lambda {|env| self.send(method_name, env)}
    end

    # topology proxy interface

    def start(base_class_path, env)
      self.class.resolve_ids!(self.class.components)

      builder = TopologyBuilder.new
      self.class.spouts.each do |spout|
         builder.setSpout(spout.id, JRubySpout.new(base_class_path, spout.clazz.name), spout.parallelism)
      end
      self.class.bolts.each do |bolt|
        declarer = builder.setBolt(bolt.id, JRubyBolt.new(base_class_path, bolt.clazz.name), bolt.parallelism)
        bolt.define_grouping(declarer)
      end

      configurator = Configurator.new
      configurator.instance_exec(env, &self.class.configure_block)
 
      case env
      when :local
        @cluster = LocalCluster.new
        @cluster.submitTopology(self.class.topology_name, configurator.config, builder.createTopology)
      when :cluster
        StormSubmitter.submitTopology(self.class.topology_name, configurator.config, builder.createTopology);
      else
        raise("unsupported env=#{env.inspect}, expecting :local or :cluster")
      end

      instance_exec(env, &self.class.submit_block)
    end

    private

    def self.resolve_ids!(components)
      next_numeric_id = 1
      resolved_names = {}

      numeric_components, symbolic_components = components.partition{|c| c.id.is_a?(Fixnum)}
      numeric_ids = numeric_components.map(&:id)

      # map unused numeric ids to symbolic ids
      symbolic_components.each do |component|
        id = component.id.to_s
        raise("duplicate symbolic id in #{component.clazz.name} on id=#{id}") if resolved_names.has_key?(id)
        next_numeric_id += 1 while numeric_ids.include?(next_numeric_id)
        numeric_ids << next_numeric_id
        resolved_names[id] = next_numeric_id
      end

      # reassign numeric ids in all components
      components.each do |component|
        unless component.id.is_a?(Fixnum)
          component.id = resolved_names[component.id.to_s] || raise("cannot resolve #{component.clazz.name} id=#{component.id.to_s}")
        end
        if component.respond_to?(:sources)
          component.sources.map! do |source_id, grouping|
            id = source_id.is_a?(Fixnum) ? source_id : resolved_names[source_id.to_s] || raise("cannot resolve #{component.clazz.name} source id=#{source_id.to_s}")
            [id, grouping]
          end
        end
      end
    end

    def self.spouts
      self.components.select{|c| c.is_a?(SpoutDefinition)}
    end

    def self.bolts
      self.components.select{|c| c.is_a?(BoltDefinition)}
    end

    def self.components
      @components ||= []
    end

    def self.topology_name
      @topology_name ||= self.underscore(self.name)
    end

    def self.configure_block
      @configure_block ||= lambda{|env|}
    end

    def self.submit_block
      @submit_block ||= lambda{|env|}
    end

    def self.underscore(camel_case)
      camel_case.to_s.split('::').last.gsub(/(.)([A-Z])/,'\1_\2').downcase!
    end
  end
end