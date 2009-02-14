#!/usr/bin/env ruby -wKU

require 'mongrel'

require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"
require ENV['TM_SUPPORT_PATH'] + "/lib/progress"
require ENV["TM_SUPPORT_PATH"] + "/lib/web_preview"
require ENV["TM_SUPPORT_PATH"] + "/lib/escape"

module FlashMate

  # This should be tested and generated
  SERVER_PORT = 3579
  HOSTNAME = "0.0.0.0"

  class SWF
    attr_reader :path, :width, :height, :color, :messages

    def initialize(path, width, height, color = "##ffffff", messages = {})
      @path = path
      @width = width
      @height = height
      @color = color
      @messages = messages
    end
  end

  class FlashServer
    def initialize(swf, debugger = nil, port = SERVER_PORT)
      @debugger = debugger
      @port = port

      @server = Mongrel::HttpServer.new(HOSTNAME, port)
      @server.register("/_swf", Mongrel::DirHandler.new(swf.path))
      @server.register("/_shutdown", ShutdownHandler.new(@server))
      @server.register("/_scripts", ScriptsHandler.new(swf, debugger, self))
      @server.register("/_player", Mongrel::DirHandler.new("#{ENV['TM_BUNDLE_SUPPORT']}/player/index.html"))
      @server.register("/_javascripts", Mongrel::DirHandler.new("#{ENV['TM_BUNDLE_SUPPORT']}/player/_javascripts"))
      @server.register("/", Mongrel::DirHandler.new(File.dirname(swf.path)))

      trap("INT") {@server.stop}
    end

    def run
      @server.run
    end

    def url
      return "http://#{HOSTNAME}:#{@port}"
    end
  end

  class PixelBenderServer < FlashServer
    def initialize(pbj)
      # TODO: Make sure this path works properly
#      super("pbj_player.swf")
    end
  end

  # Once the message handler is called it calls the shutdown handler
  class ScriptsHandler < Mongrel::HttpHandler
    def initialize(swf, debugger, server)
      @swf = swf
      @debugger = debugger
      @server = server
      
      @swf_loaded = false
    end

    def process(request, response)
      response.start(200) do |head,out|
        # Put a delay between the calls
        sleep 0.2
        head["Content-Type"] = "text/javascript"

        unless @swf_loaded then
          @swf.messages.each do |msg|
            m = msg.to_debug
            m.gsub!(/'/) { |match| "\\#{match}" }
            m.gsub!(/[\n\r]/) { |match| "" }
            out.write "Warptube.Debug.trace('#{m}');"
          end

          out.write("Warptube.Debug.loadSWF('/_swf', '#{@swf.width}', " +
            "'#{@swf.height}', '#{@swf.color}');")
          @swf_loaded = true

          # We need a small delay to make sure everything is all setup
          # on the page before we begin debugging.
          sleep 0.5
        end

        if @debugger then
          if @debugger.debugging then
            @debugger.each_message do |message|
              msg = message.gsub(/(')/) {|match| "\\#{match}"}
              out.write("Warptube.Debug.trace('#{msg}');")
            end

            out.write("$.getScript('/_scripts');")
          else
            @server.stop
          end
        else
          out.write("$.getScript('/_shutdown');")
        end
      end
    end
  end

  # When something calls this handler it will stop the server
  class ShutdownHandler < Mongrel::HttpHandler
    def initialize(server)
      raise "Need to have a server to shutdown for this handler to work." unless server
      @server = server
    end
    
    def process(request, response)
      response.start(200) {}
      @server.stop
    end
  end
  
  # Shows a page with all the compiler messages, this is used usually when
  # a compile fails and we don't open the runtime page
  def FlashMate.display_messages messages
    puts html_head(:window_title => "ActionScript Compiler Messages",
      :page_title => "ActionScript Compiler Messages")

    messages.each do |message|
      puts message.to_debug
      puts "<br />"
    end
    
    html_footer
  end
  
  # Causes a JS redirect inside a TextMate HTML window to the specified URL.
  def FlashMate.open_page url
    puts <<PLAYER
<html>
<body onload="document.location.href = '#{url}'"></body>
</html>
PLAYER
  end
  
  def FlashMate.namespace
    print ENV["TM_NEW_FILE_DIRECTORY"].sub(/#{ENV["TM_PROJECT_DIRECTORY"]}\/*/, "").gsub(/\//, ".") + " "
  end
end

# Extend Hash so we have our conversion to our debug output
class Hash
  def to_debug
#    return "[No message]" unless self[:file] || self[:message]

    message = ""

    message += "<em>#{self[:type]}:</em> " if self[:type]
    message += self[:message] if self[:message]
    message += "<br />"

    if self[:file]
      link_message = "#{self[:file]}"

      link = "txmt://open?url=file://#{self[:file]}"
      if self[:line]
        link += "&line=#{self[:line]}"
        link_message += " - (#{self[:line]})"
      end
      link += "&column=#{self[:column]}" if self[:column]

      message += "&nbsp;&nbsp;<a href=\"#{link}\">#{link_message}</a>"
    end

    # TODO: Parse extra data if it exists.

    return message
  end
end