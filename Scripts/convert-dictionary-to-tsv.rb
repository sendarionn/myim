#!/usr/bin/env ruby
# frozen_string_literal: true

usage = "使い方: convert-dictionary-to-tsv.rb FILE..."
if ARGV.empty? || ARGV.include?("--help") || ARGV.include?("-h")
  puts usage
  exit ARGV.empty? ? 1 : 0
end

ARGV.each do |path|
  reading = nil
  lines = []

  File.foreach(path, chomp: true).with_index(1) do |raw, line_number|
    value = raw.strip
    next if value.empty?

    if raw[0]&.match?(/\s/)
      abort "#{path}:#{line_number}: 読みのない候補" unless reading
      lines << "#{reading}\t#{value}"
    elsif raw.include?("\t")
      reading = nil
      lines << raw
    else
      reading = value
    end
  end

  File.write(path, lines.join("\n") + (lines.empty? ? "" : "\n"))
end
