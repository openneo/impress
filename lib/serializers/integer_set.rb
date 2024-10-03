module Serializers
	module IntegerSet
		def self.dump(array)
			array.sort.join(",")
		end

		def self.load(string)
			(string || "").split(",").map(&:to_i)
		end
	end
end