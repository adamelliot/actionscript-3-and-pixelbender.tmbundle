#!/usr/bin/env ruby
#
# flash_debugger.rb
#

require 'open3'

module FlashMate

  FDB = 'fdb'

  # TODO: Cleanup how we pull stuff off the command line and get data from fdb

  class FlashDebugger
    attr_reader :debugging

    def initialize(basedir, sdk)
      @basedir = basedir
      @sdk = sdk
      @messages = []
      @debugging = true
    end

    # Puts a message,but cleans it up so it will display properly
    def print(msg)
      @last_message = msg.chomp
      @messages.push @last_message
    end

    # Reads in a line and removes the debugger "(fdb) "
    def readline
      @stdout.gets.gsub(/^\(fdb\) /, '').chomp
    end

    def extract_backtrace
      readline unless readline['Execution halted in']

      @stdin.puts 'cf' # includes line / col info
      file = readline

      @stdin.puts 'bt' # Get a back trace
      first_line = readline

      begin
        tmp = file.split('.')
        file = tmp[0]
        tmp = tmp[1].split('#')
        ext = tmp[0]
        tmp = tmp[1].split(':')
        line, col = tmp[1], tmp[0]

        path = first_line[/.*class='([a-zA-Z\._0-9]*)::#{file}'.*/, 1]
        path = File.join(path.split('.'), file) + ".#{ext}"

        link = "txmt://open?url=file://#{File.join @basedir, path}&line=#{line.to_i}&column=#{col.to_i + 1}"
        link = "<a href=\"#{link}\">#{file}</a>"

      # The backtrack doesn't always reveal what we want
      rescue
        link = "no source path"
      ensure
        print "<em>Backtrace (#{link}):</em> "
        # The rest will be extracted via standard read loop (def run)
        print first_line

        @stdin.puts 'c' # Continue debugging.
      end
    end

    def run
      @debugger = Thread.new do
        command = File.join @sdk, 'bin', FDB
        @stdin, @stdout, @stderr = Open3.popen3(command)
        # Put the debugger in a mode ready to recieve a SWF
        @stdin.puts 'r'

        while (msg = readline) && @debugging do
          print msg

          @debugging = false if msg['Another Flash debugger is probably running']

          type = msg[/\[([^\]]*)\]/, 1]
          case type
            when "SWF": @stdin.puts 'c'
            when "Fault": extract_backtrace
            when "UnloadSWF"
              @stdin.puts 'q'
              @debugging = false
          end
        end
      end
    end

    def stop
      @debugger.stop if @debugger
    end

    def each_message
      yield @messages.shift while @messages.length > 0
    end
  end
end

#fdb = FlashMate::FlashDebugger.new('~/bin/flex')
#fdb.run
#
#puts "Starting..."
#
#while fdb.debugging do
#  sleep 0.1
#  fdb.each_message do |message|
#    puts message
#  end
#end