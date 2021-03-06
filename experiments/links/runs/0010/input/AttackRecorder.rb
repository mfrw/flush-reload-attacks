#!/usr/bin/env ruby

$LOAD_PATH << File.dirname( __FILE__ )

require 'optparse'
require '../../flush-reload/myversion/RubyInterface.rb'

$options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"

  $options[:links] = nil
  opts.on( '-l', '--links-path PATH', 'Path to the links web browser.' ) do |path|
    $options[:links] = path
  end

  $options[:outputdir] = nil
  opts.on( '-d', '--output-dir DIR', 'Output directory.' ) do |dir|
    $options[:outputdir] = dir
  end

  $options[:probefile] = nil
  opts.on( '-p', '--probe-file FILE', 'Probe configuration file.' ) do |path|
    $options[:probefile] = path
  end
end

def exit_with_message(optparse, msg)
  STDERR.puts "[!] #{msg}"
  STDERR.puts optparse
  exit(false)
end

begin
  optparse.parse!
rescue OptionParser::InvalidOption
  exit_with_message(optparse, "Invalid option.")
rescue OptionParser::MissingArgument
  exit_with_message(optparse, "Missing argument.")
end

if $options[:outputdir].nil?
  exit_with_message(optparse, "Missing --output-dir")
end
if Dir.exist?($options[:outputdir])
  exit_with_message(optparse, "Output directory already exists.")
end

if $options[:links].nil?
  exit_with_message(optparse, "Missing --links-path (path to links binary)")
end

if $options[:probefile].nil?
  exit_with_message(optparse, "Missing --probe-file (path to probe config)")
end

Dir.mkdir($options[:outputdir])

begin
  spy = Spy.new($options[:links])
  spy.loadProbes($options[:probefile])
  spy.start
  trap("SIGINT") do 
    spy.stop
    exit
  end
  spy.each_burst do |burst|
    # Ignore blips
    if burst.length > 5
      # Collapse
      burst.gsub!("\n", "")
      burst.gsub!("|", "")
      burst.gsub!(/D+/, "D")
      burst.gsub!(/R+/, "R")
      burst.gsub!(/H+/, "H")
      # Commenting this out -- it wasn't there in my orgiginal tests
      # FIXME put this and the other code in the same place
      #burst.gsub!(/S+/, "S")

      save_path = File.join( $options[:outputdir], Time.now.to_i.to_s )
      File.open( save_path, "w" ) do |f|
        f.write(burst)
      end
    end
  end
rescue MonotonicityError
  puts "[!!] Monotonicity Error! Re-starting."
  retry
end
