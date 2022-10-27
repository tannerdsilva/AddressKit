//DEFINITIONS OF RESERVED IPV4 ADDRESSES
//RANGES REFERENCED FROM https://en.wikipedia.org/wiki/Reserved_IP_addresses AS OF OCTOBER 3, 2021

//VALID_RANGE does not need to be defined here since AddressV4 is based on UInt32 which perfectly encompasses the 32 bit address space of IPv4
fileprivate let PRIVATE_RANGES = [
	NetworkV4(cidr:"10.0.0.0/8")!,
	NetworkV4(cidr:"192.168.0.0/16")!,
	NetworkV4(cidr:"172.16.0.0/12")!
]

fileprivate let RESERVED_RANGES = PRIVATE_RANGES + [
	NetworkV4(cidr:"192.0.2.0/24")!,
	NetworkV4(cidr:"198.51.100.0/24")!,
	NetworkV4(cidr:"203.0.113.0/24")!,
	NetworkV4(cidr:"233.252.0.0/24")!,
	NetworkV4(cidr:"127.0.0.0/8")!,
	NetworkV4(cidr:"192.88.99.0/24")!,
	NetworkV4(cidr:"224.0.0.0/4")!,
	NetworkV4(cidr:"240.0.0.0/4")!,
	NetworkV4(cidr:"100.64.0.0/10")!,
	NetworkV4(cidr:"192.0.0.0/24")!,
	NetworkV4(cidr:"198.18.0.0/15")!,
	NetworkV4(cidr:"0.0.0.0/8")!,
	NetworkV4(cidr:"169.254.0.0/16")!,
	NetworkV4(cidr:"255.255.255.255/32")!
]

public struct AddressV4:Address, LosslessStringConvertible {
	public let integer:UInt32
	
	public var string:String {
		get {
			return String((self.integer >> 24) & 0xFF) + "." + String((self.integer >> 16) & 0xFF) + "." + String((self.integer >> 8) & 0xFF) + "." + String(self.integer & 0xFF)
		}
	}
	
	public var description:String {
		get {
			return self.string
		}
	}
	
	public var isPrivate:Bool {
		get {
			for range in PRIVATE_RANGES {
				if range.contains(self) {
					return true
				}
			}
			return false
		}
	}
	
	public var isReserved:Bool {
		get {
			for range in RESERVED_RANGES {
				if range.contains(self) {
					return true
				}
			}
			return false
		}
	}
	
	public init(_ addressInteger:UInt32) {
		self.integer = addressInteger
	}
	
	public init?(_ stringRep:String) {
		var octets = [UInt32]()
		for octet in stringRep.split(separator:".") {
			guard let asInt = UInt8(octet) else {
				return nil
			}
			octets.append(UInt32(asInt))
		}
		guard octets.count == 4 else {
			return nil
		}
		var total:UInt32 = 0
		for i in stride(from:3, through:0, by:-1) {
			total += octets[3-i] << (i * 8)
		}
		self.integer = total
	}
	
	
	//comparible
	public static func < (lhs:AddressV4, rhs:AddressV4) -> Bool {
		return lhs.integer < rhs.integer
	}
	
	public static func <= (lhs:AddressV4, rhs:AddressV4) -> Bool {
		return lhs.integer <= rhs.integer
	}
	
	public static func > (lhs:AddressV4, rhs:AddressV4) -> Bool {
		return lhs.integer > rhs.integer
	}
	
	public static func >= (lhs:AddressV4, rhs:AddressV4) -> Bool {
		return lhs.integer >= rhs.integer
	}
		
	public static func + (left:AddressV4, adjustment:Int64) -> AddressV4 {
		let newValue = Int64(left.integer) + adjustment
		return AddressV4(UInt32(newValue))
	}
	
	public static func - (left:AddressV4, adjustment:Int64) -> AddressV4 {
		let newValue = Int64(left.integer) - adjustment
		return AddressV4(UInt32(newValue))
	}
}

public struct RangeV4:Range, LosslessStringConvertible {
	public var string:String {
		get {
			return self.lower.string + "-" + self.upper.string
		}
	}
	
	public var description:String {
		get {
			return self.string
		}
	}
	
	public let lower:AddressV4
	public let upper:AddressV4
	public let count:UInt32
	
	public init?(_ rangeString:String) {
		let splitData = rangeString.split(separator:"-", omittingEmptySubsequences:true)
		guard splitData.count == 2, splitData[0].count > 0, splitData[1].count > 0 else {
			return nil
		}
		guard let lower = AddressV4(String(splitData[0])), let upper = AddressV4(String(splitData[1])) else {
			return nil
		}
		self = RangeV4(lower:lower, upper:upper)
	}
	
