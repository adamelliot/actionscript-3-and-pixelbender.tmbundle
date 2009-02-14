#!/usr/bin/env ruby
#
# flex_compiler.rb
#
# This object will compile an ActionScript project using the Flex compiler
# chain. It expects a project file. The format for the file uses yml and
# should look like:

require 'flash_mate'
require 'open3'

module FlashMate
  # If nothing is set these are used when displaying the flash player.
  # They are the defaults flex uses.
  DEFAULT_WIDTH = 550
  DEFAULT_HEIGHT = 400

  MXMLC = 'mxmlc'

  class FlexCompiler
    attr_reader :swf, :sdk, :basedir, :source

    def initialize(source, sdk, options = {})
      @basedir = File.dirname source
      @source = source
      @options = options
      @sdk = sdk
      @success = true

      @messages = [] # All other messages are stored here, even missed errors
    end

    # Construct the mxmlc command
    def build
      args = ""

      parse_action_script_for_params
      @options['debug'] = true if @options['debug'].nil?
      @options.each { |k,v| args += " -#{k}=\"#{[v].flatten.join ','}\"" }

      @swf = SWF.new(File.join(@basedir,
        ("#{File.basename(@source, '.as')}.swf" || @options['output'])),
        @width || (@options['default-size'] && @options['default-size'][0]) || DEFAULT_WIDTH,
        @height || (@options['default-size'] && @options['default-size'][1]) || DEFAULT_HEIGHT,
        @color || @options['background-color'] || '#ffffff',
        @messages)

      mxmlc = File.join @sdk, "bin", MXMLC
      command = "cd #{@basedir}; #{mxmlc} #{args} #{@source}"
      stdin, stdout, stderr = Open3.popen3(command)
      @messages.push({:type => 'command', :message => command})

      while msg = stdout.gets do
        # TODO: Parse out these messages
        @messages.push({:message => msg})
      end

      while msg = stderr.gets do
        message = /(.+)\(([0-9]+)\): col: ([0-9]+) (Error|Warning): (.*)/.match(msg)
        @success = false if message[4].downcase == 'error'

        if message then
          @messages.push({:file => message[1], :line => message[2],
            :column => message[3], :type => message[4], :message => message[5]})
          4.times {stderr.gets}
        else
          @messages.push({:message => msg})
        end
      end

      @success
    end

    def compiled_without_errors?
      @success
    end

    def parse_action_script_for_params
      f = File.new @source, "r"
      f.each_line do |line|
        params = line[/\[\s*SWF\s*\(([^\)\]]*)\)\s*\]/, 1]
        if params then
          params.downcase!
          params = params.split(/\s*,\s*/)
          params.each do |param|
            param = param.split(/\s*=\s*/)
            name = param[0]
            val = param[1][/('(.*)'|"(.*)")/, 3]

            case name
              when 'width': @width = val.to_i
              when 'height': @height = val.to_i
              when 'backgroundcolor': @color = val
            end
          end
        end
      end
    end
  end
end