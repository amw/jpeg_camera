# Base class for JpegCamera implementations. Subclasses provide functionality
# defined by this API using different engines. On supported browsers HTML5
# implementation will be used, otherwise Flash will be used if available.
#
#     if (!window.JpegCamera) {
#       alert("Neither getUserMedia nor Flash are available!");
#     }
#     else {
#       // either HTML5 or Flash are available
#       var camera = JpegCamera("#camera").ready(function () {
#         var snapshot = camera.capture().show()
#       }).error(function () {
#         alert("Camera access was declined.");
#       });
#     }
class JpegCamera
  @DefaultOptions =
    shutter_url: "/jpeg_camera/shutter.mp3"
    swf_url: "/jpeg_camera/jpeg_camera.swf"
    on_debug: (message) ->
      console.log "JpegCamera: #{message}" if console && console.log
    quality: 0.9
    shutter: true
    mirror: false
    timeout: 0
    retry_success: false

  # Construct new camera.
  #
  # JpegCamera will fill the entire container element. If the element's aspect
  # ratio is different than that of the camera stream (usually 4:3, but
  # sometimes 16:9) the stream will be clipped horizontally or vertically.
  #
  # To display the image on the client side the image might additionally get
  # resized to match container element, but the file sent to the server will
  # always be in camera's native resolution.
  #
  # By design the file sent to the server will only contain the area that was
  # visible to the user during capture. There is no way of sending unclipped,
  # full camera frame without showing the whole frame to the user.
  #
  # Resizing container after the camera has been initialized is not supported.
  #
  # Various options provided here can be overwritten when calling
  # {JpegCamera#capture capture} or {Snapshot#upload}.
  #
  # @param container [String, DOMElement] CSS selector string or DOM element.
  #
  # @option options swf_url [String] URL to the SWF file that should be used
  #   for fallback if HTML5 cannot be used. "/jpeg_camera/jpeg_camera.swf" by
  #   default.
  # @option options shutter_url [String] URL to the shutter sound file.
  #   "/jpeg_camera/shutter.mp3" by default.
  # @option options on_ready [Function] Function to call when camera is ready.
  #   Inside the callback camera object can be accessed as `this`. See also
  #   {JpegCamera#ready}.
  # @option options on_error [Function] Function to call when camera error
  #   occurs. Error message will be passed as the first argument. Inside the
  #   callback camera object can be accessed as `this`. See also
  #   {JpegCamera#error}.
  # @option options on_debug [Function] This callback can be used to log various
  #   events and information that can be useful when debugging JpegCamera. Debug
  #   message will be passed as the first argument. Inside the callback camera
  #   object can be accessed as `this`. There is a default implementation of
  #   this callback that logs messages to window.console if available.
  # @option options quality [Float] Quality of the JPEG file that will be
  #   uploaded to the server. Should be between 0 and 1. 0.9 by default. Can be
  #   overwritten when calling {JpegCamera#capture capture}. _Cannot_ be
  #   overwritten at the time of upload.
  # @option options mirror [Boolean] The video stream and images displayed on
  #   the client side mimic a mirror, because that's how people are used to
  #   seeing themselves. By default images are uploaded to the server in their
  #   natural orientation - how the front facing camera sees the user.
  #   This option can be set to true to upload images the way the user sees
  #   them. Can be overwritten when calling {JpegCamera#capture capture}.
  #   _Cannot_ be overwritten at the time of upload.
  # @option options shutter [Boolean] Whether to play shutter sound when
  #   capturing snapshots. Can be overwritten when calling
  #   {JpegCamera#capture capture}.
  # @option options api_url [String] URL where the snapshots will be uploaded.
  #   Can be overwritten when calling {JpegCamera#capture capture} or
  #   {Snapshot#upload}.
  # @option options csrf_token [String] CSRF token to be sent in the
  #   __X-CSRF-Token__ header during upload. Can be overwritten when calling
  #   {JpegCamera#capture capture} or {Snapshot#upload}.
  # @option options timeout [Integer] __IGNORED__ (__NOT__ __IMPLEMENTED__)
  #   The number of milliseconds a request can take before automatically being
  #   terminated. Default of 0 means there is no timeout. Can be overwritten
  #   when calling {JpegCamera#capture capture} or {Snapshot#upload}.
  # @option options on_upload_done [Function] Function to call when upload
  #   completes. Snapshot object will be available as `this`, response body will
  #   be passed as the first argument. Can be overwritten when calling
  #   {JpegCamera#capture capture} or {Snapshot#upload}.
  # @option options on_upload_fail [Function] Function to call when upload
  #   fails. Snapshot object will be available as `this`, response code will
  #   be passed as the first argument followed by error message and response
  #   body. Can be overwritten when calling {JpegCamera#capture capture} or
  #   {Snapshot#upload}.
  # @option options retry_if [Function] Function to be called before any upload
  #   done/fail callbacks to decide if the upload should be retried. By default
  #   it's null and uploads are never retried.
  #   Inside the function snapshot object will be available as `this` and the
  #   arguments will be: `status_code`, `error_message`, `response`, `retry`.
  #   `retry` is a number incremented for each retry and starting with 1 when
  #   the upload finishes for the first time.
  #   If the function returns `true` or `0` then upload will be retried
  #   immediately. Number greater than `0` will delay the retry by
  #   that many milliseconds. Any other value will be treated as a decision not
  #   to retry the upload and one of the `on_upload_done` or `on_upload_fail`
  #   callbacks will be fired instead.
  #   Can be overwritten when calling {JpegCamera#capture capture} or
  #   {Snapshot#upload}.
  # @option options retry_success [Boolean] By default `retry_if` is not called
  #   for uploads that finish with a status code from the 2XX range. Set this
  #   to `true` if you want to retry some of these responses. This can be
  #   useful if you're experiencing some network oddities. Can be overwritten
  #   when calling {JpegCamera#capture capture} or {Snapshot#upload}.
  constructor: (container, options) ->
    if "string" == typeof container
      container = document.querySelector container

    unless container && container.offsetWidth
      throw "JpegCamera: invalid container"

    container.innerHTML = ""

    @container = document.createElement "div"
    @container.style.width = "100%"
    @container.style.height = "100%"
    @container.style.position = "relative"

    container.appendChild @container

    @options = @_extend {}, @constructor.DefaultOptions, options

    @_engine_init()

  # Bind callback for camera ready event.
  #
  # Replaces the callback set using __on_ready__ option during initialization.
  #
  # If the event has already happened the argument will be called immediately.
  #
  # @param callback [Function] function to call when camera is ready. Camera
  #   object will be available as `this`.
  #
  # @return [JpegCamera] Self for chaining.
  ready: (callback) ->
    @options.on_ready = callback
    if @options.on_ready && @_is_ready
      @options.on_ready.call @
    @

  _is_ready: false

  # Bind callback for camera error events.
  #
  # Replaces the callback set using __on_error__ option during initialization.
  #
  # Errors can occur if user declines camera access, flash fails to load, etc.
  # Furthermore error event can occur even after camera was ready if for example
  # user revokes access.
  #
  # If the event has already happened the argument will be called immediately.
  #
  # @param callback [Function] function to call when errors occur. Camera
  #   object will be available as `this`, error message will be passed as the
  #   first argument.
  #
  # @return [JpegCamera] Self for chaining.
  error: (callback) ->
    @options.on_error = callback
    if @options.on_error && @_error_occured
      @options.on_error.call @, @_error_occured
    @

  _error_occured: false

  # Capture camera snapshot.
  #
  # All of the options can have their defaults set when constructing camera
  # object.
  #
  # @option options quality [Float] Quality of the JPEG file that will be
  #   uploaded to the server. Should be between 0 and 1. Defaults to 0.9 or
  #   whatever was set during camera initialization. _Cannot_ be
  #   overwritten at the time of upload.
  # @option options mirror [Boolean] The video stream and images displayed on
  #   the client side mimic a mirror, because that's how people are used to
  #   seeing themselves. By default images are uploaded to the server in their
  #   natural orientation - how the front facing camera sees the user.
  #   This option can be set to true to upload images the way the user sees
  #   them. _Cannot_ be overwritten at the time of upload.
  # @option options shutter [Boolean] Whether to play the shutter sound.
  # @option options api_url [String] URL where the snapshots will be uploaded.
  #   Can be overwritten when calling {Snapshot#upload}.
  # @option options csrf_token [String] CSRF token to be sent in the
  #   __X-CSRF-Token__ header during upload. Can be overwritten when calling
  #   {Snapshot#upload}.
  # @option options timeout [Integer] __IGNORED__ (__NOT__ __IMPLEMENTED__)
  #   The number of milliseconds a request can take before automatically being
  #   terminated. Default of 0 means there is no timeout. Can be overwritten
  #   when calling {Snapshot#upload}.
  # @option options on_upload_done [Function] Function to call when upload
  #   completes. Snapshot object will be available as `this`, response body will
  #   be passed as the first argument. Can be overwritten when calling
  #   {Snapshot#upload}.
  # @option options on_upload_fail [Function] Function to call when upload
  #   fails. Snapshot object will be available as `this`, response code will
  #   be passed as the first argument followed by error message and response
  #   body. Can be overwritten when calling {Snapshot#upload}.
  # @option options retry_if [Function] Function to be called before any upload
  #   done/fail callbacks to decide if the upload should be retried. By default
  #   it's null and uploads are never retried.
  #   Inside the function snapshot object will be available as `this` and the
  #   arguments will be: `status_code`, `error_message`, `response`, `retry`.
  #   `retry` is a number incremented for each retry and starting with 1 when
  #   the upload finishes for the first time.
  #   If the function returns `true` or `0` then upload will be retried
  #   immediately. Number greater than `0` will delay the retry by
  #   that many milliseconds. Any other value will be treated as a decision not
  #   to retry the upload and one of the `on_upload_done` or `on_upload_fail`
  #   callbacks will be fired instead.
  #   Can be overwritten when calling {Snapshot#upload}.
  # @option options retry_success [Boolean] By default `retry_if` is not called
  #   for uploads that finish with a status code from the 2XX range. Set this
  #   to `true` if you want to retry some of these responses. This can be
  #   useful if you're experiencing some network oddities. Can be overwritten
  #   when calling {Snapshot#upload}.
  #
  # @return [Snapshot] The snapshot that was taken.
  capture: (options = {}) ->
    snapshot = new Snapshot @, options
    @_snapshots[snapshot.id] = snapshot

    _options = snapshot._options()

    if _options.shutter
      @_engine_play_shutter_sound()

    @_engine_capture snapshot, _options.mirror, _options.quality

    snapshot

  _snapshots: {}

  # Hide currently displayed snapshot and show the video stream.
  #
  # @return [JpegCamera] Self for chaining.
  show_stream: ->
    @_engine_show_stream()
    @_displayed_snapshot = null
    @

  # Discard all snapshots and show video stream.
  #
  # @return [JpegCamera] Self for chaining.
  discard_all: ->
    if @_displayed_snapshot
      @show_stream()
    for id, snapshot of @_snapshots
      @_engine_discard snapshot
      snapshot._discarded = true
    @_snapshots = {}
    @

  # Used to extend options objects.
  #
  # @private
  _extend: (object) ->
    sources = Array.prototype.slice.call arguments, 1
    for source in sources
      if source
        for key, value of source
          object[key] = value
    object

  # Log debug messages
  #
  # @private
  _debug: (message) ->
    @options.on_debug.call @, message if @options.on_debug

  # @private
  _view_width: -> parseInt @container.offsetWidth, 10
  # @private
  _view_height: -> parseInt @container.offsetHeight, 10

  # @private
  _display: (snapshot) ->
    @_engine_display snapshot
    @_displayed_snapshot = snapshot

  _displayed_snapshot: null

  # @private
  _discard: (snapshot) ->
    if @_displayed_snapshot == snapshot
      @show_stream()
    @_engine_discard snapshot
    snapshot._discarded = true
    delete @_snapshots[snapshot.id]

  # Called by the engine when camera is ready.
  #
  # @private
  _prepared: ->
    @_is_ready = true
    if @options.on_ready
      @options.on_ready.call @

  # Called by the engine when error occurs.
  #
  # @private
  _got_error: (error) ->
    @_debug "Error - #{error}"
    @_error_occured = error
    if @options.on_error
      @options.on_error.call @, @_error_occured

  # Shows an overlay over the container to block mouse access.
  #
  # Prevents changing flash permission after camera has been enabled or stopping
  # the HTML5 video stream - both options available through context menu of
  # Flash object or <video> elements.
  #
  # @private
  _block_element_access: ->
    @_overlay = document.createElement "div"
    @_overlay.style.width = "100%"
    @_overlay.style.height = "100%"
    @_overlay.style.position = "absolute"
    @_overlay.style.top = 0
    @_overlay.style.left = 0
    @_overlay.style.zIndex = 2

    @container.appendChild @_overlay

  _overlay: null

  # Helper for setting prefixed CSS declarations.
  #
  # @private
  @_add_prefixed_style: (element, style, value) ->
    uppercase_style = style.charAt(0).toUpperCase() + style.slice(1)
    element.style[style] = value
    element.style["Webkit" + uppercase_style] = value
    element.style["Moz" + uppercase_style] = value
    element.style["ms" + uppercase_style] = value
    element.style["O" + uppercase_style] = value
