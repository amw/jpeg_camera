# Snapshot taken using {JpegCamera}.
class Snapshot
  # Snapshot IDs are unique within browser session. This class variable holds
  # the value of the next ID to use.
  #
  # @nodoc
  # @private
  @_next_snapshot_id: 1

  # @nodoc
  # @private
  constructor: (@camera, @options) ->
    @id = @constructor._next_snapshot_id++

  # @nodoc
  # @private
  _discarded: false

  # Display the snapshot with the camera element it was taken with.
  #
  # @return [Snapshot] Self for chaining.
  show: ->
    raise "discarded snapshot cannot be used" if @_discarded

    @camera._display @
    @

  # Stop displaying the snapshot and return to showing live camera stream.
  #
  # Ignored if camera is displaying different snapshot.
  #
  # @return [Snapshot] Self for chaining.
  hide: ->
    if @camera.displayed_snapshot() == @
      @camera.show_stream()
    @

  # Calculate snapshot pixel statistics (mean gray value, std).
  #
  # Because reading image data can take a while when Flash fallback is being
  # used this method does not return the data immediately. Instead it accepts
  # a callback that later will be called with a {Stats} object as an argument.
  # Snapshot will be available as `this`.
  #
  # @param callback [Function] Function to call when data is available. Snapshot
  #   object will be available as `this`, the {Stats} instance will be passed
  #   as the first argument.
  #
  # @return [void]
  get_stats: (callback) ->
    raise "discarded snapshot cannot be used" if @_discarded

    @get_image_data (data) ->
      @_get_stats data, callback

  # Get canvas element showing the snapshot.
  #
  # This can be used to display the snapshot outside the camera's container.
  # You can show multiple snapshots at a time and allow the user to pick one
  # he likes best.
  #
  # Canvas produced by this method has a resolution of the snapshot (which
  # depends on the camera's native resolution), not that of the camera's
  # container. Use CSS to display this canvas in different sizes.
  #
  # Because reading image data can take a while when Flash fallback is being
  # used this method does not return the `canvas` element immediately. Instead
  # it accepts a callback that later will be called with the `canvas` element as
  # an argument. Snapshot will be available as `this`.
  #
  # Multiple calls to this method will yield the same canvas element.
  #
  # One caveat is that the underlaying data of this canvas is not mirrored like
  # the stream shown in the camera container. Special CSS transform directive
  # is applied on it so that it looks like the picture in the camera when
  # displayed. This only matters when manipulating the canvas or reading it's
  # data. You can read more about mirroring in {JpegCamera#capture}.
  #
  # This method doesn't work in Internet Explorer 8 or earlier, because it does
  # not support `canvas` element. Call {JpegCamera.canvas_supported} to learn
  # whether you can use this method.
  #
  # @param callback [Function] Function to call when `canvas` element is
  #   available. Snapshot object will be available as `this`, the `canvas`
  #   element will be passed as the first argument.
  #
  # @return [Boolean] Whether canvas is supported in this browser.
  get_canvas: (callback) ->
    raise "discarded snapshot cannot be used" if @_discarded

    false unless JpegCamera._canvas_supported

    # FIXME This method is supposed to always return the same object, but if
    # you call it again before this timeout runs, a new timeout will be
    # scheduled and new data created.
    that = this
    setTimeout ->
        that._extra_canvas ||= that.camera._engine_get_canvas that

        JpegCamera._add_prefixed_style that._extra_canvas,
          "transform", "scalex(-1.0)"

        callback.call that, that._extra_canvas
      , 1
    true

  # @nodoc
  # @private
  _extra_canvas: null

  # Get the file that would be uploaded to the server as a Blob object.
  #
  # This can be useful if you want to stream the data via a websocket. Note that
  # using `upload` is more efficient if all you want to do is upload this file
  # to a server via POST call.
  #
  # This method doesn't work in Internet Explorer 8 or earlier, because it does
  # not support `canvas` element. Call {JpegCamera.canvas_supported} to learn
  # whether you can use this method.
  #
  # Because preparing image blob can take a while this method does not return
  # the data immediately. Instead it accepts a callback that later will be
  # called with the data object as an argument. Snapshot will be available as
  # `this`.
  #
  # Multiple calls to this method will yield the same data object.
  #
  # @param callback [Function] Function to call when data is available. Snapshot
  #   object will be available as `this`, the blob object will be passed as the
  #   first argument.
  # @param mime_type [String] Mime type of the requested blob. "image/jpeg" by
  #   default.
  #
  # @return [Boolean] Whether canvas is supported in this browser.
  get_blob: (callback, mime_type = "image/jpeg") ->
    raise "discarded snapshot cannot be used" if @_discarded

    false unless JpegCamera._canvas_supported

    # FIXME This method is supposed to always return the same object, but if
    # you call it again before this timeout runs, a new timeout will be
    # scheduled and new data created.
    that = this
    setTimeout ->
        that._blob = null if that._blob_mime != mime_type
        that._blob_mime = mime_type
        if that._blob
          callback.call that, that._blob
        else
          mirror = that.options.mirror
          quality = that.options.quality
          that.camera._engine_get_blob that, mime_type, mirror, quality, (b) ->
            that._blob = b
            callback.call that, that._blob
      , 1
    true

  # @nodoc
  # @private
  _blob: null
  # @nodoc
  # @private
  _blob_mime: null

  # Get ImageData object containing color values for each pixel of the snapshot.
  #
  # Data produced by this method has a resolution of the snapshot (which depends
  # on the camera's native resolution), not that of the camera's container.
  #
  # Read more about ImageData object on [Mozilla's website
  # ](https://developer.mozilla.org/en-US/docs/Web/API/ImageData).
  #
  # Because reading image data can take a while when Flash fallback is being
  # used this method does not return the data immediately. Instead it accepts
  # a callback that later will be called with the data object as an argument.
  # Snapshot will be available as `this`.
  #
  # Multiple calls to this method will yield the same data object.
  #
  # One caveat is that the returned data is not mirrored like the stream shown
  # in the camera container. This only matters when manipulating the canvas or
  # reading it's data. You can read more about mirroring in
  # {JpegCamera#capture}.
  #
  # This method returns native [ImageData
  # ](https://developer.mozilla.org/en-US/docs/Web/API/ImageData) object in all
  # browsers except Internet Explorer 8 or earlier which does not support
  # the `canvas` element. In that browser a generic JavaScript object will be
  # returned that mimics the native format. Call {JpegCamera.canvas_supported}
  # to learn whether `canvas` is supported by the browser.
  #
  # @param callback [Function] Function to call when data is available. Snapshot
  #   object will be available as `this`, the data will be passed as the
  #   first argument.
  #
  # @return [void]
  get_image_data: (callback) ->
    raise "discarded snapshot cannot be used" if @_discarded

    # FIXME This method is supposed to always return the same object, but if
    # you call it again before this timeout runs, a new timeout will be
    # scheduled and new data created.
    that = this
    setTimeout ->
        that._image_data ||= that.camera._engine_get_image_data that
        callback.call that, that._image_data
      , 1

    null

  # @nodoc
  # @private
  _image_data: null

  # Upload the snapshot to the server.
  #
  # The snapshot is uploaded using a POST request with JPEG file sent as RAW
  # data. This not like a multipart form upload using file element where the
  # file is given a name and is encoded along with other form keys. To read
  # file contents on the server side use `request.raw_post` in Ruby on Rails or
  # `$HTTP_RAW_POST_DATA` in PHP.
  #
  # Upload completes successfully only if the server responds with status code
  # 200. Any other code will be handled via on_upload_fail callback. Your
  # application is free to inspect the status code and response text in that
  # handler to decide whether that response is acceptable or not.
  #
  # You cannot have multiple uploads for one snapshot running at the same time,
  # but you are free to start another upload after one succeeds or fails.
  #
  # All of the options can have their defaults set when constructing camera
  # object or calling {JpegCamera#capture}.
  #
  # @option options api_url [String] URL where the snapshots will be uploaded.
  # @option options csrf_token [String] CSRF token to be sent in the
  #   __X-CSRF-Token__ header during upload.
  # @option options timeout [Integer] __IGNORED__ (__NOT__ __IMPLEMENTED__)
  #   The number of milliseconds a request can take before automatically being
  #   terminated. Default of 0 means there is no timeout.
  # @option options on_upload_done [Function] Function to call when upload
  #   completes. Snapshot object will be available as `this`, response body will
  #   be passed as the first argument. Calling {Snapshot#done done} before the
  #   upload exits will change the handler for this upload.
  # @option options on_upload_fail [Function] Function to call when upload
  #   fails. Snapshot object will be available as `this`, response code will
  #   be passed as the first argument followed by error message and response
  #   body. Calling {Snapshot#fail fail} before the upload exits will change
  #   the handler for this upload.
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
  # @option options retry_success [Boolean] By default `retry_if` is not called
  #   for uploads that finish with a status code from the 2XX range. Set this
  #   to `true` if you want to retry some of these responses. This can be
  #   useful if you're experiencing some network oddities.
  #
  # @return [Snapshot] Self for chaining.
  upload: (options = {}) ->
    raise "discarded snapshot cannot be used" if @_discarded

    if @_uploading
      @camera._debug "Upload already in progress"
      return
    @_uploading = true
    @_retry = 1

    @_upload_options = options
    cache = @_options()

    unless cache.api_url
      @camera._debug "Snapshot#upload called without valid api_url"
      throw "Snapshot#upload called without valid api_url"

    @_start_upload cache

    @

  # @nodoc
  # @private
  _upload_options: {}
  # @nodoc
  # @private
  _uploading: false
  # @nodoc
  # @private
  _retry: 1

  # Bind callback for upload complete event.
  #
  # The callback to fire when the previously requested {Snapshot#upload upload}
  # operation succeeds. This is just a syntactic sugar that allows one to write:
  # `snapshot.upload().done(done_callback)` instead of
  # `snapshot.upload(on_upload_done: done_callback)`. This callback will be
  # forgotten after the next call to {Snapshot#upload upload}.
  #
  # If the event has already happened the argument will be called immediately.
  #
  # @param callback [Function] Function to call when upload completes. Snapshot
  #   object will be available as `this`, response body will be passed as the
  #   first argument.
  #
  # @return [Snapshot] Self for chaining.
  done: (callback) ->
    raise "discarded snapshot cannot be used" if @_discarded

    @_upload_options.on_upload_done = callback
    cache = @_options()
    if cache.on_upload_done && @_done
      cache.on_upload_done.call @, @_response
    @

  # @nodoc
  # @private
  _done: false
  # @nodoc
  # @private
  _response: null

  # Bind callback for upload error event.
  #
  #
  # The callback to fire when the previously requested {Snapshot#upload upload}
  # operation fails. This is just a syntactic sugar that allows one to write:
  # `snapshot.upload().fail(fail_callback)` instead of
  # `snapshot.upload(on_upload_fail: fail_callback)`. This callback will be
  # forgotten after the next call to {Snapshot#upload upload}.
  #
  # If the event has already happened the argument will be called immediately.
  #
  # @param callback [Function] Function to call when upload fails. Snapshot
  #   object will be available as `this`, response code will be passed as the
  #   first argument with response body or error message as the second argument
  #   if available.
  #
  # @return [Snapshot] Self for chaining.
  fail: (callback) ->
    raise "discarded snapshot cannot be used" if @_discarded

    @_upload_options.on_upload_fail = callback
    cache = @_options()
    if cache.on_upload_fail && @_fail
      cache.on_upload_fail.call @, @_status, @_error_message, @_response
    @

  # @nodoc
  # @private
  _fail: false
  # @nodoc
  # @private
  _status: null
  # @nodoc
  # @private
  _error_message: null

  # Hide and discard this snapshot.
  #
  # After discarding a snapshot an attempt to show or upload it will raise
  # an error.
  #
  # @return [void]
  discard: ->
    @camera._discard @
    delete @_extra_canvas
    delete @_image_data
    delete @_blob
    undefined

  # Snapshot options
  #
  # @nodoc
  # @private
  _options: ->
    @camera._extend {}, @camera.options, @options, @_upload_options

  # Send the upload request
  #
  # @nodoc
  # @private
  _start_upload: (cache) ->
    if "string" == typeof cache.csrf_token && cache.csrf_token.length > 0
      csrf_token = cache.csrf_token
    else
      csrf_token = null

    @_done = false
    @_response = null
    @_fail = false
    @_status = null
    @_error_message = null

    @camera._engine_upload @, cache.api_url, csrf_token, cache.timeout

  # Calculate the snapshot pixel statistics given image data and call callback.
  #
  # @nodoc
  # @private
  _get_stats: (data, callback) ->
    unless @_stats
      n = data.width * data.height
      sum = 0.0
      gray_values = new Array(n)

      for i in [0...n] by 1
        index = i * 4
        gray =
          0.2126 * data.data[index + 0] + # red
          0.7152 * data.data[index + 1] + # green
          0.0722 * data.data[index + 2]   # blue
        gray = Math.round gray

        sum += gray
        gray_values[i] = gray

      mean = Math.round sum / n

      sum_of_square_distances = 0
      for gray in gray_values
        sum_of_square_distances += Math.pow gray - mean, 2

      @_stats = new Stats()
      @_stats.mean = mean
      @_stats.std = Math.round(Math.sqrt(sum_of_square_distances / n))
    callback.call @, @_stats

  # @nodoc
  # @private
  _stats: null

  # Called by the camera engine when upload completes.
  #
  # @nodoc
  # @private
  _upload_done: ->
    @camera._debug "Upload completed with status #{@_status}"
    @_done = true

    cache = @_options()

    retry_decision =
      cache.retry_success &&
      cache.retry_if &&
      cache.retry_if.call(@, @_status, @_error_message, @_response, @_retry)

    if true == retry_decision
      retry_decision = 0

    if "number" == typeof retry_decision
      @_retry++
      if retry_decision > 0
        delay = parseInt retry_decision
        @camera._debug \
          "Will retry the upload in #{delay}ms (attempt ##{@_retry})"

        that = this
        setTimeout (-> that._start_upload cache), delay
      else
        @camera._debug "Will retry the upload immediately (attempt ##{@_retry})"
        @_start_upload cache
    else
      @_uploading = false
      if cache.on_upload_done
        cache.on_upload_done.call @, @_response

  # Called by the camera engine when upload fails.
  #
  # @nodoc
  # @private
  _upload_fail: ->
    @camera._debug "Upload failed with status #{@_status}"
    @_fail = true

    cache = @_options()

    retry_decision =
      cache.retry_if &&
      cache.retry_if.call(@, @_status, @_error_message, @_response, @_retry)

    if true == retry_decision
      retry_decision = 0

    if "number" == typeof retry_decision
      @_retry++
      if retry_decision > 0
        delay = parseInt retry_decision
        @camera._debug \
          "Will retry the upload in #{delay}ms (attempt ##{@_retry})"

        that = this
        setTimeout (-> that._start_upload cache), delay
      else
        @camera._debug "Will retry the upload immediately (attempt ##{@_retry})"
        @_start_upload cache
    else
      @_uploading = false
      if cache.on_upload_fail
        cache.on_upload_fail.call @, @_status, @_error_message, @_response
