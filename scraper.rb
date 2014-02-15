#!/usr/bin/env ruby

require 'json'
require 'open-uri'
require 'nokogiri'
require 'logger'

DUMP_PATH = "./cars"
LOG_FILE = "./scraper.log"

class TooManyConsecutiveErrors < StandardError; end
class EndOfRange < StandardError; end

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

class AutoRipper

  def initialize(dump_path, log_file, range=nil)
    @dump_path = dump_path
    @errors = []
    @log = Logger.new(log_file)
    
    unless range.nil?
      @start, @end = *range.gsub(/\.\./, " ").split(" ")
      @start = @start.to_i
      @end = @end.to_i
    end
  end

  def run
    
    count = @start || 0

    while true do
      count+= 1

      begin
        raise EndOfRange if !@end.nil? and count >= @end
        raise TooManyConsecutiveErrors if consecutive_errors >= 3
        duration = rand(4..10)
        @log.debug "Sleeping for #{duration} seconds"
        sleep duration # act like a human

        @log.info "Trying to get ID #{count}"
        
        html = open( url(count),
          "User-Agent" => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:26.0) Gecko/20100101 Firefox/26.0"
        )

        @log.warn "HTML was nil" and next if html.nil?
        @log.info "Got HTML for ID #{count}"

        car = process_car(html)
        @log.info "It's a #{car[:year]} #{car[:manufacturer]} #{car[:model]} #{car[:modification]}"
        write_to_file car
      rescue OpenURI::HTTPError => e
        @log.error e.message
        @errors << count
      rescue TooManyConsecutiveErrors
        @log.fatal "Too many consecutive errors"
        break
      rescue EndOfRange
        @log.fatal "End of range met"
        break
      end
    end

  end

  def consecutive_errors
    last_index = @errors.last
    consecutive_error_count = 0

    @errors.reverse[0..2].each do |i|
      next unless last_index = (i - 1)
      last_index = i
      consecutive_error_count+= 1
    end

    consecutive_error_count
  end

  def url(count)
    "http://english.auto.vl.ru/catalog/nissan/180sx/1989_3/#{count}/"
  end

  def process_car(html)
    doc = Nokogiri::HTML(html)
    do_process_car(doc)
  end

  def write_to_file(hash)
    json = hash.to_json
    @log.info "Dumping json to #{@dump_path}/#{hash[:slug]}.json"
    File.open("#{@dump_path}/#{hash[:slug]}.json", "w") do |f|
      f.write json
    end
  end

  def do_process_car(doc)
    hash = {}

    hash[:name] = doc.css("h1").first.content.force_encoding("UTF-8")

    parts = hash[:name].split(" ")
    hash[:manufacturer] = parts.first
    hash[:model] = parts[1..parts.size-2].join(" ")


    hash[:modification], hash[:produced_from] = *doc.css("h3").first.content.force_encoding("UTF-8").split(",")
    hash[:modification].gsub! /Modification/, ""
    hash[:modification].normalize!

    hash[:produced_from].gsub!(/produced from/, "")
    hash[:produced_from].normalize!
    hash[:produced_from].gsub!(/\(|\)/, "")

    hash[:year], hash[:month] = *hash[:produced_from].split(" ")
    hash[:month].capitalize!

    doc.css("table.text:nth-child(2) tr").each do |tr|
      next if tr.children.size != 2
      key = tr.children[0].content.force_encoding("UTF-8")
      key.parameterize!
      value = tr.children[1]

      if value.css("img").size > 0
        value = case value.children[0].attributes["alt"].value
        when "o"
          "optional"
        when "y"
          "yes"
        when "n"
          "no"
        end
      else
        value = value.content.force_encoding("UTF-8")
      end

      hash[key.to_sym] = value
    end

    hash[:slug] = hash[:name].clone
    hash[:slug] = [
      hash[:slug],
      hash[:month],
      hash[:modification],
      hash[:frame]
    ].join(" ")
    hash[:slug].parameterize!

    hash
  end
end

AutoRipper.new(DUMP_PATH, LOG_FILE, ARGV[0]).run