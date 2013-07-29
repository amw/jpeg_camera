/*! JpegCamera 1.0.0 | 2013-07-29
    (c) 2013 Adam Wrobel
    https://github.com/amw/jpeg_camera */
(function() {
  var JpegCamera, JpegCameraHtml5, Snapshot, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  JpegCamera = (function() {
    JpegCamera.DefaultOptions = {
      shutter_url: "/jpeg_camera/shutter.mp3",
      swf_url: "/jpeg_camera/jpeg_camera.swf",
      on_debug: function(message) {
        if (console && console.log) {
          return console.log("JpegCamera: " + message);
        }
      },
      quality: 0.9,
      shutter: true,
      mirror: false,
      timeout: 0
    };

    function JpegCamera(container, options) {
      if ("string" === typeof container) {
        this.container = document.querySelector(container);
      } else {
        this.container = container;
      }
      if (!(this.container && this.container.offsetWidth)) {
        throw "JpegCamera: invalid container";
      }
      this.container.innerHTML = "";
      this.options = this._extend({}, this.constructor.DefaultOptions, options);
      this._engine_init();
    }

    JpegCamera.prototype.ready = function(callback) {
      this.options.on_ready = callback;
      if (this.options.on_ready && this._is_ready) {
        this.options.on_ready.call(this);
      }
      return this;
    };

    JpegCamera.prototype._is_ready = false;

    JpegCamera.prototype.error = function(callback) {
      this.options.on_error = callback;
      if (this.options.on_error && this._error_occured) {
        this.options.on_error.call(this, this._error_occured);
      }
      return this;
    };

    JpegCamera.prototype._error_occured = false;

    JpegCamera.prototype.capture = function(options) {
      var snapshot, _options;
      if (options == null) {
        options = {};
      }
      snapshot = new Snapshot(this, options);
      this._snapshots[snapshot.id] = snapshot;
      _options = snapshot._options();
      if (_options.shutter) {
        this._engine_play_shutter_sound();
      }
      this._engine_capture(snapshot, _options.mirror, _options.quality);
      return snapshot;
    };

    JpegCamera.prototype._snapshots = {};

    JpegCamera.prototype.show_stream = function() {
      this._engine_show_stream();
      this._displayed_snapshot = null;
      return this;
    };

    JpegCamera.prototype.discard_all = function() {
      var id, snapshot, _ref;
      if (this._displayed_snapshot) {
        this.show_stream();
      }
      _ref = this._snapshots;
      for (id in _ref) {
        snapshot = _ref[id];
        this._engine_discard(snapshot);
        snapshot._discarded = true;
      }
      this._snapshots = {};
      return this;
    };

    JpegCamera.prototype._extend = function(object) {
      var key, source, sources, value, _i, _len;
      sources = Array.prototype.slice.call(arguments, 1);
      for (_i = 0, _len = sources.length; _i < _len; _i++) {
        source = sources[_i];
        if (source) {
          for (key in source) {
            value = source[key];
            object[key] = value;
          }
        }
      }
      return object;
    };

    JpegCamera.prototype._debug = function(message) {
      if (this.options.on_debug) {
        return this.options.on_debug.call(this, message);
      }
    };

    JpegCamera.prototype._view_width = function() {
      return parseInt(this.container.offsetWidth, 10);
    };

    JpegCamera.prototype._view_height = function() {
      return parseInt(this.container.offsetHeight, 10);
    };

    JpegCamera.prototype._display = function(snapshot) {
      this._engine_display(snapshot);
      return this._displayed_snapshot = snapshot;
    };

    JpegCamera.prototype._displayed_snapshot = null;

    JpegCamera.prototype._upload = function(snapshot, api_url, csrf_token, timeout) {
      return this._engine_upload(snapshot, api_url, csrf_token, timeout);
    };

    JpegCamera.prototype._discard = function(snapshot) {
      if (this._displayed_snapshot === snapshot) {
        this.show_stream();
      }
      this._engine_discard(snapshot);
      snapshot._discarded = true;
      return delete this._snapshots[snapshot.id];
    };

    JpegCamera.prototype._prepared = function() {
      this._is_ready = true;
      if (this.options.on_ready) {
        return this.options.on_ready.call(this);
      }
    };

    JpegCamera.prototype._got_error = function(error) {
      this._debug("Error - " + error);
      this._error_occured = error;
      if (this.options.on_error) {
        return this.options.on_error.call(this, this._error_occured);
      }
    };

    return JpegCamera;

  })();

  navigator.getUserMedia || (navigator.getUserMedia = navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia);

  if (navigator.getUserMedia) {
    JpegCameraHtml5 = (function(_super) {
      __extends(JpegCameraHtml5, _super);

      function JpegCameraHtml5() {
        _ref = JpegCameraHtml5.__super__.constructor.apply(this, arguments);
        return _ref;
      }

      JpegCameraHtml5.prototype._engine_init = function() {
        var get_user_media_options, horizontal_padding, that, vertical_padding;
        this._debug("Using HTML5 engine");
        this.internal_container = document.createElement("div");
        this.internal_container.style.width = "100%";
        this.internal_container.style.height = "100%";
        this.internal_container.style.position = "relative";
        this.container.appendChild(this.internal_container);
        vertical_padding = Math.floor(this._view_height() * 0.2);
        horizontal_padding = Math.floor(this._view_width() * 0.2);
        this.message = document.createElement("div");
        this.message["class"] = "message";
        this.message.style.width = "100%";
        this.message.style.height = "100%";
        this._add_prefixed_style(this.message, "boxSizing", "border-box");
        this.message.style.overflow = "hidden";
        this.message.style.textAlign = "center";
        this.message.style.paddingTop = "" + vertical_padding + "px";
        this.message.style.paddingBottom = "" + vertical_padding + "px";
        this.message.style.paddingLeft = "" + horizontal_padding + "px";
        this.message.style.paddingRight = "" + horizontal_padding + "px";
        this.message.style.position = "absolute";
        this.message.style.zIndex = 3;
        this.message.innerHTML = "Please allow camera access when prompted by the browser.";
        this.internal_container.appendChild(this.message);
        this.video_container = document.createElement("div");
        this.video_container.style.width = "" + (this._view_width()) + "px";
        this.video_container.style.height = "" + (this._view_height()) + "px";
        this.video_container.style.overflow = "hidden";
        this.video_container.style.position = "absolute";
        this.video_container.style.zIndex = 1;
        this.internal_container.appendChild(this.video_container);
        this.video = document.createElement('video');
        this.video.autoplay = true;
        this._add_prefixed_style(this.video, "transform", "scalex(-1.0)");
        window.AudioContext || (window.AudioContext = window.webkitAudioContext);
        if (window.AudioContext) {
          this._load_shutter_sound();
        }
        get_user_media_options = {
          video: {
            optional: [
              {
                minWidth: 1280
              }, {
                minWidth: 640
              }, {
                minWidth: 480
              }, {
                minWidth: 360
              }
            ]
          }
        };
        that = this;
        return navigator.getUserMedia(get_user_media_options, function(stream) {
          that._remove_message();
          if (window.URL) {
            that.video.src = URL.createObjectURL(stream);
          } else {
            that.video.src = stream;
          }
          return that._wait_for_video_ready();
        }, function(error) {
          var code, key, value;
          code = error.code;
          for (key in error) {
            value = error[key];
            if (key === "code") {
              continue;
            }
            that._got_error(key);
            return;
          }
          return that._got_error("UNKNOWN ERROR");
        });
      };

      JpegCameraHtml5.prototype._engine_play_shutter_sound = function() {
        var source;
        if (!this.shutter_buffer) {
          return;
        }
        source = this.audio_context.createBufferSource();
        source.buffer = this.shutter_buffer;
        source.connect(this.audio_context.destination);
        return source.start(0);
      };

      JpegCameraHtml5.prototype._engine_capture = function(snapshot, mirror, quality) {
        var canvas, context, crop;
        crop = this._get_capture_crop();
        canvas = document.createElement("canvas");
        canvas.width = crop.width;
        canvas.height = crop.height;
        context = canvas.getContext("2d");
        context.drawImage(this.video, crop.x_offset, crop.y_offset, crop.width, crop.height, 0, 0, crop.width, crop.height);
        snapshot._canvas = canvas;
        snapshot._mirror = mirror;
        return snapshot._quality = quality;
      };

      JpegCameraHtml5.prototype._engine_display = function(snapshot) {
        if (this.displayed_canvas) {
          this.internal_container.removeChild(this.displayed_canvas);
        }
        this.displayed_canvas = snapshot._canvas;
        this.displayed_canvas.style.width = "" + (this._view_width()) + "px";
        this.displayed_canvas.style.height = "" + (this._view_height()) + "px";
        this.displayed_canvas.style.top = 0;
        this.displayed_canvas.style.left = 0;
        this.displayed_canvas.style.position = "absolute";
        this.displayed_canvas.style.zIndex = 2;
        this._add_prefixed_style(this.displayed_canvas, "transform", "scalex(-1.0)");
        return this.internal_container.appendChild(this.displayed_canvas);
      };

      JpegCameraHtml5.prototype._engine_discard = function(snapshot) {
        if (snapshot._xhr) {
          snapshot._xhr.abort();
        }
        delete snapshot._xhr;
        delete snapshot._canvas;
        return delete snapshot._jpeg_blob;
      };

      JpegCameraHtml5.prototype._engine_show_stream = function() {
        if (this.displayed_canvas) {
          this.internal_container.removeChild(this.displayed_canvas);
          this.displayed_canvas = null;
        }
        return this.video_container.style.display = "block";
      };

      JpegCameraHtml5.prototype._engine_upload = function(snapshot, api_url, csrf_token, timeout) {
        var canvas, context, handler, that, xhr;
        that = this;
        if (snapshot._jpeg_blob) {
          this._debug("Uploading the file");
          handler = function(event) {
            delete snapshot._xhr;
            snapshot._status = event.target.status;
            snapshot._response = event.target.responseText;
            if (snapshot._status >= 200 && snapshot._status < 300) {
              return snapshot._upload_done();
            } else {
              snapshot._error_message = event.target.statusText || "Unknown error";
              return snapshot._upload_fail();
            }
          };
          xhr = new XMLHttpRequest();
          xhr.open('POST', api_url);
          xhr.timeout = timeout;
          if (csrf_token) {
            xhr.setRequestHeader("X-CSRF-Token", csrf_token);
          }
          xhr.onload = handler;
          xhr.onerror = handler;
          xhr.onabort = handler;
          xhr.send(snapshot._jpeg_blob);
          return snapshot._xhr = xhr;
        } else {
          this._debug("Generating JPEG file");
          if (snapshot._mirror) {
            canvas = document.createElement("canvas");
            canvas.width = snapshot._canvas.width;
            canvas.height = snapshot._canvas.height;
            context = canvas.getContext("2d");
            context.setTransform(1, 0, 0, 1, 0, 0);
            context.translate(canvas.width, 0);
            context.scale(-1, 1);
            context.drawImage(snapshot._canvas, 0, 0);
          } else {
            canvas = snapshot._canvas;
          }
          return canvas.toBlob(function(blob) {
            snapshot._jpeg_blob = blob;
            return that._engine_upload(snapshot, api_url, csrf_token, timeout);
          }, "image/jpeg", this.quality);
        }
      };

      JpegCameraHtml5.prototype._remove_message = function() {
        return this.message.style.display = "none";
      };

      JpegCameraHtml5.prototype._load_shutter_sound = function() {
        var request, that;
        if (this.audio_context) {
          return;
        }
        this.audio_context = new AudioContext();
        request = new XMLHttpRequest();
        request.open('GET', this.options.shutter_url, true);
        request.responseType = 'arraybuffer';
        that = this;
        request.onload = function() {
          return that.audio_context.decodeAudioData(request.response, function(buffer) {
            return that.shutter_buffer = buffer;
          });
        };
        return request.send();
      };

      JpegCameraHtml5.prototype._wait_for_video_ready = function() {
        var crop, that, video_height, video_width;
        video_width = parseInt(this.video.videoWidth);
        video_height = parseInt(this.video.videoHeight);
        if (video_width > 0 && video_height > 0) {
          this.video_container.appendChild(this.video);
          this.video_width = video_width;
          this.video_height = video_height;
          this._debug("Camera resolution " + this.video_width + "x" + this.video_height + "px");
          crop = this._get_video_crop();
          this.video.style.position = "relative";
          this.video.style.width = "" + crop.width + "px";
          this.video.style.height = "" + crop.height + "px";
          this.video.style.left = "" + crop.x_offset + "px";
          this.video.style.top = "" + crop.y_offset + "px";
          return this._prepared();
        } else if (this._status_checks_count > 100) {
          return this._got_error("Camera failed to initialize in 10 seconds");
        } else {
          this._status_checks_count++;
          that = this;
          return setTimeout((function() {
            return that._wait_for_video_ready();
          }), 100);
        }
      };

      JpegCameraHtml5.prototype._status_checks_count = 0;

      JpegCameraHtml5.prototype._add_prefixed_style = function(element, style, value) {
        var uppercase_style;
        uppercase_style = style.charAt(0).toUpperCase() + style.slice(1);
        element.style[style] = value;
        element.style["Webkit" + uppercase_style] = value;
        element.style["Moz" + uppercase_style] = value;
        element.style["ms" + uppercase_style] = value;
        return element.style["O" + uppercase_style] = value;
      };

      JpegCameraHtml5.prototype._get_video_crop = function() {
        var scaled_video_height, scaled_video_width, video_ratio, video_scale, view_height, view_ratio, view_width;
        view_width = this._view_width();
        view_height = this._view_height();
        video_ratio = this.video_width / this.video_height;
        view_ratio = view_width / view_height;
        if (video_ratio >= view_ratio) {
          this._debug("Filling height");
          video_scale = view_height / this.video_height;
          scaled_video_width = Math.round(this.video_width * video_scale);
          return {
            width: scaled_video_width,
            height: view_height,
            x_offset: -Math.floor((scaled_video_width - view_width) / 2.0),
            y_offset: 0
          };
        } else {
          this._debug("Filling width");
          video_scale = view_width / this.video_width;
          scaled_video_height = Math.round(this.video_height * video_scale);
          return {
            width: view_width,
            height: scaled_video_height,
            x_offset: 0,
            y_offset: -Math.floor((scaled_video_height - view_height) / 2.0)
          };
        }
      };

      JpegCameraHtml5.prototype._get_capture_crop = function() {
        var snapshot_height, snapshot_width, video_ratio, view_height, view_ratio, view_width;
        view_width = this._view_width();
        view_height = this._view_height();
        video_ratio = this.video_width / this.video_height;
        view_ratio = view_width / view_height;
        if (video_ratio >= view_ratio) {
          snapshot_width = Math.round(this.video_height * view_ratio);
          return {
            width: snapshot_width,
            height: this.video_height,
            x_offset: Math.floor((this.video_width - snapshot_width) / 2.0),
            y_offset: 0
          };
        } else {
          snapshot_height = Math.round(this.video_width / view_ratio);
          return {
            width: this.video_width,
            height: snapshot_height,
            x_offset: 0,
            y_offset: Math.floor((this.video_height - snapshot_height) / 2.0)
          };
        }
      };

      return JpegCameraHtml5;

    })(JpegCamera);
    ({
      video_width: null,
      video_height: null
    });
    window.JpegCamera = JpegCameraHtml5;
  }

  Snapshot = (function() {
    Snapshot._next_snapshot_id = 1;

    function Snapshot(camera, options) {
      this.camera = camera;
      this.options = options;
      this.id = this.constructor._next_snapshot_id++;
    }

    Snapshot.prototype._discarded = false;

    Snapshot.prototype.show = function() {
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      this.camera._display(this);
      return this;
    };

    Snapshot.prototype.hide = function() {
      if (this.camera.displayed_snapshot() === this) {
        this.camera.show_stream();
      }
      return this;
    };

    Snapshot.prototype.upload = function(options) {
      var cache, csrf_token;
      if (options == null) {
        options = {};
      }
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      if (this._uploading) {
        this._debug("Upload already in progress");
        return;
      }
      this._uploading = true;
      this._upload_options = options;
      cache = this._options();
      if (!cache.api_url) {
        this.camera._debug("Snapshot#upload called without valid api_url");
        throw "Snapshot#upload called without valid api_url";
      }
      if ("string" === typeof cache.csrf_token && cache.csrf_token.length > 0) {
        csrf_token = cache.csrf_token;
      } else {
        csrf_token = null;
      }
      this._done = false;
      this._response = null;
      this._fail = false;
      this._status = null;
      this._error_message = null;
      this.camera._upload(this, cache.api_url, csrf_token, cache.timeout);
      return this;
    };

    Snapshot.prototype._upload_options = {};

    Snapshot.prototype._uploading = false;

    Snapshot.prototype.done = function(callback) {
      var cache;
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      this._upload_options.on_upload_done = callback;
      cache = this._options();
      if (cache.on_upload_done && this._done) {
        cache.on_upload_done.call(this, this._response);
      }
      return this;
    };

    Snapshot.prototype._done = false;

    Snapshot.prototype._response = null;

    Snapshot.prototype.fail = function(callback) {
      var cache;
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      this._upload_options.on_upload_fail = callback;
      cache = this._options();
      if (cache.on_upload_fail && this._fail) {
        cache.on_upload_fail.call(this, this._status, this._error_message, this._response);
      }
      return this;
    };

    Snapshot.prototype._fail = false;

    Snapshot.prototype._status = null;

    Snapshot.prototype._error_message = null;

    Snapshot.prototype.discard = function() {
      this.camera._discard(this);
      return void 0;
    };

    Snapshot.prototype._options = function() {
      return this.camera._extend({}, this.camera.options, this.options, this._upload_options);
    };

    Snapshot.prototype._upload_done = function() {
      var cache;
      this.camera._debug("Upload completed");
      this._uploading = false;
      this._done = true;
      cache = this._options();
      if (cache.on_upload_done) {
        return cache.on_upload_done.call(this, this._response);
      }
    };

    Snapshot.prototype._upload_fail = function() {
      var cache;
      this.camera._debug("Upload failed with status " + this._status);
      this._uploading = false;
      this._fail = true;
      cache = this._options();
      if (cache.on_upload_fail) {
        return cache.on_upload_fail.call(this, this._status, this._error_message, this._response);
      }
    };

    return Snapshot;

  })();

}).call(this);
