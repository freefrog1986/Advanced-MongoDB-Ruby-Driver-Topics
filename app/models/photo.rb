class Photo
include ActiveModel::Model
attr_accessor :id, :location
attr_writer :contents

def self.mongo_client
	Mongoid::Clients.default
end

end