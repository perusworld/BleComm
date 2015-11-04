import Foundation
import CoreBluetooth

public protocol BLEPeripheralDelegate: Any {
    func didReceiveData(newData:NSString)
    func connectionFinalized()
    func didEncounterError(error:NSString)
    func serviceUUID() -> CBUUID
    func txUUID() -> CBUUID
    func rxUUID() -> CBUUID
    func maxSize() -> Int
}

public protocol BLEPeripheral: Any {
    func writeString(string:NSString)
    func didConnect()
    func currentPeripheral() -> CBPeripheral
}

public class SimpleBLEPeripheral: NSObject, CBPeripheralDelegate, BLEPeripheral {
    
    var currentPeri:CBPeripheral!
    var delegate:BLEPeripheralDelegate!
    var uartService:CBService?
    var rxCharacteristic:CBCharacteristic?
    var txCharacteristic:CBCharacteristic?
    var knownServices:[CBService] = []
    var logger:Logger!
    
    init(peripheral:CBPeripheral, delegate:BLEPeripheralDelegate, logger:Logger?=DefaultLogger()){
        super.init()
        self.currentPeri = peripheral
        self.currentPeri.delegate = self
        self.delegate = delegate
        self.logger = logger
    }

    public func currentPeripheral() -> CBPeripheral {
        return self.currentPeri;
    }

    public func didConnect() {
        if currentPeri.services != nil{
            logger.printLog( "didConnect Skipping service discovery")
            peripheral(currentPeri, didDiscoverServices: nil)
            return
        }
        
        logger.printLog("didConnect Starting service discovery")
        currentPeri.discoverServices([delegate.serviceUUID()])
    }
    
    
    public func writeString(string:NSString){
        let data = NSData(bytes: string.UTF8String, length: string.length)
        writeRawData(data)
    }
    
    
    func writeRawData(data:NSData) {
        if (txCharacteristic == nil){
            logger.printLog("writeRawData Unable to write data without txcharacteristic")
            return
        }
        
        var writeType:CBCharacteristicWriteType
        
        if (txCharacteristic!.properties.rawValue & CBCharacteristicProperties.WriteWithoutResponse.rawValue) != 0 {
            
            writeType = CBCharacteristicWriteType.WithoutResponse
            
        }
            
        else if ((txCharacteristic!.properties.rawValue & CBCharacteristicProperties.Write.rawValue) != 0){
            
            writeType = CBCharacteristicWriteType.WithResponse
        }
            
        else{
            logger.printLog("writeRawData Unable to write data without characteristic write property")
            return
        }
        
        let dataLength = data.length
        let limit = delegate.maxSize()
        
        if dataLength <= limit {
            currentPeri.writeValue(data, forCharacteristic: txCharacteristic!, type: writeType)
        }
            
        else {
            
            var len = limit
            var loc = 0
            var idx = 0
            while loc < dataLength {
                
                let rmdr = dataLength - loc
                
                if rmdr <= len {
                    len = rmdr
                }
                
                let range = NSMakeRange(loc, len)
                var newBytes = [UInt8](count: len, repeatedValue: 0)
                data.getBytes(&newBytes, range: range)
                let newData = NSData(bytes: newBytes, length: len)
                self.currentPeri.writeValue(newData, forCharacteristic: self.txCharacteristic!, type: writeType)
                
                loc += len
                idx += 1
            }
        }
        
    }
    
    
    //MARK: CBPeripheral Delegate methods
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        if error != nil {
            logger.printLog("didDiscoverServices \(error.debugDescription)")
            return
        }
        let services = peripheral.services! as [CBService]
        
        for s in services {
            
            if (s.characteristics != nil){
                self.peripheral(peripheral, didDiscoverCharacteristicsForService: s, error: nil)
            }
                
            else if UUIDsAreEqual(s.UUID, secondID: delegate.serviceUUID()) {
                uartService = s
                peripheral.discoverCharacteristics(nil, forService: uartService!)
            }
            
        }
        