	public init(lower:AddressV4, upper:AddressV4) {
		guard lower <= upper else {
			fatalError("lower is greater than upper")
		}
		self.upper = upper
		self.lower = lower
		self.count = upper.integer - lower.integer + 1
	}
	
	public func contains(_ addressV4:AddressV4) -> Bool {
		if lower <= addressV4 && upper >= addressV4 {
			return true
		}
		return false
	}
	
	public func randomAddress() -> AddressV4 {
		let randomIncrementFromBase = UInt32.random(in:0..<count)
		return AddressV4(lower.integer + randomIncrementFromBase)
	}
	
	public func overlapsWith(_ range:RangeV4) -> Bool {
		if (range.lower < self.lower && range.upper < self.lower) || (range.upper > self.upper && range.lower > self.upper) {
			return false
		} else {
			return true
		}
	}
}

public struct NetworkV4:Network, LosslessStringConvertible {
	public var cidrString:String {
		get {
			return self.address.string + "/" + String(prefix)
		}
	}
	
	public var description:String {
		get {
			return self.cidrString
		}
	}
	
	public let address:AddressV4
	public let netmask:AddressV4
	public let prefix:UInt8
	public let range:RangeV4
	
	//ipv4 specifics
	public let usableRange:RangeV4
	public let broadcast:AddressV4?
	
	public init?(_ description:String) {
		self.init(cidr:description)
	}
	
	public init?(cidr cidrV4:String) {
		let cidrSplit = cidrV4.split(separator:"/").compactMap { String($0) }
		guard cidrSplit.count == 2 else {
			return nil
		}
		guard let parseAddress = AddressV4(cidrSplit[0]), let parsePrefix = UInt8(cidrSplit[1]) else {
			return nil
		}
		self.address = parseAddress
		self.prefix = parsePrefix
		
		var buildNetmask:UInt32 = 0
		switch parsePrefix {
			case 0:
				buildNetmask = 0
			case 1:
				buildNetmask = 0b10000000000000000000000000000000
			case 2:
				buildNetmask = 0b11000000000000000000000000000000
			case 3:
				buildNetmask = 0b11100000000000000000000000000000
			case 4:
				buildNetmask = 0b11110000000000000000000000000000
			case 5:
				buildNetmask = 0b11111000000000000000000000000000
			case 6:
				buildNetmask = 0b11111100000000000000000000000000
			case 7:
				buildNetmask = 0b11111110000000000000000000000000
			case 8:
				buildNetmask = 0b11111111000000000000000000000000
			case 9:
				buildNetmask = 0b11111111100000000000000000000000
			case 10:
				buildNetmask = 0b11111111110000000000000000000000
			case 11:
				buildNetmask = 0b11111111111000000000000000000000
			case 12:
				buildNetmask = 0b11111111111100000000000000000000
			case 13:
				buildNetmask = 0b11111111111110000000000000000000
			case 14:
				buildNetmask = 0b11111111111111000000000000000000
			case 15:
				buildNetmask = 0b11111111111111100000000000000000
			case 16:
				buildNetmask = 0b11111111111111110000000000000000
			case 17:
				buildNetmask = 0b11111111111111111000000000000000
			case 18:
				buildNetmask = 0b11111111111111111100000000000000
			case 19:
				buildNetmask = 0b11111111111111111110000000000000
			case 20:
				buildNetmask = 0b11111111111111111111000000000000
			case 21:
				buildNetmask = 0b11111111111111111111100000000000
			case 22:
				buildNetmask = 0b11111111111111111111110000000000
			case 23:
				buildNetmask = 0b11111111111111111111111000000000
			case 24:
				buildNetmask = 0b11111111111111111111111100000000
			case 25:
				buildNetmask = 0b11111111111111111111111110000000
			case 26:
				buildNetmask = 0b11111111111111111111111111000000
			case 27:
				buildNetmask = 0b11111111111111111111111111100000
			case 28:
				buildNetmask = 0b11111111111111111111111111110000
			case 29:
				buildNetmask = 0b11111111111111111111111111111000
			case 30:
				buildNetmask = 0b11111111111111111111111111111100
			case 31:
				buildNetmask = 0b11111111111111111111111111111110
			case 32:
				buildNetmask = 0b11111111111111111111111111111111
			default:
				return nil
		}
		self.netmask = AddressV4(buildNetmask)
		
		let startAddress = parseAddress.integer & buildNetmask
		let range = buildNetmask ^ 0xFFFFFFFF
		let endAddress = startAddress + range
		
		let makeRange = RangeV4(lower:AddressV4(startAddress), upper:AddressV4(endAddress))
		self.range = makeRange
		switch makeRange.count {
			case 1, 2:
				self.usableRange = makeRange
				self.broadcast = nil
			default:
				self.usableRange = RangeV4(lower:makeRange.lower + 1, upper:makeRange.upper - 1)
				self.broadcast = makeRange.upper
		}
	}
	
