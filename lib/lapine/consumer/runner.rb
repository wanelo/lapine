require 'amqp'
require 'digest'
require 'eventmachine'
require 'lapine/annotated_logger'
require 'lapine/consumer/config'
require 'lapine/consumer/connection'
require 'lapine/consumer/environment'
require 'lapine/consumer/topology'
require 'lapine/consumer/dispatcher'

module Lapine
  module Consumer
    class Runner
      attr_reader :argv

      def initialize(argv)
        @argv = argv
        @message_count = 0
        @running_message_count = 0
      end

      def run
        handle_signals!
        Consumer::Environment.new(config).load!
        logger.info 'starting Lapine::Consumer'

        @queue_properties = queue_properties
        EventMachine.run do
          topology.each_binding do |q, conn, routing_key, classes|
            queue = conn.channel.queue(q, @queue_properties).bind(conn.exchange, routing_key: routing_key)
            queue.subscribe(ack: true) do |metadata, payload|
              classes.each do |clazz|
                Lapine::Consumer::Dispatcher.new(clazz, payload, metadata, logger).dispatch
              end

              if config.debug?
                @message_count += 1
                @running_message_count += 1
              end
              metadata.ack
            end
          end

          if config.debug?
            EventMachine.add_periodic_timer(10) do
              logger.info "Lapine::Consumer messages processed=#{@message_count} running_count=#{@running_message_count}"
              @message_count = 0
            end
          end
        end

        logger.warn 'exiting Lapine::Consumer'
      end

      def config
        @config ||= Lapine::Consumer::Config.new.load(argv)
      end

      def topology
        @topology ||= ::Lapine::Consumer::Topology.new(config, logger)
      end

      def logger
        @logger ||= config.logfile ? AnnotatedLogger.new(config.logfile) : AnnotatedLogger.new(STDOUT)
      end

      def queue_properties
        {}.tap do |props|
          props.merge!(auto_delete: true) if config.transient?
        end
      end

      def handle_signals!
        Signal.trap('INT') { EventMachine.stop }
        Signal.trap('TERM') { EventMachine.stop }
      end
    end
  end
end
