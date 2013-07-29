# -*- encoding: utf-8 -*-
require File.expand_path('../lib/jpeg_camera/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = "jpeg_camera"
  s.version     = JpegCamera::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Wróbel"]
  s.email       = ["adam@adamwrobel.com"]
  s.homepage    = JpegCamera::HOMEPAGE
  s.summary     = "Use JpegCamera in Rails 3 app"
  s.description = "This gem provides assets required to use JpegCamera in your Rails 3 application"
  s.license     = "MIT"

  s.add_dependency "railties", ">= 3.1"

  s.files        = Dir.glob("{lib,vendor}/**/*") + %w{README.md LICENSE}
  s.require_path = 'lib'
end
