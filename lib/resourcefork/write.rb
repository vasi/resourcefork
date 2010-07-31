require 'iconv'

class ResourceFork
	def writeInt(io, bytes, i)
		i += (1 << 32) if i < 0
		s = [i].pack('N')
		io.write(s[4 - bytes, 4])
	end
	def write8(io, i); writeInt(io, 1, i); end
	def write16(io, i); writeInt(io, 2, i); end
	def write32(io, i); writeInt(io, 4, i); end
	def writePad(io, bytes); io.write("\0" * bytes); end
	
	def macRoman(s); Iconv.conv('MacRoman', 'UTF8', s); end
	def writeFCC(io, fcc); io.write(macRoman(fcc)); end
	
	HEADER_SIZE = 64
	HEADER_PAD = HEADER_SIZE - 4 * 4
	
	MAP_HEADER_SIZE = MAP_HEADER_RESERVED + 6
	TYPELIST_HEADER_SIZE = 2
	TYPELIST_ENTRY_SIZE = 8
	REFLIST_ENTRY_SIZE = REFLIST_ENTRY_RESERVED + 8
		
	def write(io)
		# Figure out some sizes and offsets
		typeEntries = types.map { |t| TypeEntry.new(t, @resources[t].size) }		
		dataSize = nameSize = 0
		resEntries = resources.map do |r|
			n = r.name && macRoman(r.name)
			re = ResourceEntry.new(r, dataSize, n ? nameSize : -1, n)
			dataSize += r.data.size + 4
			nameSize += n.size + 1 if n
			re
		end
		
		typeCount = @resources.size
		typeListSize = TYPELIST_HEADER_SIZE + typeCount * TYPELIST_ENTRY_SIZE
		mapSize = MAP_HEADER_SIZE + typeListSize + 
			resEntries.size * REFLIST_ENTRY_SIZE + nameSize
		
		# File header
		write32(io, HEADER_SIZE)
		write32(io, HEADER_SIZE + dataSize)
		write32(io, dataSize)
		write32(io, mapSize)
		writePad(io, HEADER_PAD)
		
		# Data
		resEntries.each do |re|
			d = re.resource.data
			write32(io, d.size)
			io.write(d)
		end
		
		# Map header
		writePad(io, MAP_HEADER_RESERVED)
		write16(io, 0)	# TODO: attrs
		write16(io, MAP_HEADER_SIZE)
		write16(io, mapSize - nameSize)
		
		# Type list
		refListOffset = typeListSize
		write16(io, typeEntries.size - 1)
		typeEntries.each do |te|
			writeFCC(io, te.type)
			write16(io, te.count - 1)
			write16(io, refListOffset)
			refListOffset += te.count * REFLIST_ENTRY_SIZE
		end
		
		# Ref list
		resEntries.each do |re|
			write16(io, re.resource.id)
			write16(io, re.nameOffset)
			write8(io, 0)	# TODO: attrs
			writeInt(io, 3, re.dataOffset)
			writePad(io, REFLIST_ENTRY_RESERVED)
		end
		
		# Name list
		resEntries.each do |re|
			next unless re.name
			write8(io, re.name.size)
			io.write(re.name)
		end
	end
end
