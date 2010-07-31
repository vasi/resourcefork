require 'iconv'

class ResourceFork
	class FileFormatError < Exception; end
	
	def seek(offset)
		@io.seek(offset) if @io.pos != offset
		@io.eof? and raise EOFError
	end
	
	def readBytes(bytes)
		data = @io.read(bytes)
		data.size == bytes or raise EOFError
		data
	end
	def readUnsigned(bytes)
		i = 0
		readBytes(bytes).each_byte { |b| i = (i << 8) + b }
		return i
	end
	def readSigned(bytes)
		bits = 8 * bytes
		i = readUnsigned(bytes)
		i > (1 << (bits - 1)) ? i - (1 << bits) : i
	end
	def readU8; readUnsigned(1); end
	def readU16; readUnsigned(2); end
	def readU32; readUnsigned(4); end
	
	def macRoman2UTF8(s); Iconv.conv('UTF8', 'MacRoman', s); end
	def readFCC; macRoman2UTF8(readBytes(4)); end
	def readPstring; macRoman2UTF8(readBytes(readU8)); end
	
	TypeEntry = Struct.new(:type, :count)
	ResourceEntry = Struct.new(:resource, :dataOffset, :nameOffset, :name)
	
	MAP_HEADER_RESERVED = 22
	REFLIST_ENTRY_RESERVED = 4
	
	def readFork
		seek 0	# fork header
		dataOffset, mapOffset = readU32, readU32
		
		seek mapOffset + MAP_HEADER_RESERVED	# map header
		attrs, typeOffset, nameOffset = readU16, readU16, readU16
		# TODO: do something with attrs
		
		typeEntries = readTypeList
		resEntries = readRefLists(typeEntries, mapOffset + nameOffset,
			dataOffset)
		readNameList(resEntries)
		readData(resEntries)
		
		# Hook 'em up
		resEntries.each do |re|
			re.resource.instance_variable_set(:@fork, self)
		end
	end
		
	def readTypeList
		entries = []
		(readU16 + 1).times do
			t, cntM1, off = readFCC, readU16, readU16
			entries << TypeEntry.new(t, cntM1 + 1)
		end
		return entries
	end
	
	def readRefLists(typeEntries, absNameOff, dataOff)
		entries = []
		typeEntries.each do |te|
			rh = @resources[te.type] = {}
			te.count.times do
				id, noff, attrs = readU16, readSigned(2), readU8
				doff = readUnsigned(3)
				readBytes(REFLIST_ENTRY_RESERVED)
				
				# TODO: attrs
				r = Resource.new(te.type, id)
				rh[id] = r
				entries << ResourceEntry.new(r, dataOff + doff,
					noff == -1 ? nil : absNameOff + noff, nil)
			end
		end
		return entries
	end
	
	def readNameList(resEntries)		
		res = resEntries.select { |re| re.nameOffset }
		res.sort_by { |re| re.nameOffset }.each do |re|
			seek re.nameOffset # should be unnecessary, no harm though
			re.resource.name = readPstring
		end
	end
	
	def readData(resEntries)
		resEntries.sort_by { |re| re.dataOffset }.each do |re|
			seek re.dataOffset
			len = readU32
			re.resource.data = readBytes(len)
		end
	end
end
