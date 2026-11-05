import Foundation
let path = CommandLine.arguments[1]
let expected = CommandLine.arguments[2]
guard let bundle = Bundle(path: path) else { fatalError("App bundle missing") }
let display = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
let finder = FileManager.default.displayName(atPath: path)
let report: [String: Any] = ["displayName": display ?? "", "bundleName": name ?? "", "finderName": finder, "preferredLocalizations": bundle.preferredLocalizations, "expected": expected, "passed": display == expected && name == expected]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
exit(display == expected && name == expected ? 0 : 1)
