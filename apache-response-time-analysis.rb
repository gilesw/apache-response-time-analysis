#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'English'
require 'trollop'
require 'apache_log_regex'
require 'date'

# http://stackoverflow.com/questions/11784843/calculate-95th-percentile-in-ruby
def percentile(values, percentile)
    values_sorted = values.sort
    k = (percentile*(values_sorted.length-1)+1).floor - 1
    f = (percentile*(values_sorted.length-1)+1).modulo(1)
    return values_sorted[k] + (f * (values_sorted[k+1] - values_sorted[k]))
end

# FIXME: no shelling out
# Combine multiple files and return a single string variable
def filter_accesslog(accesslogpattern, filter)
  return `gzip -cdfq #{accesslogpattern} | grep #{filter}`
end

def test_accesslogpattern(accesslogpattern)
  `ls #{accesslogpattern} >/dev/null 2>&1`
  if $CHILD_STATUS != 0
    puts "ls #{accesslogpattern} matched nothing"
    puts "Have you enabled the wildcard option?"
    exit
  end
end

def verbose(msg)
  puts msg if $verbose
end

# http://trollop.rubyforge.org/trollop/Trollop/Parser.html
opts = Trollop::options do
  version "1.0"
  banner <<-EOS
  #{File.basename($0)}

  Description:
   Parse Apache compressed or uncompressed access logs and optionally filter on a string
   Extract %D    The time taken to serve the request, in microseconds.
   Find the 95th percentile figure from the range of all the values
   Output the value in milliseconds

  Dependencies:
   logformat with %D
   gzip

  Usage:
           #{File.basename($0)} [options]
  where [options] are:
  EOS
  opt :accesslogpath, "Path to accesslogs", :default => './access_log'
  opt :datepattern, "Pattern used in date e.g %Y-%m", :type => :string
  opt :wildcard, "Use a trailing wildcard?", :default => false
  opt :logformat, "Apache log format", :default => '%h %l %u %t \"%r\" %>s %b %D \"%{Referer}i\" \"%{User-Agent}i\"'
  opt :filter,    "Filter access logs based on a string", :default => '.'
  opt :verbose,    "Enable verbose mode", :default => false
end

if opts[:verbose]
  $verbose = true
else
  $verbose = false
end

# Build up the pattern used to match the log files
if ! opts[:datepattern].nil?
  date = Time.now.strftime(opts[:datepattern])
  accesslogpattern = "#{opts[:accesslogpath]}*#{date}"
else
  accesslogpattern = opts[:accesslogpath]
end
if opts[:wildcard]
  accesslogpattern += '*'
end

test_accesslogpattern(accesslogpattern)

accesslog_lines = filter_accesslog(accesslogpattern,opts[:filter])

# Configure the Apache access log parser with our log format
parser = ApacheLogRegex.new(opts[:logformat])

response_times = Array.new
accesslog_lines.split("\n").each do | line|
  response_times.push ( parser.parse(line)['%D'].to_f / 1000)
end


######################################
puts "Total number of response times recorded:"
puts response_times.size
puts "95th percentile of those values in milliseconds:"
puts percentile(response_times,0.95)


