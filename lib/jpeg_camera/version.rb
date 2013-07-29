require "json"

module JpegCamera
  package_file = File.expand_path '../../../package.json', __FILE__
  package_info = JSON.parse File.read(package_file)
  VERSION = package_info["version"]
  HOMEPAGE = package_info["homepage"]
end
