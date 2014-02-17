#!/usr/bin/env ruby

require 'json'
require 'open-uri'
require 'nokogiri'
require 'logger'

require './auto_ripper'

class String

  def parameterize!
    downcase!
    gsub!(/\W/, "_")
    gsub!(/_+/, "_")
    gsub!(/^_/, "")
    gsub!(/_$/, "")
    self
  end

  def normalize!
    gsub!(/ +/, " ")
    strip!
    self
  end

end

OpenCarData::AutoRipper.new(range: ARGV[0]).run
