# -*- encoding: utf-8 -*-
require "json"

package_file = File.expand_path '../package.json', __FILE__
package_info = JSON.parse File.read(package_file)
VERSION = package_info["version"]
HOMEPAGE = package_info["homepage"]

Gem::Specification.new do |s|
  s.name        = "jpeg_camera"
  s.version     = VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Wróbel"]
  s.email       = ["adam@adamwrobel.com"]
  s.homepage    = HOMEPAGE
  s.summary     = "Use JpegCamera in Rails 3 app"

  s.description = <<-DESC
    JpegCamera is a JavaScript library that allows you display a camera stream
    on a web page and then capture, show and upload JPEG snapshots to the
    server. It uses HTML5 in Chrome, Firefox and Opera and falls back to Flash
    in less capable browsers. The video stream is placed without any UI in a
    container of your choice and you control it through JavaScript API and your
    own UI elements.
  DESC

  s.license     = "MIT"

  s.add_dependency "railties", ">= 3.1"

  s.files        = Dir.glob("{app,lib,vendor}/**/*") + %w{README.md LICENSE.md}
  s.require_path = 'lib'
end
