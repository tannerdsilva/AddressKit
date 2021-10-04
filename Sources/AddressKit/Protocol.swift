public protocol Address:Comparable, Hashable {
	var string:String { get }

	var isPrivate:Bool { get }
	var isReserved:Bool { get }
}
