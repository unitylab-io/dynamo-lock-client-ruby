module DynamoLock
  class Configuration
    attr_accessor :table_name, :endpoint, :aws, :client

    def initialize(&_block)
      @table_name = 'dynamolock-locks'
      yield(self) if block_given?
    end
  end
end
