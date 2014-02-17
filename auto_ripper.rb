require 'fileutils'
require 'json'
require 'open-uri'
require 'nokogiri'
require 'logger'

module OpenCarData

  DUMP_PATH = "./cars"
  LOG_FILE = "./scraper.log"
  CACHE_PATH="./tmp/cache"
  ERROR_CACHE_PATH="./tmp/error_cache"

  class TooManyConsecutiveErrors < StandardError; end
  class EndOfRange < StandardError; end
  class RecordExists < StandardError; end
  class CacheFull < StandardError; end
  class CarNotFound < StandardError; end

  class AutoRipper
  
    RANDOM_MODE = true
    MAX_CACHE = 30098
  
    def initialize(opts={})
      @dump_path =        opts[:dump_path]        || OpenCarData::DUMP_PATH
      @cache_path =       opts[:cache_path]       || OpenCarData::CACHE_PATH
      @error_cache_path = opts[:error_cache_path] || OpenCarData::ERROR_CACHE_PATH
      @range =            opts[:range]            || 0..MAX_CACHE
      @errors = []
  
      init_cache
      init_log
      init_range
    end
    
    def init_range
      return if @range.is_a? Range or @range.nil? 
      
      s, e = *@range.gsub(/\.\./, " ").split(" ")
      s = s.to_i
      e = e.to_i
      @range = s..e
    end
    
    def init_log
      $stdout.sync = true
      @log = Logger.new($stdout)
      @log.level = Logger::DEBUG
    end
    
    def init_cache
      FileUtils.touch(@cache_path)
      FileUtils.touch(@error_cache_path)
      
      @cache = File.read(@cache_path).split("\n")
      @error_cache = File.read(@error_cache_path).split("\n")
      
      raise ArgumentError "Couldn't build cache" unless @cache.is_a? Array
      raise ArgumentError "Couldn't build error cache" unless @error_cache.is_a? Array
    end
  
    def run
      
      index = @start || 0
      last_url = "http://english.auto.vl.ru/catalog/"
  
      while true do
        index = RANDOM_MODE ? get_random_id : index+= 1
  
        begin
          raise OpenCarData::EndOfRange if !@end.nil? and index >= @end
          raise OpenCarData::TooManyConsecutiveErrors if consecutive_errors >= 3
          raise OpenCarData::RecordExists if cached?(index)
          raise OpenCarData::CacheFull if @cache.size >= MAX_CACHE
  
          duration = rand(4..10)
          @log.debug "Sleeping for #{duration} seconds"
          sleep duration # act like a human/don't hammer server
  
          @log.info "Trying to get ID #{index}"
          
          html = open( url(index),
            "User-Agent" => "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:26.0) Gecko/20100101 Firefox/26.0",
            "Referer" => last_url
          )
  
          @log.warn "HTML was nil" and next if html.nil?
          @log.info "Got HTML for ID #{index}"
  
          last_url = url(index)
  
          car = process_car(html)
          car[:auto_vl_ru_id] = index
  
          @log.info "It's a #{car[:year]} #{car[:manufacturer]} #{car[:model]} #{car[:modification]}"
          write_to_file car
          cache(index)
        rescue OpenURI::HTTPError => e
          @log.error e.message
          @errors << index
          cache index, :error
        rescue OpenCarData::CarNotFound
          @log.error "No car found with ID #{index}"
          @errors << index
          cache index, :error
        rescue OpenCarData::TooManyConsecutiveErrors
          @log.fatal "Too many consecutive errors"
          break
        rescue OpenCarData::EndOfRange
          @log.fatal "End of range met"
          break
        rescue OpenCarData::RecordExists
          @log.warn "ID #{index} is already in the cache, skipping..."
          next
        end
      end
  
    end
  
    def get_random_id
      count = 0
      while true
        count+= 1
        raise OpenCarData::CacheFull if count >= MAX_CACHE
        index = rand(@range)
        return index unless cached?(index)
      end
    end
  
    def cache(index, error=nil)
      return false if @cache.nil?
      
      if error.nil?
        @cache << index
        File.open(@cache_path, "a") {|f| f.puts index }
      else
        @error_cache << index
        File.open(@error_cache_path, "a") {|f| f.puts index }
      end
    end
  
    def cached?(index)
      @cache.include? index.to_s or
      @error_cache.include? index.to_s
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
      "http://english.auto.vl.ru/catalog/#{random_manufacturer}/#{random_model}/#{random_date}/#{count}/"
    end
  
    def random_manufacturer
      %w(nissan toyota mitsubish mazda).sample
    end
  
    def random_date
      %w(1983_1 1984_4 1996_2 1994_10 1999_10 1988_4 1991_9).sample
    end
  
    def random_model
      %w(bluebird 323 wagon safari 180 atenza 200 fairlady widetrack hilux corona corolla mr-s).sample
    end
  
    def process_car(html)
      doc = Nokogiri::HTML(html)
      validate doc
      do_process_car(doc)
    end
  
    def validate(doc)
      raise OpenCarData::CarNotFound if doc.css("h3").first.content == "Wrong params" # essentially a 404
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
      hash[:month].capitalize! unless hash[:month].nil?
  
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
end
