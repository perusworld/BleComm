import Foundation
import CoreBluetooth

public extension NSData {
    
    func hexRepresentationWithSpaces(spaces:Bool) ->NSString {
        
        var byteArray = [UInt8](count: self.length, repeatedValue: 0x0)
        self.getBytes(&byteArray, length:self.length)
        
        var hexBits = "" as String
        for value in byteArray {
            let newHex = NSString(format:"0x%2X", value) as String
            hexBits += newHex.stringByReplacingOccurrencesOfString(" ", withString: "0", options: NSStringCompareOptions.CaseInsensitiveSearch)
            if spaces {
                hexBits += " "
            }
        }
        return hexBits
    }
    
    
    func hexRepresentation()->String {
        
        let dataLength:Int = self.length
        let string = NSMutableString(capacity: dataLength*2)
        let dataBytes = UnsafePointer<UInt8>(self.bytes)
        for idx in 0..<dataLength {
            //print(dataBytes[idx])
            string.appendFormat("%02x", dataBytes[idx])
        }
        
        return string as String
    }
    
    func hexArray()->[String] {
        var ret = [String]()
        let dataLength:Int = self.length
        let string = NSMutableString(capacity: dataLength*2)
        let dataBytes = UnsafePointer<UInt8>(self.bytes)
        for idx in 0..<dataLength {
            ret.append(String(format:"%02x", arguments: [dataBytes[idx]]))
        }
        
        return ret
    }
    
    func stringRepresentation()->String {
        let dataLength:Int = self.length
        var data = [UInt8](count: dataLength, repeatedValue: 0)
        
        self.getBytes(&data, length: dataLength)
        
        for index in 0..<dataLength {
            if (data[index] <= 0x1f) || (data[index] >= 0x80) { //null characters
                if (data[index] != 0x9)       //0x9 == TAB
                    && (data[index] != 0xa)   //0xA == NL
                    && (data[index] != 0xd) { //0xD == CR
                    data[index] = 0xA9
                }
                
            }
        }
        
        let newString = NSString(bytes: &data, length: dataLength, encoding: NSUTF8StringEncoding)
        
        return newString! as String
        
    }
    
}


public extension NSString {
    
    func toHexSpaceSeparated() ->NSString {
        
        let len = UInt(self.length)
        var charArray = [unichar](count: self.length, repeatedValue: 0x0)
        
        self.getCharacters(&charArray)
        
        let hexString = NSMutableString()
        var charString:NSString
        
        for i in 0..<len {
            charString = NSString(format: "0x%02X", charArray[Int(i)])
            
            if (charString.length == 1){
                charString = "0".stringByAppendingString(charString as String)
            }
            
            hexString.appendString(charString.stringByAppendingString(" "))
        }
        
        
        return hexString
    }
    
}

public extension String {
    
    func subStr(from:Int, to: Int) ->String {
        let start = self.startIndex.advancedBy(from)
        let end = self.startIndex.advancedBy(to)
        let range = start..<end
        return self.substringWithRange(range)
    }
    
    func hexInt(from:Int, to: Int) ->Int {
        let value = self.subStr(from, to: to)
        var outVal: CUnsignedInt = 0
        let scanner: NSScanner = NSScanner(string: value)
        scanner.scanHexInt(&outVal)
        return Int(outVal)
    }
    
    func hexByteArray() ->[UInt8] {
        var ret = [UInt8]()
        var index = 0
        while index + 2 <= characters.count {
            ret.append(UInt8(self.hexInt(index, to: index+2)))
            index += 2
        }
        return ret
    }
    
}


public extension CBUUID {
    
    func representativeString() ->NSString{
        
        let data = self.data
        var byteArray = [UInt8](count: data.length, repeatedValue: 0x0)
        data.getBytes(&byteArray, length:data.length)
        
        let outputString = NSMutableString(capacity: 16)
        
        for value in byteArray {
            
            switch (value){
            case 9:
                outputString.appendFormat("%02x-", value)
                break
            default:
                outputString.appendFormat("%02x", value)
            }
            
        }
        
        return outputString
    }
    
    
    func equalsString(toString:String, caseSensitive:Bool, omitDashes:Bool)->Bool {
        
        var aString = toString
        var verdict = false
        var options = NSStringCompareOptions.CaseInsensitiveSearch
        
        if omitDashes == true {
            aString = toString.stringByReplacingOccurrencesOfString("-", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        }
        
        if caseSensitive == true {
            options = NSStringCompareOptions.LiteralSearch
        }
        
        verdict = aString.compare(self.representativeString() as String, options: options, range: nil, locale: NSLocale.currentLocale()) == NSComparisonResult.OrderedSame
        
        return verdict
        
    }
    
}

public protocol Logger {
    
    func printLog(logString:String)
}


public class DefaultLogger : Logger {
    
    public init() {
        
    }
    
    public func printLog(logString:String) {
        print(logString)
    }
    
}

func binaryforByte(value: UInt8) -> String {
    
    var str = String(value, radix: 2)
    let len = str.characters.count
    if len < 8 {
        var addzeroes = 8 - len
        while addzeroes > 0 {
            str = "0" + str
            addzeroes -= 1
        }
    }
    
    return str
}


func UUIDsAreEqual(firstID:CBUUID, secondID:CBUUID)->Bool {
    
    if firstID.representativeString() == secondID.representativeString() {
        return true
    }
        
    else {
        return false
    }
    
}