        logger.printLog("didDiscoverServices all top-level services discovered")
        
    }
    
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if error != nil {
            logger.printLog( "didDiscoverCharacteristicsForService \(error.debugDescription)")
            
            return
        }
        
        logger.printLog("didDiscoverCharacteristicsForService \(service.description) with \(service.characteristics!.count) characteristics")
        let chars = service.characteristics;
        
        for chr in (chars as [CBCharacteristic]?)! {
            
            logger.printLog( "chr.UUID \(chr.UUID.representativeString())")
            switch chr.UUID {
            case delegate.rxUUID():
                logger.printLog("didDiscoverCharacteristicsForService \(service.description) : RX")
                rxCharacteristic = chr
                peripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic!)
                break
            case delegate.txUUID():
                logger.printLog("didDiscoverCharacteristicsForService \(service.description) : TX")
                txCharacteristic = chr
                break
            default:
                break
            }
            
        }
        
        if rxCharacteristic != nil && txCharacteristic != nil {
            self.onConnectionFinalized();
        }
        
    }

    func onConnectionFinalized() {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate.connectionFinalized()
        })
    }
    
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        if error != nil {
            logger.printLog("didDiscoverDescriptorsForCharacteristic \(error.debugDescription)")
        }
            
        else {
            if characteristic.descriptors!.count != 0 {
                for d in characteristic.descriptors! {
                    let desc = d as CBDescriptor!
                    logger.printLog( "didDiscoverDescriptorsForCharacteristic \(desc.description)")
                }
            }
            
        }
        
        
        var allCharacteristics:[CBCharacteristic] = []
        for s in knownServices {
            for c in s.characteristics! {
                allCharacteristics.append(c)
            }
        }
        for idx in 0...(allCharacteristics.count-1) {
            if allCharacteristics[idx] === characteristic {
                if (idx + 1) == allCharacteristics.count {
                }
            }
        }
        
        
    }
    
    public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        logger.printLog( "chrval \(characteristic.value)")
        if error != nil {
            logger.printLog( "didUpdateValueForCharacteristic \(error.debugDescription)")
            return
        }
        
        if (characteristic == self.rxCharacteristic){
            onData(characteristic.value!)
        }
        
        
        
    }

    func onData(newData: NSData) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let string = NSString(data: newData, encoding:NSUTF8StringEncoding)
            self.delegate.didReceiveData(string!)
        })
    }

    public func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
        
        if error != nil {
            logger.printLog( "errdescsrv \(error.debugDescription)")
            return
        }
        
        logger.printLog( "discsrv: \(service.description) has \(service.includedServices!.count) included services")
        
        for s in (service.includedServices! as [CBService]) {
            logger.printLog( "discinclsrv \(s.description)")
        }
        
    }
    
    
    public func handleError(errorString:String) {
        
        logger.printLog( "Error \(errorString)")
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate.didEncounterError(errorString)
        })
        
    }
    
    
}

public class ProtocolBLEPeripheral: SimpleBLEPeripheral {
    let PingIn:UInt8 = 0xCC
    let PingOut:UInt8 = 0xDD
    let Data:UInt8 =  0xEE
    let ChunkedDataStart:UInt8 = 0xEB
    let ChunkedData:UInt8 = 0xEC
    let ChunkedDataEnd:UInt8 = 0xED
    let EOMFirst:UInt8 = 0xFE
    let EOMSecond:UInt8 = 0xFF
    let pingOutData = NSData(bytes: [0xDD, 0xFE, 0xFF] as [UInt8], length: 3)
    let cmdLength = 3
    let dataLength = 100 - 3
    var inSync: Bool = false
    var chunkedDataBuffer: NSMutableData!

    override init(peripheral:CBPeripheral, delegate:BLEPeripheralDelegate, logger:Logger?=DefaultLogger()){
        super.init(peripheral: peripheral, delegate: delegate, logger: logger)
    }

    override func onConnectionFinalized() {
        inSync = false
    }

    func pingIn() {
        writeRawData(self.pingOutData)
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate.connectionFinalized()
        })
    }

    func pingOut() {
        //noop
    }

    func onDataPacket(data: NSData) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let string = NSString(data: data, encoding:NSUTF8StringEncoding)
            self.delegate.didReceiveData(string!)
        })
    }


    override func onData(newData: NSData) {
        var data = [UInt8](count: newData.length, repeatedValue: 0)
        let len = newData.length
        var msgData: NSData?
        newData.getBytes(&data, length: len)
        if (cmdLength < len) {
            var msg = [UInt8](count: len - cmdLength, repeatedValue: 0)
            for index in 1...len-cmdLength {
                msg[index - 1] = data[index]
            }
            msgData = NSData(bytes: msg, length: len - cmdLength)
        }
        if (self.EOMFirst == data[len - 2] && self.EOMSecond == data[len - 1]) {
            switch (data[0]) {
            case self.PingIn:
                self.pingIn()
                break
            case self.PingOut:
                self.pingOut()
                break
            case self.Data:
                self.onDataPacket(msgData!)
                break
            case self.ChunkedDataStart:
                self.chunkedDataBuffer = NSMutableData()
                self.chunkedDataBuffer.appendData(msgData!)
                break
            case self.ChunkedData:
                self.chunkedDataBuffer.appendData(msgData!)
                break
            case self.ChunkedDataEnd:
                self.chunkedDataBuffer.appendData(msgData!)
                self.onDataPacket(self.chunkedDataBuffer)
                break
            default:
                let string = NSString(data: newData, encoding: NSUTF8StringEncoding)
                self.logger.printLog("Unknown data packet \(string)");
                break
            }
        }
    }

    public override func writeString(string:NSString){
        if (self.dataLength < string.length) {
            var toIndex = 0
            var dataMarker = self.ChunkedData
            for (var index = 0; index < string.length; index = index + self.dataLength) {
                var data:NSMutableData = NSMutableData()
                toIndex = min(index + self.dataLength, string.length)
                var chunk = string.substringWithRange(NSRange(location:index, length:toIndex-index)) as NSString
                dataMarker = (index == 0) ? self.ChunkedDataStart : (toIndex == string.length ? self.ChunkedDataEnd : self.ChunkedData)
                data.appendBytes([dataMarker] as [UInt8], length: 1)
                data.appendData(NSData(bytes: chunk.UTF8String, length: chunk.length))
                data.appendBytes([self.EOMFirst, self.EOMSecond] as [UInt8], length: 2)
                writeRawData(data)
            }
        } else {
            let data:NSMutableData = NSMutableData()
            data.appendBytes([self.Data] as [UInt8], length: 1)
            data.appendData(NSData(bytes: string.UTF8String, length: string.length))
            data.appendBytes([self.EOMFirst, self.EOMSecond] as [UInt8], length: 2)
            writeRawData(data)
        }
    }
}
