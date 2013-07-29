## About

JpegCamera is a JavaScript library that allows you display a camera stream on
a web page and then capture, show and upload JPEG snapshots to the server. It
uses HTML5 in Chrome, Firefox and Opera and falls back to Flash in less capable
browsers. The video stream is placed without any UI in a container of your
choice and you control it through JavaScript API and your own UI elements.

The idea is based on a similar
[JpegCam](https://github.com/mattclements/jpegcam) library which was Flash only.
Beside working without Flash and offering a cleaner, more modern API, JpegCamera
has some nice, new features.

## Features

- Works natively in Chrome, Firefox, Opera and with a Flash plugin in all other
  browsers.
- Manage and upload multiple snapshots at once. You don't have to wait for the
  first upload to finish before capturing the next image. This means you can
  take a few shots in a short interval.
- Allows you to retry failed uploads.
- Easily read server response text and code after upload.
- Send CSRF tokens to secure your user's session from [Cross-site request
  forgery](http://en.wikipedia.org/wiki/Cross-site_request_forgery#Prevention)

## Dependencies

- [Canvas-to-Blob](https://github.com/blueimp/JavaScript-Canvas-to-Blob)
  polyfill for the standard JavaScript `canvas.toBlob` method.
- [SWFObject](http://code.google.com/p/swfobject/) for embedding the
  Flash-based fallback.

For convenience these scripts are packaged with JpegCamera.

## Installation

You can load JpegCamera directly on any web page, but if you're writing Rails
3.1 application consider using a gem. In either case you have an option
of loading full library that includes HTML5 implementation with Flash fallback
or HTML5 version only.

### Standalone app

Copy all the files from `dist` into `jpeg_camera` directory under your server's
root.

Load JpegCamera and it's dependencies in the `HEAD` section of your page.

    <script src="/jpeg_camera/swfobject.min.js" type="text/javascript"></script>
    <script src="/jpeg_camera/canvas-to-blob.min.js" type="text/javascript"></script>
    <script src="/jpeg_camera/jpeg_camera.min.js" type="text/javascript"></script>

SWFObject and Canvas-to-Blob are stored in separate files so that you don't have
to load them again if you already use them in your project. If you want to cut
down on HTTP requests then there is a concatenated version you can use.

    <script src="/jpeg_camera/jpeg_camera_with_dependencies.min.js" type="text/javascript"></script>

If you want to use HTML5-only version you can load jpeg_camera_no_flash.min.js.
There is no "with dependencies" version of this file, so you have to remember
to also load Canvas-to-Blob. You don't need SWFObject for HTML5.

### Ruby on Rails 3.1 applications

Require the gem in your Gemfile.

    gem "jpeg_camera", "~> 1.0.0"

Add appropriate requires to your application.js. SWFObject and Canvas-to-Blob
are stored in separate files so that you don't have to load them again if you
already use them in your project. The assets pipeline will take care of
minifying and concatenating everything into one script.

    //= require jpeg_camera/swfobject
    //= require jpeg_camera/canvas-to-blob
    //= require jpeg_camera/jpeg_camera

If you want to use HTML5-only version then use this instead:

    //= require jpeg_camera/canvas-to-blob
    //= require jpeg_camera/jpeg_camera_no_flash

Minified versions of all the scripts are also included in the gem if you don't
want to include JpegCamera in your application.js file and would rather use
`javascript_include_tag` on select pages of your application.

## Usage

    var camera = new JpegCamera("#camera");

    var snapshot = camera.capture();

    snapshot.show(); // Display the snapshot

    snapshot.upload({api_url: "/upload_image"}).done(function(response) {
      response_container.innerHTML = response;
      this.discard(); // discard snapshot and show video stream again
    }).fail(function() {
      alert("Upload failed.");
    });

A detailed documentation using in-code comments is maintained for
[JpegCamera](http://amw.github.io/jpeg_camera/doc/classes/JpegCamera.html) and
[Snapshot](http://amw.github.io/jpeg_camera/doc/classes/Snapshot.html)
classes.

## Caveats

To use Flash fallback your camera container must be at least 215 pixels wide and
138 pixels tall. This is the minimum to display privacy settings dialog.

With Flash in some browsers it's impossible to read response body for requests
that finish with status codes from outside the 2XX range (like 404 Not Found or
422 Unprocessable Entity). If you're using version of JpegCamera with Flash
fallback your application should not rely on reading body of these responses.
The status code number is always available.

## Contributing

The source code is available on [Github](https://github.com/amw/jpeg_camera).
Please send pull requests on topic branches.

To build dist files from source you need `npm` — Node Package Manager.

    npm install              # install required dependencies
    npm install -g grunt-cli # install grunt command
    grunt dist               # build js & swf files
    grunt js                 # only builds js files
    grunt swf                # only builds swf file
    grunt doc                # update documentation
    grunt                    # build dist files and update documentation

To build swf file you need to have `mxmlc` available in your `$PATH`. It comes
in the [Flex SDK](http://www.adobe.com/devnet/flex/flex-sdk-download.html).

## Acknowledgements

Thanks to Joseph Huckaby for creating and Matt Clements for maintaining
Flash-based [JpegCam library](http://code.google.com/p/jpegcam/) which I have
been using until HTML5 became a viable solution. If you're interested here's
[Matt's repo](https://github.com/mattclements/jpegcam) and here's
[mine](https://github.com/amw/jpegcam). Thanks to everyone else contributing to
that project.


Copyright [Adam Wróbel](http://adamwrobel.com), released under the MIT License.
