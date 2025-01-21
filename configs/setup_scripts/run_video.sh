# Device 1
# Start the TCP Server to Send Video to Device 2:

gst-launch-1.0 -v \
  v4l2src device=/dev/video0 ! videoconvert ! \
  x264enc tune=zerolatency bitrate=500 speed-preset=superfast ! \
  mpegtsmux ! tcpserversink host=10.0.0.1 port=5000

# Start the TCP Client to Receive Video from Device 2:
gst-launch-1.0 -v \
  tcpclientsrc host=11.0.0.1 port=6000 ! tsdemux ! \
  h264parse ! avdec_h264 ! videoconvert ! autovideosink sync=false


# Device 1
# Start the TCP Server to Send Video to Device 1:
gst-launch-1.0 -v \
  v4l2src device=/dev/video0 ! videoconvert ! \
  x264enc tune=zerolatency bitrate=500 speed-preset=superfast ! \
  mpegtsmux ! tcpserversink host=11.0.0.1 port=6000

# Start the TCP Client to Receive Video from Device 1:
gst-launch-1.0 -v \
  tcpclientsrc host=10.0.0.1 port=5000 ! tsdemux ! \
  h264parse ! avdec_h264 ! videoconvert ! autovideosink sync=false


# Capture traffic using:
sudo tcpdump -i veth_host -w capture.pcap

# Visual representation:
# Device 1 (10.0.0.1)                      Device 2 (11.0.0.1)
# +----------------------+                 +----------------------+
# |                      |                 |                      |
# |  GStreamer Server    |  ---> TCP 5000 --->|  GStreamer Client   |
# |  (Send Video to 2)   |                 |  (Receive Video from 1) |
# |                      |                 |                      |
# |  GStreamer Client    |  <--- TCP 6000 ---|  GStreamer Server   |
# |  (Receive Video from 2)|               |  (Send Video to 1)   |
# |                      |                 |                      |
# +----------------------+                 +----------------------+
#            |                                         |
#            |                                         |
#            |               Ethernet Cable            |
#            +-----------------------------------------+