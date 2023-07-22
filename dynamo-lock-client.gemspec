
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dynamo_lock/version'

Gem::Specification.new do |spec|
  spec.name          = 'dynamo-lock-client'
  spec.version       = DynamoLock::VERSION
  spec.authors       = ['Julien D.']
  spec.email         = ['julien@unitylab.io']

  spec.summary       = %q(DynamoLock - A distributed locking mechanism for Ruby)
  spec.description   = %q(
    DynamoLock is distributed locking mechanism for Ruby that use AWS DynamoDB
    as persistence backend
  )
  spec.homepage      = 'https://github.com/unitylab-io/dynamo-lock-client-ruby'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/unitylab-io/dynamo-lock-client-ruby.git'
    spec.metadata['changelog_uri'] = 'https://github.com/unitylab-io/dynamo-lock-client-ruby'
  else
    raise %q(
      RubyGems 2.0 or newer is required to protect against public gem pushes.
    )
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-dynamodb', '~> 1.29'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
