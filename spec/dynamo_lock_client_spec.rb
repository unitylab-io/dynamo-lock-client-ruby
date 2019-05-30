RSpec.describe DynamoLock::Client do
  it 'should create a client instance' do
    client = DynamoLock::Client.new
    expect(client).to be_kind_of(DynamoLock::Client)
  end

  it "should create a client with 'demo' as table name" do
    client = DynamoLock::Client.new(table_name: 'demo')
    expect(client.table_name).to eq('demo')
  end

  it 'should create a client via block configuration' do
    client = DynamoLock::Client.new do |config|
      config.table_name = 'demo'
    end

    expect(client).to be_kind_of(DynamoLock::Client)
    expect(client.table_name).to eq('demo')
  end

  it 'should create a lock' do
    client = DynamoLock::Client.new do |config|
      config.table_name = 'demo'
      config.dynamo_client = Aws::DynamoDB::Client.new(
        endpoint: ENV.fetch('DYNAMODB_URL'),
        access_key_id: 'foo',
        secret_access_key: 'bar'
      )
    end

    client.with_lock('test') do
      p client.dynamo_client.scan(table_name: client.table_name)
    end
  end
end
