class Place
include ActiveModel::Model
attr_accessor :id, :formatted_address, :location, :address_components 

def initialize(params)
	@id = params[:_id].to_s
	@formatted_address = params[:formatted_address]
	@address_components = []
    if !params[:address_components].nil?
      address_components = params[:address_components]
      address_components.each { |a| @address_components << AddressComponent.new(a) }
    end
	@location = Point.new(params[:geometry][:geolocation])
end

def self.mongo_client
	Mongoid::Clients.default
end

def persisted? 
	!@id.nil?
end

def self.collection
	self.mongo_client['places']
end

def self.load_all(f)
	file=File.read(f)
    hash=JSON.parse(file)
    place=collection.insert_many(hash)
end

def self.find_by_short_name(s)
	collection.find({"address_components.short_name":s})
end

def self.to_places(ms)
	p = []
    ms.each { |m| 
      p << Place.new(m) 
    }
    return p
end

def self.find(id)
	_id = BSON::ObjectId.from_string(id)
	p = collection.find(:_id => _id).first
	if !p.nil?
		Place.new(p)
	else
		nil
	end
end

# limit equal to 0 means nolimit
# if this a instance method to call a class method, use self.class. as the head of calling
# find photo in mongo_client.database.fs while find other data in collection.
def photos(offset=0, limit= 0)
  self.class.mongo_client.database.fs.find(
      "metadata.place": BSON::ObjectId.from_string(@id)
    ).map { |photo|
      Photo.new(photo)
    }
end

def self.all(offset = 0, limit = nil)
    if !limit.nil?
      docs = collection.find.skip(offset).limit(limit)
    else
      docs = collection.find.skip(offset)
    end

    docs.map { |doc|
      Place.new(doc)
    }
end

def destroy
	_id = BSON::ObjectId.from_string(@id)
	self.class.collection.find(:_id => _id).delete_one
end

def self.get_address_components(sort = nil, offset = 0, limit = nil)
	arr = []
	arr << {:$unwind=>"$address_components"}
	arr << {:$project=>{:_id=>1, :address_components=>1, :formatted_address=>1, :geometry=>{:geolocation=>1}}}
	if !sort.nil?
		arr << {:$sort => sort}
	end
	if offset!=0
		arr << {:$skip => offset}
	end
	if !limit.nil?
		arr << {:$limit => limit}
	end
	collection.aggregate(arr)
end

def self.get_country_names
	arr=[]
	arr << {:$unwind => '$address_components'}
	arr << {:$project => {:_id=>0, :address_components=>{:long_name=>1,:types=>1}}}
	arr << {:$match => {'address_components.types':"country"}}
	arr << {:$group=>{ :_id=>'$address_components.long_name', :count=>{:$sum=>1}}}

	collection.aggregate(arr).to_a.map {|h| h[:_id]}
end

def self.find_ids_by_country_code(cc)
	arr =[]
	arr << {:$match => {'address_components.types': "country"}}
	arr << {:$match => {'address_components.short_name': cc}}
	arr << {:$project => {:_id=>1}}
	collection.aggregate(arr).map {|doc| doc[:_id].to_s}
end

def self.create_indexes
	collection.indexes.create_one({'geometry.geolocation': Mongo::Index::GEO2DSPHERE})
end

def self.remove_indexes
	collection.indexes.drop_one('geometry.geolocation_2dsphere')
end

def self.near(point, max_meters = nil)
	near_hash ={}
	near_hash['$near'] = point.to_hash
	if !max_meters.nil?
		near_hash[:$maxDistance] = max_meters.to_i
	end
	collection.find({:'geometry.geolocation'=> near_hash})
end

def near(max_meters = nil)
	near_points = []
	pa_near=self.class.near(@location,max_meters)
	pa_near.each { |p| 
        near_points << Place.new(p)
      }
     return near_points
end


end