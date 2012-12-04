#!/usr/local/bin/ruby

#
# main.rb - Main executable for running experiments.
#

require 'optparse'
require 'ostruct'

require_relative 'cfg.rb'
require_relative 'list.rb'
require_relative 'lossify.rb'
require_relative 'reduce.rb'
require_relative 'sequitur.rb'
require_relative 'graphplot.rb'

USAGE = "Usage: ./main.rb [options] input-file"
ALGORITHMS = {
  'similarity' => Lossifier::Similarity,
  'cluster' => Lossifier::Cluster,
}

# Default option values.
options = OpenStruct.new
options.algorithms = ALGORITHMS.values
options.expand = true
options.print = false
options.plot = false
options.reduce = false
options.verbose = false

OptionParser.new do |opts|
  opts.banner = USAGE

  opts.on("-e", "--[no-]expand", "Print expansion") do |e|
    options.expand = e
  end

  opts.on("-g", "--[no-]print-grammar", "Print grammar") do |g|
    options.print = g
  end

  opts.on("-p", "--[no-]plot-grammar", "Plot grammar") do |p|
    options.plot = p
  end

  opts.on("-l", "--lossifiers [ALGO1, ALGO2, ...]", Array,
          "The lossifier algorithms to use") do |algos|
    if algos = [ 'none' ]
      options.algorithms = []
      next
    end

    raise OptionParser::InvalidArgument unless (algos - ALGORITHMS.keys).empty?
    options.algorithms = algos.uniq.map { |algo| ALGORITHMS[algo] }
  end

  opts.on("-r", "--[no-]reduce", "Apply grammar reductions") do |r|
    options.reduce = r
  end

  opts.on("-v", "--verbose", "Run verbosely") do |v|
    options.verbose = v
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

if ARGV[0].nil?
  puts USAGE
  exit
end

def output_cfg(cfg, options, plotname)
  puts cfg if options.print
  puts cfg.expand if options.expand
  plot_cfg cfg, plotname if options.plot
  puts "\n"
end

def reduce_cfg(cfg, options, plotname)
  cfg = Reducer.new(cfg, options.verbose).run
  output_cfg cfg, options, plotname + '-red'
  cfg
end

def process_cfg(title, options, fprefix)
  puts title + '-' * (79 - title.size) + "\n\n"

  cfg = yield
  output_cfg cfg, options, fprefix + '-' + title

  if options.reduce
    puts '-' * 70 + "(Reduced)\n\n"
    reduce_cfg cfg, options, fprefix + '-' + title
  else
    cfg
  end
end

str = File.read(ARGV[0])
fprefix = ARGV[0].rpartition('.').first

cfg = process_cfg('Sequitur', options, fprefix) do
  Sequitur.new(str).run
end

options.algorithms.each do |algo|
  process_cfg(algo.name, options, fprefix) do
    algo.new(cfg, options.verbose).run
  end
end
