require 'lapine/version'
require 'lapine/configuration'
require 'lapine/exchange'
require 'lapine/publisher'
require 'lapine/annotated_logger'

module Lapine
  class UndefinedConnection < StandardError; end
  class UndefinedExchange < StandardError; end

  def self.config
    @config ||= Configuration.new
  end

  def self.add_connection(name, properties)
    config.connection_properties[name] = properties
  end

  def self.add_exchange(name, properties)
    connection = properties[:connection]
    raise UndefinedConnection unless connection
    raise UndefinedConnection unless config.connection_properties[connection]
    config.exchange_properties[name] = properties
  end

  def self.find_exchange(name)
    exchange = config.exchange_properties[name]
    raise UndefinedExchange unless exchange
    return config.exchanges[name].exchange if config.exchanges[name]
    config.exchanges[name] = Lapine::Exchange.new(name, exchange)
    config.exchanges[name].exchange
  end

  def self.close_connections!
    config.exchanges.values.each do |exchange|
      exchange.close!
      config.exchanges.delete exchange.name
    end
  end
end
