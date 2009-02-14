#!/usr/bin/env ruby
#
# Run - compile ActionScript3 using Flex 2 SDK (mxmlc)
#
# Created by Adam Elliot <adam.elliot@gmail.com> to work with Flex 2 (AS3) (2007-04-15)
#
# This code has been designed to be used with Flex 2 SDK.
# It uses fdb for tracing although no other debugging support currently exists.
# Reading bookmarks as breakpoints is next.
#
# NOTE: For the trace to work properly you will need the web debug player.
#

require "open3"
require "yaml"
require "date"

require ENV['TM_SUPPORT_PATH'] + "/lib/exit_codes"
require ENV['TM_SUPPORT_PATH'] + "/lib/progress"
require ENV["TM_SUPPORT_PATH"] + "/lib/web_preview"
require ENV["TM_SUPPORT_PATH"] + "/lib/escape"

# Some routes
@file_path = ENV['TM_FILEPATH']
@file_name = ENV['TM_FILENAME']
@project_path = ENV['TM_PROJECT_DIRECTORY']

@project_name = "project.yml"
@compiler = "mxmlc"

@project_path = File.dirname @file_path unless File.exist?("#{@project_path}/#{@project_name}")
@project = "#{@project_path}/#{@project_name}"

@document_class = File.basename(@file_name, ".as")
@output_swf = @document_class + ".swf"
@flex_sdk_bin = "" # Assume it's on the path already
# Compiler options passed to mxmlc, check:
# http://livedocs.adobe.com/flex/2/docs/wwhelp/wwhimpl/common/html/wwhelp.htm?context=LiveDocs_Parts&file=00001508.html
# For a full list of the options
@compile_options = {
  "default-size" => [400, 300],
  "default-frame-rate" => 24,
  "compiler.debug" => false,
# FIXME: If you have spaces in metadata mxmlc chokes.  The doc says this
# shouldn't happen, but I am unable to find a work around.
  "metadata.date" => Date.today.to_s,
  "use-network" => true
#  "metadata.creator" => "#{ENV["TM_ORGANIZATION_NAME"]}",
}

# Sets the compiler variables and the global projec variables
def read_yml
  yml = YAML.load(File.open(@project))
  file_name = @document_class

  @document_class = yml['document-class'] if ['document-class']
  if yml['document-classes']
    @document_class = yml['document-classes'][0]
    yml['document-classes'].each { |v| @document_class = v if v == file_name }
  end
  @flex_sdk_bin = yml['flex-sdk-bin'] if ['flex-sdk-bin']
  yml['compile-options'].each { |k,v| @compile_options[k] = v } if yml['compile-options']

  @output_swf = yml['compile-options']['output'] || @document_class + ".swf"
end

# Prints a list of messages from the compiler and creates links to the documents
def print_message_list messages
  messages.each do |msg|
    file = File.basename msg[1]
    link = "txmt://open?url=file://#{msg[1]}&line=#{msg[2]}&column=#{msg[3]}"
    html = "<a href=\"#{link}\">#{file} - (#{msg[2]})</a><br />&nbsp;&nbsp;<b>#{msg[4]}:</b> #{msg[5]}</a><br />"
    puts html
  end
end

# Interprets the output from the compiler
def process_output command
  @warnings = [] # Keep global so we can show the warnings with the swf
  errors = []

  stdin, stdout, stderr = Open3.popen3(command)

  while msg = stderr.gets do
    message = /(.+)\(([0-9]+)\): col: ([0-9]+) (Error|Warning): (.*)/.match(msg)

    if message then
      array = case message[4]
        when "Warning" then @warnings
        when "Error" then errors
      end

      array.push(message)
    end

    4.times {stderr.gets}
  end

  unless errors.empty? then
    puts html_head(:window_title => "ActionScript 3 — Errors", :page_title => "Errors for #{@document_class}")
    puts "#{@command}\n\n<br />"
    print_message_list errors
    html_footer
    TextMate.exit_show_html

    false # Code shouldn't get here
  else
    true
  end
end

# Run the secondary debugger script that will update our trace
def load_debugger
  pid = Process.fork do
    STDOUT.close
    STDERR.close

    debug_loop = ENV["TM_BUNDLE_SUPPORT"] + "/lib/debug_loop.rb"
    `ruby #{e_sh debug_loop} #{@output_swf} #{e_sh @flex_sdk_bin} &> /dev/null &`
  end
  Process.detach pid

  sleep 0.6 # Give the debugger a moment to load
end

# Creates an HTML window with a flash player and loads the new SWF
def display_web_player
  w = @compile_options['default-size'][0]
  h = @compile_options['default-size'][1]

  puts html_head(:window_title => "ActionScript 3 — Player", :page_title => "Flash Player for #{@document_class}")

  puts @command

  puts <<PLAYER
	  <div style="margin:auto;margin-top:22px;border:solid thin #72a1ed;width:#{w}px;height:#{h}px"> 
      <embed src="file://#{@project_path}/#{@output_swf}" type="application/x-shockwave-flash" quality="high" bgcolor="#ffffff" width="#{w}" height="#{h}" name="player" align="middle" />
    </div>
PLAYER

 unless @warnings.empty?
   puts '<br /><div><h3>Warnings:</h3>'
   print_message_list @warnings
   puts '</div>'
 end
  
  html_footer
  TextMate.exit_show_html
end

def display_player

  %x{open "#{@project_path}/#{@output_swf}"}

  unless @warnings.empty?
    puts html_head(:window_title => "ActionScript 3 — Player", :page_title => "Flash Player 9 for #{@document_class}")
    puts '<br /><div><h3>Warnings:</h3>'
    print_message_list @warnings
    puts '</div>'
    html_footer
    TextMate.exit_show_html
  end
end

# Compiles the swf based on the project or currently selected file
def compile
  read_yml if File.exists?(@project)

  default_options = {}
  other_options = {}

  @compile_options.each do |k,v| 
    if /default/.match(k)
      default_options[k] = v
    else
      other_options[k] = v
    end
  end

  command = "#{@flex_sdk_bin}#{@compiler}"
  other_options.each { |k,v| command += " -#{k}=\"#{[v].flatten.join ','}\"" }
  default_options.each { |k,v| command += " -#{k}=\"#{[v].flatten.join ','}\"" }
  command += " #{@document_class}.as"

#  puts command
#  TextMate.exit_show_html

  @command = command
#TextMate.exit_show_html
  if process_output command
#    load_debugger
    display_web_player #unless ARGV[0] = "--display"
#    display_player
  end
end

# compile with MTASC
TextMate.call_with_progress({:title => "Action Script 3 Complier", :message => "Compiling ActionScript..."}) do
  compile
end