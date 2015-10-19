/* Part of JpegCamera library.
 * https://amw.github.io/jpeg_camera
 * Copyright (c) 2013 Adam Wróbel <adam@adamwrobel.com>
 */
package
{
  // Taking snapshots
  import flash.media.Video;
  import flash.display.BitmapData;
  import flash.display.Bitmap;
  import flash.geom.Matrix;

  // Preparing jpeg file
  import flash.utils.ByteArray;
  import JPGEncoder;

  // Uploading
  import flash.net.URLRequest;
  import flash.net.URLRequestHeader;
  import flash.net.URLRequestMethod;
  import flash.net.URLLoader;
  import flash.events.Event;
  import flash.events.IOErrorEvent;
  import flash.events.HTTPStatusEvent;
  import flash.events.SecurityErrorEvent;

  public class Snapshot
  {
    private var id:int;
    private var camera:JpegCamera;

    private var data:BitmapData;
    private var jpegFile:ByteArray;

    private var mirror:Boolean;
    private var quality:Number;

    private var loader:URLLoader;
    private var statusCode:int;
    private var errorMessage:String;

    public function Snapshot(
      id:int, camera:JpegCamera, video:Video,
      width:uint, height:uint,
      mirror:Boolean, quality:Number, scale:Number
    ) {
      this.id = id;
      this.camera = camera;
      this.mirror = mirror;
      this.quality = quality;

      var x_offset:int = 0;
      var y_offset:int = 0;

      if (width < video.videoWidth) {
        x_offset = -Math.round((video.videoWidth - width) / 2.0)
      }

      if (height < video.videoHeight) {
        y_offset = -Math.round((video.videoHeight - height) / 2.0)
      }

      width = Math.round(width * scale);
      height = Math.round(height * scale);

      data = new BitmapData(width, height, false, 0xffffffff);

      var matrix:Matrix = new Matrix();
      matrix.translate(x_offset, y_offset);
      matrix.scale(scale, scale);

      data.draw(video, matrix);
    }

    public function getBitmap():Bitmap {
      return new Bitmap(data);
    }

    public function getImageData():Object {
      var array:Array = new Array(data.height * data.width);

      var index:uint = 0;

      for (var y:uint = 0; y < data.height; ++y) {
        for (var x:uint = 0; x < data.width; ++x) {
          array[index++] = data.getPixel(x, y);
        }
      }

      var result:Object = new Object();

      result.data = array;
      result.width = data.width;
      result.height = data.height;

      return result;
    }

    public function upload(url:String, csrfToken:String, timeout:uint):void {
      if (!jpegFile) {
        debug("Generating JPEG file");

        var encoder:JPGEncoder = new JPGEncoder(quality * 100);

        if (mirror) {
          var matrix:Matrix = new Matrix();
          matrix.translate(-data.width, 0);
          matrix.scale(-1.0, 1.0);

          var mirroredData:BitmapData = new BitmapData(data.width, data.height);
          mirroredData.draw(data, matrix, null, null, null, false);
          jpegFile = encoder.encode(mirroredData);
        }
        else {
          jpegFile = encoder.encode(data);
        }
      }

      var request:URLRequest = new URLRequest(url);
      request.requestHeaders.push(new URLRequestHeader("Accept", "text/*"));

      if (csrfToken && csrfToken.length > 0) {
        request.requestHeaders.push(
          new URLRequestHeader("X-CSRF-Token", csrfToken));
      }

      request.data = jpegFile;
      request.contentType = "image/jpeg";
      request.method = URLRequestMethod.POST;

      loader = new URLLoader();
      loader.addEventListener(Event.OPEN, open);
      loader.addEventListener(Event.COMPLETE, complete);
      loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
      loader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
      loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityError);

      statusCode = -1;
      errorMessage = null;

      try {
        loader.load(request);
      }
      catch (error:Error) {
        errorMessage = "Can't upload data: " + error
        camera.uploadComplete(id, statusCode, errorMessage, null);
      }
    }

    private function open(event:Event):void {
      debug("Uploading the file");
    }

    private function complete(event:Event):void {
      var response:String = "response missing";
      if (loader && loader.data) {
        response = loader.data;
      }
      camera.uploadComplete(id, statusCode, errorMessage, response);
    }

    private function httpStatusHandler(event:HTTPStatusEvent):void {
      debug("HTTP status " + event.status);
      statusCode = event.status;
    }

    private function ioErrorHandler(event:IOErrorEvent):void {
      reportError("IO " + event.text);
    }

    private function securityError(event:SecurityErrorEvent):void {
      reportError("Security " + event.text);
    }

    private function reportError(errorMessage:String):void {
      this.errorMessage = errorMessage;
      debug(errorMessage);

      var response:String;
      if (loader && loader.data) {
        response = loader.data;
      }

      camera.uploadComplete(id, statusCode, errorMessage, response);
    }

    private function debug(debug_message:String):void {
      if (camera) {
        camera.debug(debug_message);
      }
    }
  }
}
