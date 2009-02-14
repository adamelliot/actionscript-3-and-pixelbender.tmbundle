#!/usr/bin/env ruby
#
# Lookup Selection - Use the flex docs online to get help
#
# Created by Adam Elliot <adam.elliot@gmail.com> (2007-04-15)
#

require "rexml/document"
require ENV["TM_SUPPORT_PATH"] + "/lib/web_preview"
require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"

BASE_URL = "http://livedocs.adobe.com/flex/3/langref/"
# This should likely pull from the web, but that can come later.
XML_SOURCE = ENV["TM_BUNDLE_SUPPORT"] + "/lib/as3-classes.xml"

def get_doc_path class_name
  url = nil
  file = File.new XML_SOURCE
  doc = REXML::Document.new(file, {:compress_whitespace => :all})

  # This might be a bit hack, XPath may work better, but this may be quicker
  doc.elements.each("table/tbody/tr/td/a") do |element| 
      url = BASE_URL + element.attributes["href"] if element.text == class_name
  end

  url
end

# Send the page to the document we want
def open_page url
  puts <<PLAYER
<html>
<head>
  <script>
    function redirect() {
      document.location.href = "#{url}";
    }
  </script>
</head>
<body onload="redirect()"></body>
</html>
PLAYER
end

#def get_namespace_from_classname classname
#  file = File.new(ENV["TM_FILEPATH"], "r")
#
#  while line = file.gets do
#    if classpath = /import[ \t]+(.+)#{classname};/.match(line)
#      path = classpath[1].split('.')
#      next if path[0] != "flash"
#      return path
#    end
#  end
#
#  false
#end

open_page get_doc_path(ENV["TM_CURRENT_WORD"])
TextMate.exit_show_html