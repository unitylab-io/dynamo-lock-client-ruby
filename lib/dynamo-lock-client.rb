require 'aws-sdk-dynamodb'
require 'dynamo_lock/version'
require 'dynamo_lock/configuration'
require 'dynamo_lock/client'

module DynamoLock
  def build_dynamodb_client
    if @config.client.is_a?(Aws::DynamoDB::Client)
      return @config.client
    end

    Aws::DynamoDB::Client.new(
      { endpoint: @config.endpoint }.merge(
        @config.aws&.symbolize_keys || {}
      )
    )
  end

  def config
    @config ||= Configuration.new
  end

  def configure(&block)
    block.call(config)
  end

  def setup_table!
    dynamo_client = build_dynamodb_client

    begin
      dynamo_client.describe_table(table_name: config.table_name)
    rescue Aws::DynamoDB::Errors::ResourceNotFoundException
      dynamo_client.create_table(
        table_name: config.table_name,
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
      sleep 10
    end
    result = dynamo_client.describe_time_to_live(table_name: config.table_name)
    if result.time_to_live_description.time_to_live_status == 'DISABLED'
      dynamo_client.update_time_to_live(
        table_name: config.table_name,
        time_to_live_specification: {
          enabled: true, attribute_name: 'ttl'
        }
      )
    end
  end

  module_function :setup_table!, :configure, :build_dynamodb_client, :config

  class Error < StandardError; end
  class LockFailedError < Error; end
end
