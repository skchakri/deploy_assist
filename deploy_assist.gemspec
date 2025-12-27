require_relative "lib/deploy_assist/version"

Gem::Specification.new do |spec|
  spec.name        = "deploy_assist"
  spec.version     = DeployAssist::VERSION
  spec.authors     = [ "skchakri" ]
  spec.email       = [ "skchakri@gmail.com" ]
  spec.homepage    = "https://github.com/skchakri/deploy_assist"
  spec.summary     = "Rails engine for deployment automation"
  spec.description = "Automates AWS deployment, Google OAuth, SES, and Stripe setup for Rails applications with guided wizards and config generation"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/skchakri/deploy_assist"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "aws-sdk-iam", "~> 1.0"
  spec.add_dependency "aws-sdk-s3", "~> 1.0"
  spec.add_dependency "aws-sdk-rds", "~> 1.0"
  spec.add_dependency "aws-sdk-ses", "~> 1.0"
  spec.add_dependency "stripe", "~> 12.0"
end
