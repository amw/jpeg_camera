/* Part of JpegCamera library.
 * https://amw.github.io/jpeg_camera
 * Copyright (c) 2013 Adam Wróbel <adam@adamwrobel.com>
 */
package {
  // Communicating with JS
  import flash.external.ExternalInterface;
  import flash.display.LoaderInfo;

  // General UI
  import flash.display.Sprite;
  import flash.display.StageAlign;
  import flash.display.StageScaleMode;
  import flash.events.MouseEvent;

  // Storing references to snapshot instances
  import flash.utils.Dictionary;

  // Reporting system version
  import flash.system.Capabilities;

  // Camera access
  import flash.system.Security;
  import flash.system.SecurityPanel;
  import flash.media.Camera;
  import flash.media.Video;
  import flash.events.StatusEvent;

  // Playing shutter sound
  import flash.net.URLRequest;
  import flash.media.Sound;

  // Displaying messages to the user
  import flash.text.TextField;
  import flash.text.TextFormat;
  import flash.text.TextFieldAutoSize;

  // Displaying the snapshot
  import flash.display.Bitmap;

  // Our Snapshot helper class
  import Snapshot;

  public class JpegCamera extends Sprite {
    private var id:uint;

    private var snapshots:Dictionary = new Dictionary();

    private var video:Video;

    private var shutterSound:Sound;

    private var viewWidth:uint;
    private var viewHeight:uint;

    private var camera:Camera;

    private var intro:TextField;

    private var showingSettings:Boolean = false;

    private var displayedBitmap:Bitmap;

    public function JpegCamera() {
      var flashvars:Object = LoaderInfo(this.root.loaderInfo).parameters;

      id = flashvars.id;

      debug("Flash version: " + Capabilities.version);
      debug("OS: " + Capabilities.os);

      if (!Camera.isSupported) {
        callJs("_got_error", "Camera access isn't supported");
        return;
      }

      viewWidth = Math.floor(flashvars.width);
      viewHeight = Math.floor(flashvars.height);

      stage.scaleMode = StageScaleMode.NO_SCALE;
      stage.align = StageAlign.TOP_LEFT;
      stage.stageWidth = viewWidth;
      stage.stageHeight = viewHeight;

      var format:TextFormat = new TextFormat()
      format.size = 22;
      format.font = "_sans";

      intro = new TextField();
      intro.text = "Waiting for camera...";
      intro.setTextFormat(format);
      intro.width = intro.textWidth + 20;
      intro.height = intro.textHeight + 20;
      intro.x = Math.floor((stage.stageWidth - intro.textWidth) / 2);
      intro.y = Math.floor((stage.stageHeight - intro.textHeight) / 2);
      addChild(intro);

      if (flashvars.shutter_url) {
        shutterSound = new Sound();
        shutterSound.load(new URLRequest(flashvars.shutter_url));
      }

      initCamera();

      ExternalInterface.addCallback("_play_shutter", playShutter);
      ExternalInterface.addCallback("_capture", capture);
      ExternalInterface.addCallback("_display", display);
      ExternalInterface.addCallback("_discard", discard);
      ExternalInterface.addCallback("_show_stream", showStream);
      ExternalInterface.addCallback("_upload", upload);
      ExternalInterface.addCallback("_get_image_data", getImageData);
    }

    //
    // JavaScript interface
    //

    public function playShutter():Boolean {
      if (shutterSound && shutterSound.length > 0) {
        shutterSound.play();
        return true;
      }
      else {
        return false;
      }
    }

    public function capture(
      snapshotId:uint, mirror:Boolean, quality:Number, scale:Number
    ):Boolean {
      var size:Object = getSnapshotNaturalSize();

      snapshots[snapshotId] = new Snapshot(
        snapshotId, this, this.video,
        size.width, size.height,
        mirror, quality, scale
      );

      return true;
    }

    public function display(snapshotId:uint):Boolean {
      if (!snapshots[snapshotId]) {
        debug("Missing snapshot");
        return false;
      }

      if (displayedBitmap) {
        removeChild(displayedBitmap);
      }

      displayedBitmap = snapshots[snapshotId].getBitmap();
      displayedBitmap.y = 0;
      displayedBitmap.x = viewWidth;
      displayedBitmap.scaleX = -viewWidth / displayedBitmap.width;
      displayedBitmap.scaleY =  viewHeight / displayedBitmap.height;
      displayedBitmap.smoothing = true;
      addChild(displayedBitmap);

      return true;
    }

    public function discard(snapshotId:uint):void {
      delete snapshots[snapshotId];
    }

    public function showStream():void {
      if (displayedBitmap) {
        removeChild(displayedBitmap);
        displayedBitmap = null;
      }
    }

    public function upload(
      snapshotId:uint, url:String, csrfToken:String, timeout:uint
    ):void {
      if (!snapshots[snapshotId]) {
        debug("Missing snapshot");
        return;
      }

      snapshots[snapshotId].upload(url, csrfToken, timeout);
    }

    public function getImageData(snapshotId:uint):Object {
      return snapshots[snapshotId].getImageData();
    }

    //
    // Methods shared with Snapshot class
    //

    public function debug(debugMessage:String):void {
      trace(debugMessage);
      callJs("_debug", debugMessage);
    }

    // Called on both - upload success and error
    public function uploadComplete(
      snapshotId:uint, status:int, error:String, response:String
    ):void {
      callJs("_flash_upload_complete", snapshotId, status, error, response);
    }

    //
    // Private methods
    //

    private function initCamera():void {
      for (var i:uint = 0, len:uint = Camera.names.length; i < len; i++) {
        debug("Found camera \"" + Camera.names[i] + "\"");
      }

      // XXX Hack to auto-select iSight camera on Mac
      // Doesn't really seem to be needed.
      for (i = 0, len = Camera.names.length; i < len; i++) {
        if (Camera.names[i] == "USB Video Class Video") {
          camera = Camera.getCamera(String(i));
          break;
        }
      }

      if (!camera) {
        camera = Camera.getCamera();
      }

      if (!camera) {
        callJs("_got_error", "No camera was detected.");
        return;
      }

      camera.setMotionLevel(100); // (may help reduce CPU usage)
      camera.setMode(640, 480, 30);

      camera.addEventListener(StatusEvent.STATUS, cameraStatusChanged);

      if (camera.muted) {
        showSettings()
      }
      else {
        cameraUnmuted()
      }
    }

    private function cameraStatusChanged(event:StatusEvent):void {
      debug("Camera status changed. Code: " + event.code);
      if (camera.muted) {
        callJs("_got_error", "Camera access was declined");
      }
      else {
        cameraUnmuted()
      }
    }

    private function cameraUnmuted():void {
      video = new Video(camera.width, camera.height);
      video.attachCamera(camera);
      video.smoothing = true;

      var videoRatio:Number = camera.width / camera.height;
      var viewRatio:Number = viewWidth / viewHeight;
      var videoScale:Number;

      if (videoRatio >= viewRatio) {
        // fill height, crop width
        debug("Filling height");
        videoScale = viewHeight / camera.height;
        var scaledVideoWidth:Number = Math.round(camera.width * videoScale);

        video.scaleX = -videoScale;
        video.scaleY = videoScale;
        video.x = scaledVideoWidth -
          Math.floor((scaledVideoWidth - viewWidth) / 2.0);
        video.y = 0;
      }
      else {
        // fill width, crop height
        debug("Filling width")
        videoScale = viewWidth / camera.width;
        var scaledVideoHeight:Number = Math.round(camera.height * videoScale);

        video.scaleX = -videoScale;
        video.scaleY = videoScale;
        video.x = Math.round(camera.width * videoScale);
        video.y = -Math.floor((scaledVideoHeight - viewHeight) / 2.0);
      }

      addChild(video);

      if (!showingSettings) {
        callJs("_flash_prepared", camera.width, camera.height);
      }
    }

    private function showSettings(panel:String = SecurityPanel.PRIVACY):void {
      showingSettings = true;

      Security.showSettings(panel);

      // When the security panel is visible the stage doesn"t receive
      // mouse events. We can wait for a mouse move event to notify javascript
      // about the panel being closed.
      stage.addEventListener(MouseEvent.MOUSE_MOVE, detectPanelClosure);
    }

    private function detectPanelClosure(event:MouseEvent):void {
      // When privacy panel is opened flash can send mouseMove events with
      // coordinates outside the stage. We need to wait for an event from within
      // the stage.
      if (event.stageX >= 0 && event.stageX < stage.stageWidth &&
          event.stageY >= 0 && event.stageY < stage.stageHeight
      ) {
        if (camera.muted) {
          Security.showSettings(SecurityPanel.PRIVACY);
        }
        else {
          debug("Privacy panel closed.");
          stage.removeEventListener(MouseEvent.MOUSE_MOVE, detectPanelClosure);
          showingSettings = false;

          callJs("_flash_prepared", camera.width, camera.height);
        }
      }
    }

    private function getSnapshotNaturalSize():Object {
      var videoRatio:Number = camera.width / camera.height;
      var viewRatio:Number = viewWidth / viewHeight;

      var snapshotWidth:uint = camera.width;
      var snapshotHeight:uint = camera.height;

      if (videoRatio > viewRatio) {
        // crop width
        snapshotWidth = Math.round(camera.height * viewRatio);
      }
      else if (videoRatio < viewRatio) {
        // crop height
        snapshotHeight = Math.round(camera.width / viewRatio);
      }

      var result:Object = new Object();
      result.width = snapshotWidth;
      result.height = snapshotHeight;
      return result;
    }

    private function callJs(method:String, ... args):* {
      args.unshift("JpegCamera._send_message", id, method);
      return ExternalInterface.call.apply(ExternalInterface, args);
    }
  }
}
