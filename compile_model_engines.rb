#!/usr/bin/env ruby
require 'json'

cars = JSON.parse(File.read("data/cars.json"));

models = {}

cars.each do |mod, car|
  model = car["model"]
  models[model] = [] unless models[model]

  engine = {
    code: car["engine_model"],
    displacement: car["displacement_cc"]
  }

  models[model] << engine unless models[model].include? engine

end


puts models.to_json