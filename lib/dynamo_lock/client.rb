module DynamoLock
  class Client
    attr_accessor :table_name, :dynamo_client, :default_expires_after,
                  :lock_owner_id, :default_retry_interval

    def initialize(options = {}, &_block)
      @lock_owner_id = options.fetch(:lock_owner_id, SecureRandom.uuid)
      @table_name = options.fetch(:table_name, 'dynamolock-locks')
      @dynamo_client = Aws::DynamoDB::Client.new(
        options.slice(:access_key_id, :secret_access_key, :region)
      )
      @default_expires_after = options.fetch(:default_expires_after, 10).to_i
      @default_retry_interval = options.fetch(:default_retry_interval, 0.5).to_f
      yield(self) if block_given?
    end

    def setup_table!
      dynamo_client.describe_table(table_name: @table_name)
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException
      dynamo_client.create_table(
        table_name: @table_name,
        key_schema: [
          { attribute_name: 'id', key_type: 'HASH' }
        ],
        attribute_definitions: [
          { attribute_name: 'id', attribute_type: 'S' }
        ],
        provisioned_throughput: {
          read_capacity_units: 1,
          write_capacity_units: 1
        }
      )
    end

    def with_lock(name, ex: nil, max_retries: 3, retry_interval: nil, &_block)
      lock(name, ex: ex)

      begin
        yield
      ensure
        release(name)
      end
    rescue LockFailedError
      raise LockFailedError if max_retries.zero?

      max_retries -= 1
      sleep(retry_interval || default_retry_interval)
      retry
    end

    def lock(name, ex: nil)
      dynamo_client.put_item(
        table_name: table_name,
        item: {
          id: name.to_s,
          lock_owner: lock_owner_id,
          expires: Time.now.utc.to_i + (ex || default_expires_after).to_i
        },
        condition_expression: \
          'attribute_not_exists(expires) OR expires = :null OR expires < :expires',
        expression_attribute_values: {
          ':expires' => Time.now.utc.to_i,
          ':null' => nil
        }
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      raise LockFailedError
    end

    def heartbeat(name, ex: nil)
      dynamo_client.update_item(
        table_name: table_name,
        key: { id: name.to_s },
        update_expression: 'SET expires = :expires',
        condition_expression: \
          'attribute_exists(expires) AND expires > :now AND lock_owner = :owner',
        expression_attribute_values: {
          ':expires' => Time.now.utc.to_i + (ex || @default_expires_after).to_i,
          ':owner' => lock_owner_id,
          ':now' => Time.now.utc.to_i
        }
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      return false
    end

    def release(name)
      dynamo_client.update_item(
        table_name: table_name,
        key: { id: name.to_s },
        update_expression: 'SET expires = :expires',
        condition_expression: \
          'attribute_exists(expires) AND expires >= :now AND lock_owner = :owner',
        expression_attribute_values: {
          ':expires' => nil,
          ':owner' => lock_owner_id,
          ':now' => Time.now.utc.to_i
        }
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      false
    end
  end
end
