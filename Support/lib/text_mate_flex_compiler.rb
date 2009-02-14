#!/usr/bin/env ruby
# 
# text_mate_flex_compiler
#
# document-class: RootClass # Without it will just compile the active file
# flex-sdk: path/to/sdk # Defauls to ~/bin/flex/bin
# compile-options: # Optional, these args can come from the RootClass too
#   # A YML Object that describe the flash args for mxmlc
#   default-frame-rate: 30
#   default-size:
#     - 640
#     - 480

require 'yaml'
require 'daemons/daemonize'

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'flex_compiler'
require 'flash_debugger'

module FlashMate

  # TODO: The paths should be expanded and generalized.
  # This should point to the Flex 10 sdk, may work with the 9 versions
  FLEX_SDK = '/Users/adam/bin/flex/'
  AIR_SDK = '/Users/adam/bin/air/'
  PROJECT_FILE = 'project.yml'

  # Searches for either PROJECT_FILE or if project file cannot be found
  # traversing up to TM_PROJECT_DIRECTORY then the currently selected
  # file is used.
  # If we just use the default file then 
  def FlashMate.get_build_options
    ops = {}

    # Set the defaults
    ops[:basepath] = File.dirname(ENV['TM_FILEPATH'])
    ops[:file] = ENV['TM_FILEPATH']
    ops[:flex_sdk] = FLEX_SDK
    ops[:air_sdk] = AIR_SDK
    ops[:compiler_options] = {}

    d = ENV['TM_DIRECTORY']
    p = File.join(d, PROJECT_FILE)
    proj = p if File.exists? p

    while not File.identical?(ENV['TM_PROJECT_DIRECTORY'], d) do
      d = File.dirname d
      p = File.join(d, PROJECT_FILE)
      proj = p if File.exists? p
    end

    if proj then
      config = YAML.load(File.open(proj))
      if config['application-class'] then
        ops[:file] = File.join(File.dirname(proj), config['application-class']) + ".as"
        ops[:basepath] = File.dirname ops[:file]
      end
      ops[:flex_sdk] = config['flex-sdk'] || FLEX_SDK
      ops[:air_sdk] = config['air-sdk'] || AIR_SDK
      ops[:compiler_options] = config['compiler-options'] || {}
    end

    ops
  end

  def FlashMate.setup_flex_compile
    options = get_build_options
    fc = FlexCompiler.new options[:file],
      options[:flex_sdk], options[:compiler_options]

    return fc
  end

  def FlashMate.build_with_flex_compiler
    fc = FlashMate.setup_flex_compile

    TextMate.call_with_progress({:title => "Action Script 3 Complier", :message => "Compiling ActionScript..."}) do
      fc.build
    end

    unless fc.compiled_without_errors?
      FlashMate.display_messages fc.swf.messages
      # We have errors, make sure the output stops here.
      TextMate.exit_show_html
    end
    
    fc
  end

  # This function will daemonize the web server and debugger so
  def FlashMate.run_and_build_with_flex_compiler
    fc = FlashMate.build_with_flex_compiler

    Process.detach(fork do
      Daemonize.daemonize

      fdb = FlashDebugger.new fc.basedir, fc.sdk
      fs = FlashServer.new fc.swf, fdb

      fs.run
      fdb.run.join # When the debugger shuts down the swf has closed
    end)

    # TODO: Generalize this
    FlashMate.open_page "http://#{HOSTNAME}:#{SERVER_PORT}/_player"
    TextMate.exit_show_html
  end

end