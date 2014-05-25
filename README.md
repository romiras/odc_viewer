odc_viewer
==========

odc_viewer is a small web-application for viewing ODC (BlackBox, Oberon/F) documents. It's written in Ruby language using Sinatra framework.

This program uses https://github.com/gertvv/odcread internally for converting ODC into plain text.


How to view ODC document (on local machine):

1. Run Rack server

2. Point a web-browser to:
    http://localhost:9292/odcviewer?odc=http://example.com/path/to/document.odc