	public init?(address:AddressV4, netmask:AddressV4) {
		self.address = address
		self.netmask = netmask
		
		let getPrefix:UInt8
		switch netmask.integer {
			case 0:
				getPrefix = 0
			case 2147483648:
				getPrefix = 1
			case 3221225472:
				getPrefix = 2
			case 3758096384:
				getPrefix = 3
			case 4026531840:
				getPrefix = 4
			case 4160749568:
				getPrefix = 5
			case 4227858432:
				getPrefix = 6
			case 4261412864:
				getPrefix = 7
			case 4278190080:
				getPrefix = 8
			case 4286578688:
				getPrefix = 9
			case 4290772992:
				getPrefix = 10
			case 4292870144:
				getPrefix = 11
			case 4293918720:
				getPrefix = 12
			case 4294443008:
				getPrefix = 13
			case 4294705152:
				getPrefix = 14
			case 4294836224:
				getPrefix = 15
			case 4294901760:
				getPrefix = 16
			case 4294934528:
				getPrefix = 17
			case 4294950912:
				getPrefix = 18
			case 4294959104:
				getPrefix = 19
			case 4294963200:
				getPrefix = 20
			case 4294965248:
				getPrefix = 21
			case 4294966272:
				getPrefix = 22
			case 4294966784:
				getPrefix = 23
			case 4294967040:
				getPrefix = 24
			case 4294967168:
				getPrefix = 25
			case 4294967232:
				getPrefix = 26
			case 4294967264:
				getPrefix = 27
			case 4294967280:
				getPrefix = 28
			case 4294967288:
				getPrefix = 29
			case 4294967292:
				getPrefix = 30
			case 4294967294:
				getPrefix = 31
			case 4294967295:
				getPrefix = 32
			default:
				return nil
		}
		self.prefix = getPrefix
		
		let startAddress = address.integer & netmask.integer
		let range = netmask.integer ^ 0xFFFFFFFF
		let endAddress = startAddress + range
		
		let makeRange = RangeV4(lower:AddressV4(startAddress), upper:AddressV4(endAddress))
		self.range = makeRange
		switch makeRange.count {
			case 1, 2:
				self.usableRange = makeRange
				self.broadcast = nil
			default:
				self.usableRange = RangeV4(lower:makeRange.lower + 1, upper:makeRange.upper - 1)
				self.broadcast = makeRange.upper
		}
	}
	
	public func contains(_ addressV4:AddressV4) -> Bool {
		if (range.lower <= addressV4 && range.upper >= addressV4) {
			return true
		} else {
			return false
		}
	}

	public func overlapsWith(_ network:NetworkV4) -> Bool {
		if (network.range.lower < self.range.lower && network.range.upper < self.range.lower) || (network.range.upper > self.range.upper && network.range.lower > self.range.upper) {
			return false
		} else {
			return true
		}
	}
}

extension AddressV4:Codable {
	public init(from decoder:Decoder) throws {
		let singleValThing = try decoder.singleValueContainer()
		guard let asSelf = Self.init(try singleValThing.decode(String.self)) else {
			throw DecodingError.typeMismatch(AddressV4.self, DecodingError.Context(codingPath:decoder.codingPath, debugDescription: "AddressV4 couldn't be initialized from the underlying raw String value"))
		}
		self = asSelf
	}
	
	public func encode(to encoder: Encoder) throws {
		var singleValThing = encoder.singleValueContainer()
		try singleValThing.encode(self.string)
	}
}

extension RangeV4:Codable {
	public init(from decoder:Decoder) throws {
		let singleValThing = try decoder.singleValueContainer()
		guard let asSelf = Self.init(try singleValThing.decode(String.self)) else {
			throw DecodingError.typeMismatch(RangeV4.self, DecodingError.Context(codingPath:decoder.codingPath, debugDescription: "RangeV4 couldn't be initialized from the underlying raw String value"))
		}
		self = asSelf
	}
	
	public func encode(to encoder: Encoder) throws {
		var singleValThing = encoder.singleValueContainer()
		try singleValThing.encode(self.string)
	}
}

extension NetworkV4:Codable {
	public init(from decoder:Decoder) throws {
		let singleValThing = try decoder.singleValueContainer()
		guard let asSelf = Self.init(cidr:try singleValThing.decode(String.self)) else {
			throw DecodingError.typeMismatch(NetworkV4.self, DecodingError.Context(codingPath:decoder.codingPath, debugDescription: "NetworkV4 couldn't be initialized from the underlying raw String value"))
		}
		self = asSelf
	}
	
	public func encode(to encoder: Encoder) throws {
		var singleValThing = encoder.singleValueContainer()
		try singleValThing.encode(self.cidrString)
	}
}
