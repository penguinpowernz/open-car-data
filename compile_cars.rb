#!/usr/bin/env ruby

require 'json'

cars = {}

Dir["cars/*.json"].each do |file|
  car = JSON.parse(File.read(file))
  cars[car["slug"]] = car
end

puts cars.to_json