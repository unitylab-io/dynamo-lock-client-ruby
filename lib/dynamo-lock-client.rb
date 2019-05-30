require 'aws-sdk-dynamodb'
require 'dynamo_lock/version'
require 'dynamo_lock/client'

module DynamoLock
  class Error < StandardError; end
  class LockFailedError < Error; end
end
