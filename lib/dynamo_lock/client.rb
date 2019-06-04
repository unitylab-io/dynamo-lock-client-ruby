module DynamoLock
  class Client
    attr_accessor :table_name, :dynamo_client, :default_expires_after,
                  :lock_owner_id, :default_retry_interval

    ITEM_TTL = 3600

    def initialize(options = {}, &_block)
      @dynamo_client = DynamoLock.build_dynamodb_client
      @lock_owner_id = options.fetch(:lock_owner_id, SecureRandom.uuid)
      @table_name = options.fetch(:table_name, DynamoLock.config.table_name)
      @default_expires_after = options.fetch(:default_expires_after, 10).to_i
      @default_retry_interval = options.fetch(:default_retry_interval, 0.5).to_f
      yield(self) if block_given?
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
          id: lock_name_for(name),
          owner: lock_owner_id,
          ex: Time.now.utc.to_i + (ex || default_expires_after).to_i,
          ttl: (Time.now + ITEM_TTL).to_i
        },
        condition_expression: \
          'attribute_not_exists(#ex) OR #ex < :expires',
        expression_attribute_names: {
          '#ex' => 'ex'
        },
        expression_attribute_values: {
          ':expires' => Time.now.utc.to_i
        }
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      raise LockFailedError
    end

    def heartbeat(name, ex: nil)
      dynamo_client.update_item(
        table_name: table_name,
        key: { id: lock_name_for(name) },
        update_expression: 'SET #ex = :expires, #ttl = :ttl',
        condition_expression: \
          'attribute_exists(#ex) AND #ex > :now AND #owner = :owner',
        expression_attribute_names: {
          '#ex' => 'ex',
          '#ttl' => 'ttl',
          '#owner' => 'owner'
        },
        expression_attribute_values: {
          ':expires' => Time.now.utc.to_i + (ex || @default_expires_after).to_i,
          ':owner' => lock_owner_id,
          ':now' => Time.now.utc.to_i,
          ':ttl' => (Time.now + ITEM_TTL).to_i
        }
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      false
    end

    def release(name)
      dynamo_client.update_item(
        table_name: table_name,
        key: { id: lock_name_for(name) },
        update_expression: 'SET #ex = :now, #ttl = :ttl REMOVE #owner',
        condition_expression: \
          'attribute_exists(#ex) AND #ex >= :now AND #owner = :owner',
        expression_attribute_names: {
          '#ex' => 'ex',
          '#ttl' => 'ttl',
          '#owner' => 'owner'
        },
        expression_attribute_values: {
          ':owner' => lock_owner_id,
          ':now' => Time.now.utc.to_i,
          ':ttl' => (Time.now + ITEM_TTL).to_i
        }
      )
      true
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => ex
      p ex, ex.backtrace, ex.message
      false
    end

    private

    def lock_name_for(name)
      name.to_s
    end
  end
end
