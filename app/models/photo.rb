class Photo
include ActiveModel::Model
attr_accessor :id, :location
attr_writer :contents

def self.mongo_client
	Mongoid::Clients.default
end

def initialize(params=nil)
    @id = params[:_id].to_s if !params.nil? && !params[:_id].nil?
    @location = Point.new(params[:metadata][:location]) if !params.nil? && !params[:metadata].nil?
end

def persisted?
	!@id.nil?
end

# :contents is used to store the image 
# f = File.open(’./db/image1.jpg’,’rb’)
# photo.contents = f

# to save instance you have to store the pic in database using GridFS, 
# so you have to store @id and @location, while @content is the image itself
# but how to get the gps info of the image? use EXIFR gem
# Mongo::Grid::File.new() have two arguments, first one is the image(@contents.read),
# the second one is description which store all the attributes.

def save
	# check whether the instance is already persisted
    if !persisted?
      # use the exifr gem to extract geolocation information from the jpeg image
      gps = EXIFR::JPEG.new(@contents).gps
      # Both EXIFR and GridFS will be reading the same file, 
      # You must call rewind() on the file in between calls for the proper number 
      # of bytes to be stored in GridFS.
      @contents.rewind
      # create a description array to store file property hashs
      description={}
      # store the content type of image/jpeg in the GridFS contentType file property
      description[:content_type] = "image/jpeg"
      # store the GeoJSON Point format of the image location
      location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)
      description[:metadata] = {
        :location => location.to_hash
      }
      # store the data contents in GridFS
      grid_file = Mongo::Grid::File.new(@contents.read, description)
      # store the generated _id for the file in the :id property of the Photo model instance.
      @id = self.class.mongo_client.database.fs.insert_one(grid_file).to_s
      # sotre the location of Point class in the @location attribute
      @location = Point.new(location.to_hash)
    else
    end
end

def self.all(offset = 0, limit = nil)
	if !limit.nil?
	docs = mongo_client.database.fs.find.skip(offset).limit(limit)
	else
	docs = mongo_client.database.fs.find.skip(offset)
	end
	docs.map{|doc| Photo.new(doc)}
end

def self.find(params)
	id = BSON::ObjectId.from_string(params)
	p = mongo_client.database.fs.find(:_id => id).first
	p.nil? ? nil : photo = Photo.new(p)
end



end