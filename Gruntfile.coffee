module.exports = (grunt) ->
  banner =
    "/*! JpegCamera <%= pkg.version %> | " +
         "<%= grunt.template.today('yyyy-mm-dd') %>\n" +
    "    (c) 2013 Adam Wrobel\n" +
    "    <%= pkg.homepage %> */\n"

  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    coffee:
      compile:
        options:
          join: true
        files:
          "dist/jpeg_camera.js": [
            "src/jpeg_camera.coffee",
            "src/jpeg_camera_html5.coffee",
            "src/jpeg_camera_flash.coffee",
            "src/snapshot.coffee",
            "src/stats.coffee"
          ]
          "dist/jpeg_camera_no_flash.js": [
            "src/jpeg_camera.coffee",
            "src/jpeg_camera_html5.coffee",
            "src/snapshot.coffee",
            "src/stats.coffee"
          ]
    uglify:
      minify:
        options:
          banner: banner
        files:
          "dist/jpeg_camera.min.js": ["dist/jpeg_camera.js"]
          "dist/jpeg_camera_no_flash.min.js": ["dist/jpeg_camera_no_flash.js"]
    concat:
      add_banner:
        options:
          banner: banner
        files:
          "dist/jpeg_camera.js": ["dist/jpeg_camera.js"]
          "dist/jpeg_camera_no_flash.js": ["dist/jpeg_camera_no_flash.js"]
      with_dependencies:
        options:
          banner: "/*! SWFObject + Canvas-to-Blob + JpegCamera */\n\n"
        files:
          "dist/jpeg_camera_with_dependencies.min.js": [
            "dist/swfobject.min.js",
            "dist/canvas-to-blob.min.js",
            "dist/jpeg_camera.min.js"
          ]
    exec:
      swf:
        cmd: "mxmlc -static-link-runtime-shared-libraries " +
          "-output dist/jpeg_camera.swf src/as3/JpegCamera.as"
      rm_doc:
        cmd: "rm -fr doc"
      doc:
        cmd: "PATH=\"$(npm bin):$PATH\" codo; " +
          "cp index.html doc/index.html"

  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-uglify"
  grunt.loadNpmTasks "grunt-contrib-concat"
  grunt.loadNpmTasks "grunt-exec"

  grunt.registerTask "rubygem", "Prepare gem for Ruby on Rails apps", ->
    js_files = [
      "jpeg_camera.js",
      "jpeg_camera.min.js",
      "jpeg_camera_no_flash.js",
      "jpeg_camera_no_flash.min.js",
      "canvas-to-blob.js",
      "canvas-to-blob.min.js",
      "swfobject.js",
      "swfobject.min.js"
    ]
    for file in js_files
      grunt.file.copy "dist/#{file}",
        "vendor/assets/javascripts/jpeg_camera/#{file}"
    grunt.file.copy "dist/jpeg_camera.swf",
      "app/assets/images/jpeg_camera/jpeg_camera.swf"
    grunt.file.copy "dist/shutter.mp3",
      "app/assets/audios/jpeg_camera/shutter.mp3"
    grunt.file.copy "dist/shutter.ogg",
      "app/assets/audios/jpeg_camera/shutter.ogg"

  grunt.registerTask "js",
    ["coffee", "uglify", "concat:add_banner", "concat:with_dependencies"]
  grunt.registerTask "swf", ["exec:swf"]
  grunt.registerTask "doc", ["exec:rm_doc", "exec:doc"]

  grunt.registerTask "dist", ["js", "swf", "rubygem"]
  grunt.registerTask "all", ["dist", "doc"]
  grunt.registerTask "default", ["all"]
