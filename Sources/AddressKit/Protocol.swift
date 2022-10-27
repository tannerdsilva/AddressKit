public protocol Address:Comparable, Hashable {
	var string:String { get }

	var isPrivate:Bool { get }
	var isReserved:Bool { get }
	
	init?(_:String)
}

public protocol Range:Hashable {
	var string:String { get }
	
	init?(_:String)
}

public protocol Network:Hashable {
	var cidrString:String { get }
	
	init?(cidr:String)
}
