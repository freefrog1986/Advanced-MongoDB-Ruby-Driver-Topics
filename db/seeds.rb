# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

require 'pp'
# 1. Clear GridFS of all files.
Photo.all.each { |photo| photo.destroy }
# 2. Clear the places collection of all documents.
Place.all.each { |place| place.destroy }
# 3. Make sure the 2dsphere index has been created for the nested geometry.geolocation property within the places collection.
Place.create_indexes
# 4. Populate the places collection using the db/places.json file from the provided bootstrap files in student-start.
Place.load_all(File.open('./db/places.json'))
# 5. Populate GridFS with the images also located in the db/ folder and supplied with the bootstrap files in student-start.
Dir.glob("./db/image*.jpg") {|f| photo=Photo.new; photo.contents=File.open(f,'rb'); photo.save}
# 6. For each photo in GridFS, locate the nearest place within one (1) mile
Photo.all.each {|photo| place_id=photo.find_nearest_place_id 1*1609.34; photo.place=place_id; photo.save}
# self-test
pp Place.all.reject {|pl| pl.photos.empty?}.map {|pl| pl.formatted_address}.sort
