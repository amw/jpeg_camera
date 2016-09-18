/*! JpegCamera 1.3.3 | 2016-09-18
    (c) 2013 Adam Wrobel
    https://amw.github.io/jpeg_camera */
(function() {
  var JpegCamera, JpegCameraHtml5, Snapshot, Stats, can_play, check_canvas_to_blob, mpeg_audio, vorbis_audio, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  JpegCamera = (function() {
    JpegCamera.DefaultOptions = {
      shutter_ogg_url: "/jpeg_camera/shutter.ogg",
      shutter_mp3_url: "/jpeg_camera/shutter.mp3",
      swf_url: "/jpeg_camera/jpeg_camera.swf",
      on_debug: function(message) {
        if (console && console.log) {
          return console.log("JpegCamera: " + message);
        }
      },
      quality: 0.9,
      shutter: true,
      mirror: false,
      timeout: 0,
      retry_success: false,
      scale: 1.0
    };

    JpegCamera._canvas_supported = !!document.createElement('canvas').getContext;

    JpegCamera.canvas_supported = function() {
      return this._canvas_supported;
    };

    function JpegCamera(container, options) {
      if ("string" === typeof container) {
        container = document.getElementById(container.replace("#", ""));
      }
      if (!(container && container.offsetWidth)) {
        throw "JpegCamera: invalid container";
      }
      container.innerHTML = "";
      this.view_width = parseInt(container.offsetWidth, 10);
      this.view_height = parseInt(container.offsetHeight, 10);
      this.container = document.createElement("div");
      this.container.style.width = "100%";
      this.container.style.height = "100%";
      this.container.style.position = "relative";
      container.appendChild(this.container);
      this.options = this._extend({}, this.constructor.DefaultOptions, options);
      this._engine_init();
    }

    JpegCamera.prototype.ready = function(callback) {
      this.options.on_ready = callback;
      if (this.options.on_ready && this._is_ready) {
        this.options.on_ready.call(this, {
          video_width: this.video_width,
          video_height: this.video_height
        });
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

    JpegCamera.StatsCaptureScale = 0.2;

    JpegCamera.prototype.get_stats = function(callback) {
      var snapshot, that;
      snapshot = new Snapshot(this, {});
      this._engine_capture(snapshot, false, 0.1, JpegCamera.StatsCaptureScale);
      that = this;
      return snapshot.get_stats(function(stats) {
        return callback.call(that, stats);
      });
    };

    JpegCamera.prototype.capture = function(options) {
      var scale, snapshot, _options;
      if (options == null) {
        options = {};
      }
      snapshot = new Snapshot(this, options);
      this._snapshots[snapshot.id] = snapshot;
      _options = snapshot._options();
      if (_options.shutter) {
        this._engine_play_shutter_sound();
      }
      scale = Math.min(1.0, _options.scale);
      scale = Math.max(0.01, scale);
      this._engine_capture(snapshot, _options.mirror, _options.quality, scale);
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

    JpegCamera.prototype._display = function(snapshot) {
      this._engine_display(snapshot);
      return this._displayed_snapshot = snapshot;
    };

    JpegCamera.prototype._displayed_snapshot = null;

    JpegCamera.prototype._discard = function(snapshot) {
      if (this._displayed_snapshot === snapshot) {
        this.show_stream();
      }
      this._engine_discard(snapshot);
      snapshot._discarded = true;
      return delete this._snapshots[snapshot.id];
    };

    JpegCamera.prototype._prepared = function(video_width, video_height) {
      var that;
      this.video_width = video_width;
      this.video_height = video_height;
      this._debug("Camera resolution " + this.video_width + "x" + this.video_height + "px");
      that = this;
      return setTimeout((function() {
        return that._wait_until_stream_looks_ok(true);
      }), 1);
    };

    JpegCamera.prototype._wait_until_stream_looks_ok = function(show_debug) {
      return this.get_stats(function(stats) {
        var that;
        if (stats.std > 2) {
          this._debug("Stream mean gray value = " + stats.mean + " standard deviation = " + stats.std);
          this._debug("Camera is ready");
          this._is_ready = true;
          if (this.options.on_ready) {
            return this.options.on_ready.call(this, {
              video_width: this.video_width,
              video_height: this.video_height
            });
          }
        } else {
          if (show_debug) {
            this._debug("Stream mean gray value = " + stats.mean + " standard deviation = " + stats.std);
          }
          that = this;
          return setTimeout((function() {
            return that._wait_until_stream_looks_ok(false);
          }), 100);
        }
      });
    };

    JpegCamera.prototype._got_error = function(error) {
      this._debug("Error - " + error);
      this._error_occured = error;
      if (this.options.on_error) {
        return this.options.on_error.call(this, this._error_occured);
      }
    };

    JpegCamera.prototype._block_element_access = function() {
      this._overlay = document.createElement("div");
      this._overlay.style.width = "100%";
      this._overlay.style.height = "100%";
      this._overlay.style.position = "absolute";
      this._overlay.style.top = 0;
      this._overlay.style.left = 0;
      this._overlay.style.zIndex = 2;
      return this.container.appendChild(this._overlay);
    };

    JpegCamera.prototype._overlay = null;

    JpegCamera.prototype.view_width = null;

    JpegCamera.prototype.view_height = null;

    JpegCamera._add_prefixed_style = function(element, style, value) {
      var uppercase_style;
      uppercase_style = style.charAt(0).toUpperCase() + style.slice(1);
      element.style[style] = value;
      element.style["Webkit" + uppercase_style] = value;
      element.style["Moz" + uppercase_style] = value;
      element.style["ms" + uppercase_style] = value;
      return element.style["O" + uppercase_style] = value;
    };

    return JpegCamera;

  })();

  navigator.getUserMedia || (navigator.getUserMedia = navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia);

  window.AudioContext || (window.AudioContext = window.webkitAudioContext);

  check_canvas_to_blob = function() {
    var canvas;
    canvas = document.createElement("canvas");
    if (canvas.getContext && !canvas.toBlob) {
      throw "JpegCamera: Canvas-to-Blob is not loaded";
    }
  };

  if (navigator.getUserMedia) {
    check_canvas_to_blob();
    vorbis_audio = "audio/ogg; codecs=vorbis";
    mpeg_audio = "audio/mpeg; ";
    can_play = function(type) {
      var elem;
      elem = document.createElement("video");
      return !!(elem.canPlayType && elem.canPlayType(type).replace(/no/, ''));
    };
    JpegCameraHtml5 = (function(_super) {
      __extends(JpegCameraHtml5, _super);

      function JpegCameraHtml5() {
        _ref = JpegCameraHtml5.__super__.constructor.apply(this, arguments);
        return _ref;
      }

      JpegCameraHtml5.prototype._engine_init = function() {
        var error, failure, get_user_media_options, horizontal_padding, success, that, vertical_padding;
        this._debug("Using HTML5 engine");
        vertical_padding = Math.floor(this.view_height * 0.2);
        horizontal_padding = Math.floor(this.view_width * 0.2);
        this.message = document.createElement("div");
        this.message["class"] = "message";
        this.message.style.width = "100%";
        this.message.style.height = "100%";
        JpegCamera._add_prefixed_style(this.message, "boxSizing", "border-box");
        this.message.style.overflow = "hidden";
        this.message.style.textAlign = "center";
        this.message.style.paddingTop = "" + vertical_padding + "px";
        this.message.style.paddingBottom = "" + vertical_padding + "px";
        this.message.style.paddingLeft = "" + horizontal_padding + "px";
        this.message.style.paddingRight = "" + horizontal_padding + "px";
        this.message.style.position = "absolute";
        this.message.style.zIndex = 3;
        this.message.innerHTML = "Please allow camera access when prompted by the browser.<br><br>" + "Look for camera icon around your address bar.";
        this.container.appendChild(this.message);
        this.video_container = document.createElement("div");
        this.video_container.style.width = "" + this.view_width + "px";
        this.video_container.style.height = "" + this.view_height + "px";
        this.video_container.style.overflow = "hidden";
        this.video_container.style.position = "absolute";
        this.video_container.style.zIndex = 1;
        this.container.appendChild(this.video_container);
        this.video = document.createElement('video');
        this.video.autoplay = true;
        JpegCamera._add_prefixed_style(this.video, "transform", "scalex(-1.0)");
        if (window.AudioContext) {
          if (can_play(vorbis_audio)) {
            this._load_shutter_sound(this.options.shutter_ogg_url);
          } else if (can_play(mpeg_audio)) {
            this._load_shutter_sound(this.options.shutter_mp3_url);
          }
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
        success = function(stream) {
          that._remove_message();
          if (window.URL) {
            that.video.src = URL.createObjectURL(stream);
          } else {
            that.video.src = stream;
          }
          that._block_element_access();
          return that._wait_for_video_ready();
        };
        failure = function(error) {
          var code, key, value;
          that.message.innerHTML = "<span style=\"color: red;\">" + "You have denied camera access." + "</span><br><br>" + "Look for camera icon around your address bar to change your " + "decision.";
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
        };
        try {
          return navigator.getUserMedia(get_user_media_options, success, failure);
        } catch (_error) {
          error = _error;
          return navigator.getUserMedia("video", success, failure);
        }
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

      JpegCameraHtml5.prototype._engine_capture = function(snapshot, mirror, quality, scale) {
        var canvas, context, crop;
        crop = this._get_capture_crop();
        canvas = document.createElement("canvas");
        canvas.width = Math.round(crop.width * scale);
        canvas.height = Math.round(crop.height * scale);
        context = canvas.getContext("2d");
        context.drawImage(this.video, crop.x_offset, crop.y_offset, crop.width, crop.height, 0, 0, Math.round(crop.width * scale), Math.round(crop.height * scale));
        snapshot._canvas = canvas;
        snapshot._mirror = mirror;
        return snapshot._quality = quality;
      };

      JpegCameraHtml5.prototype._engine_display = function(snapshot) {
        if (this.displayed_canvas) {
          this.container.removeChild(this.displayed_canvas);
        }
        this.displayed_canvas = snapshot._canvas;
        this.displayed_canvas.style.width = "" + this.view_width + "px";
        this.displayed_canvas.style.height = "" + this.view_height + "px";
        this.displayed_canvas.style.top = 0;
        this.displayed_canvas.style.left = 0;
        this.displayed_canvas.style.position = "absolute";
        this.displayed_canvas.style.zIndex = 2;
        JpegCamera._add_prefixed_style(this.displayed_canvas, "transform", "scalex(-1.0)");
        return this.container.appendChild(this.displayed_canvas);
      };

      JpegCameraHtml5.prototype._engine_get_canvas = function(snapshot) {
        var canvas, context;
        canvas = document.createElement("canvas");
        canvas.width = snapshot._canvas.width;
        canvas.height = snapshot._canvas.height;
        context = canvas.getContext("2d");
        context.drawImage(snapshot._canvas, 0, 0);
        return canvas;
      };

      JpegCameraHtml5.prototype._engine_get_image_data = function(snapshot) {
        var canvas, context;
        canvas = snapshot._canvas;
        context = canvas.getContext("2d");
        return context.getImageData(0, 0, canvas.width, canvas.height);
      };

      JpegCameraHtml5.prototype._engine_get_blob = function(snapshot, mime, mirror, quality, callback) {
        var canvas, context;
        if (mirror) {
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
        return canvas.toBlob((function(blob) {
          return callback(blob);
        }), mime, quality);
      };

      JpegCameraHtml5.prototype._engine_discard = function(snapshot) {
        if (snapshot._xhr) {
          snapshot._xhr.abort();
        }
        delete snapshot._xhr;
        return delete snapshot._canvas;
      };

      JpegCameraHtml5.prototype._engine_show_stream = function() {
        if (this.displayed_canvas) {
          this.container.removeChild(this.displayed_canvas);
          this.displayed_canvas = null;
        }
        return this.video_container.style.display = "block";
      };

      JpegCameraHtml5.prototype._engine_upload = function(snapshot, api_url, csrf_token, timeout) {
        this._debug("Uploading the file");
        return snapshot.get_blob(function(blob) {
          var handler, xhr;
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
          xhr.send(blob);
          return snapshot._xhr = xhr;
        }, "image/jpeg");
      };

      JpegCameraHtml5.prototype._remove_message = function() {
        return this.message.style.display = "none";
      };

      JpegCameraHtml5.prototype._load_shutter_sound = function(url) {
        var request, that;
        if (this.audio_context) {
          return;
        }
        this.audio_context = new AudioContext();
        request = new XMLHttpRequest();
        request.open('GET', url, true);
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
          crop = this._get_video_crop();
          this.video.style.position = "relative";
          this.video.style.width = "" + crop.width + "px";
          this.video.style.height = "" + crop.height + "px";
          this.video.style.left = "" + crop.x_offset + "px";
          this.video.style.top = "" + crop.y_offset + "px";
          return this._prepared(this.video_width, this.video_height);
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

      JpegCameraHtml5.prototype._get_video_crop = function() {
        var scaled_video_height, scaled_video_width, video_ratio, video_scale, view_ratio;
        video_ratio = this.video_width / this.video_height;
        view_ratio = this.view_width / this.view_height;
        if (video_ratio >= view_ratio) {
          this._debug("Filling height");
          video_scale = this.view_height / this.video_height;
          scaled_video_width = Math.round(this.video_width * video_scale);
          return {
            width: scaled_video_width,
            height: this.view_height,
            x_offset: -Math.floor((scaled_video_width - this.view_width) / 2.0),
            y_offset: 0
          };
        } else {
          this._debug("Filling width");
          video_scale = this.view_width / this.video_width;
          scaled_video_height = Math.round(this.video_height * video_scale);
          return {
            width: this.view_width,
            height: scaled_video_height,
            x_offset: 0,
            y_offset: -Math.floor((scaled_video_height - this.view_height) / 2.0)
          };
        }
      };

      JpegCameraHtml5.prototype._get_capture_crop = function() {
        var snapshot_height, snapshot_width, video_ratio, view_ratio;
        video_ratio = this.video_width / this.video_height;
        view_ratio = this.view_width / this.view_height;
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

    Snapshot.prototype.get_stats = function(callback) {
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      return this.get_image_data(function(data) {
        return this._get_stats(data, callback);
      });
    };

    Snapshot.prototype.get_canvas = function(callback) {
      var that;
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      if (!JpegCamera._canvas_supported) {
        false;
      }
      that = this;
      setTimeout(function() {
        that._extra_canvas || (that._extra_canvas = that.camera._engine_get_canvas(that));
        JpegCamera._add_prefixed_style(that._extra_canvas, "transform", "scalex(-1.0)");
        return callback.call(that, that._extra_canvas);
      }, 1);
      return true;
    };

    Snapshot.prototype._extra_canvas = null;

    Snapshot.prototype.get_blob = function(callback, mime_type) {
      var that;
      if (mime_type == null) {
        mime_type = "image/jpeg";
      }
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      if (!JpegCamera._canvas_supported) {
        false;
      }
      that = this;
      setTimeout(function() {
        var mirror, quality;
        if (that._blob_mime !== mime_type) {
          that._blob = null;
        }
        that._blob_mime = mime_type;
        if (that._blob) {
          return callback.call(that, that._blob);
        } else {
          mirror = that.options.mirror;
          quality = that.options.quality;
          return that.camera._engine_get_blob(that, mime_type, mirror, quality, function(b) {
            that._blob = b;
            return callback.call(that, that._blob);
          });
        }
      }, 1);
      return true;
    };

    Snapshot.prototype._blob = null;

    Snapshot.prototype._blob_mime = null;

    Snapshot.prototype.get_image_data = function(callback) {
      var that;
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      that = this;
      setTimeout(function() {
        that._image_data || (that._image_data = that.camera._engine_get_image_data(that));
        return callback.call(that, that._image_data);
      }, 1);
      return null;
    };

    Snapshot.prototype._image_data = null;

    Snapshot.prototype.upload = function(options) {
      var cache;
      if (options == null) {
        options = {};
      }
      if (this._discarded) {
        raise("discarded snapshot cannot be used");
      }
      if (this._uploading) {
        this.camera._debug("Upload already in progress");
        return;
      }
      this._uploading = true;
      this._retry = 1;
      this._upload_options = options;
      cache = this._options();
      if (!cache.api_url) {
        this.camera._debug("Snapshot#upload called without valid api_url");
        throw "Snapshot#upload called without valid api_url";
      }
      this._start_upload(cache);
      return this;
    };

    Snapshot.prototype._upload_options = {};

    Snapshot.prototype._uploading = false;

    Snapshot.prototype._retry = 1;

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
      delete this._extra_canvas;
      delete this._image_data;
      delete this._blob;
      return void 0;
    };

    Snapshot.prototype._options = function() {
      return this.camera._extend({}, this.camera.options, this.options, this._upload_options);
    };

    Snapshot.prototype._start_upload = function(cache) {
      var csrf_token;
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
      return this.camera._engine_upload(this, cache.api_url, csrf_token, cache.timeout);
    };

    Snapshot.prototype._get_stats = function(data, callback) {
      var gray, gray_values, i, index, mean, n, sum, sum_of_square_distances, _i, _j, _len;
      if (!this._stats) {
        n = data.width * data.height;
        sum = 0.0;
        gray_values = new Array(n);
        for (i = _i = 0; _i < n; i = _i += 1) {
          index = i * 4;
          gray = 0.2126 * data.data[index + 0] + 0.7152 * data.data[index + 1] + 0.0722 * data.data[index + 2];
          gray = Math.round(gray);
          sum += gray;
          gray_values[i] = gray;
        }
        mean = Math.round(sum / n);
        sum_of_square_distances = 0;
        for (_j = 0, _len = gray_values.length; _j < _len; _j++) {
          gray = gray_values[_j];
          sum_of_square_distances += Math.pow(gray - mean, 2);
        }
        this._stats = new Stats();
        this._stats.mean = mean;
        this._stats.std = Math.round(Math.sqrt(sum_of_square_distances / n));
      }
      return callback.call(this, this._stats);
    };

    Snapshot.prototype._stats = null;

    Snapshot.prototype._upload_done = function() {
      var cache, delay, retry_decision, that;
      this.camera._debug("Upload completed with status " + this._status);
      this._done = true;
      cache = this._options();
      retry_decision = cache.retry_success && cache.retry_if && cache.retry_if.call(this, this._status, this._error_message, this._response, this._retry);
      if (true === retry_decision) {
        retry_decision = 0;
      }
      if ("number" === typeof retry_decision) {
        this._retry++;
        if (retry_decision > 0) {
          delay = parseInt(retry_decision);
          this.camera._debug("Will retry the upload in " + delay + "ms (attempt #" + this._retry + ")");
          that = this;
          return setTimeout((function() {
            return that._start_upload(cache);
          }), delay);
        } else {
          this.camera._debug("Will retry the upload immediately (attempt #" + this._retry + ")");
          return this._start_upload(cache);
        }
      } else {
        this._uploading = false;
        if (cache.on_upload_done) {
          return cache.on_upload_done.call(this, this._response);
        }
      }
    };

    Snapshot.prototype._upload_fail = function() {
      var cache, delay, retry_decision, that;
      this.camera._debug("Upload failed with status " + this._status);
      this._fail = true;
      cache = this._options();
      retry_decision = cache.retry_if && cache.retry_if.call(this, this._status, this._error_message, this._response, this._retry);
      if (true === retry_decision) {
        retry_decision = 0;
      }
      if ("number" === typeof retry_decision) {
        this._retry++;
        if (retry_decision > 0) {
          delay = parseInt(retry_decision);
          this.camera._debug("Will retry the upload in " + delay + "ms (attempt #" + this._retry + ")");
          that = this;
          return setTimeout((function() {
            return that._start_upload(cache);
          }), delay);
        } else {
          this.camera._debug("Will retry the upload immediately (attempt #" + this._retry + ")");
          return this._start_upload(cache);
        }
      } else {
        this._uploading = false;
        if (cache.on_upload_fail) {
          return cache.on_upload_fail.call(this, this._status, this._error_message, this._response);
        }
      }
    };

    return Snapshot;

  })();

  Stats = (function() {
    function Stats() {}

    Stats.prototype.mean = null;

    Stats.prototype.std = null;

    return Stats;

  })();

}).call(this);
