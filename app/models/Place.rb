class Place
include ActiveModel::Model


def self.mongo_client
	Mongoid::Clients.default
end

def self.collection
	self.mongo_client['places']
end

def self.load_all(f)
	file=File.read(f)
    hash=JSON.parse(file)
    place=collection.insert_many(hash)
end

end