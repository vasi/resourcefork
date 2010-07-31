require 'resourcefork/read'

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
		@io = io
		@resources = {} # indexed by type, then id
		readFork
		
		# TODO: write; write on close?
	end
	
	def types; @resources.keys.sort; end
	def resources(type)
		rs = @resources[type] or return nil
		rs.values.sort_by { |r| r.id }
	end
	def resource(type, id)
		rs = @resources[type] or return nil
		rs[id]
	end
end

if __FILE__ == $0
	rf = ResourceFork.new(open(ARGV.shift))
	rf.types.each do |t|
		rf.resources(t).each do |r|
			puts "%4s  %5d  %s" % [t, r.id, r.name ? r.name : '']
		end
	end
end
