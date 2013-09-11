# Contains some pixel statistics of {Snapshot} or camera stream.
#
# Can be retrieved using {JpegCamera#get_stats} or {Snapshot#get_stats} methods.
class Stats
  # @property [Float] mean gray value of pixels (0-255)
  mean: null

  # @property [Float] standard deviation of gray values
  std: null
