#!/usr/bin/env ruby

require 'json'

cars = JSON.parse(File.read("data/cars.json")).map { |key, car| car }
code_cars = {}

cars.each do |car|
  code = car["engine_model"]
  code_cars[code] = [] unless code_cars[code]
  code_cars[code] << car
end

engines = {}

code_cars.each do |code, cars|
  
  engine = {
    manufacturer:      cars.map {|c| c["manufacturer"]               }.uniq,
    produced:          cars.map {|c| c["year"]                       }.uniq.sort,
    power:             cars.map {|c| c["max_power_net_kw_ps_rpm"]    }.uniq.sort.reverse,
    displacement:      cars.first["displacement_cc"],
    torque:            cars.map {|c| c["max_torque_net_n_m_kg_m_rpm"]}.uniq.sort.reverse,
    type:              cars.map {|c| c["engine_type"]                }.uniq,
    fuel:              cars.map {|c| c["fuel_type"]                  }.uniq,
    turbo:             cars.map {|c| c["turbocharger"]               }.uniq,
    compression_ratio: cars.map {|c| c["compression_ratio"]          }.uniq.sort,
    bore_mm:           cars.map {|c| c["bore_mm"]                    }.uniq.sort,
    stroke_mm:         cars.map {|c| c["stroke_mm"]                  }.uniq.sort,
    cars:              cars.map {|c| c["slug"]                       }.uniq
  }

  engine.each do |key, array|
    next unless array.is_a? Array
    engine[key] = array.reject { |e| e == " " or e == "" }
  end

  engines[code] = engine
end

puts ARGV[0] == "-p" ? JSON.pretty_generate(engines) : engines.to_json