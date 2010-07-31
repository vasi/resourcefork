require 'resourcefork/read'
require 'resourcefork/write'

class ResourceFork
	class Resource
		attr_accessor :name, :data
		attr_reader :type, :id
				
		def initialize(type, id, name = nil, data = nil, *attrs)
			@type, @id, @name, @data = type, id, name, data
			@fork = nil

			# TODO: attrs?
		end
	end
	
	def initialize(io)
		@resources = {} # indexed by type, then id
		Reader.new(self, io, @resources)
		
		# TODO: write; write on close?
	end
	
	# TODO: Cache sort?
	def types; @resources.keys.sort; end
	def type(type)
		rs = @resources[type] or return nil
		rs.values.sort_by { |r| r.id }
	end
	def resource(type, id)
		rs = @resources[type] or return nil
		rs[id]
	end
	def resources
		types.inject([]) { |a,t| a.concat(type(t)) }
	end
end

if __FILE__ == $0
	f1, f2 = *ARGV
	rf = ResourceFork.new(open(f1))
	if f2
		rf.write(open(f2, 'w'))
	else
		rf.resources.each do |r|
			puts "%4s  %5d  %s" % [r.type, r.id, r.name ? r.name : '']
		end
	end
end
