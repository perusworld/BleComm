import Foundation
import CoreBluetooth

public protocol BLEPeripheralDelegate: Any {
    func didReceiveData(newData:NSData)
    func connectionFinalized()
    func didEncounterError(error:NSString)
    func serviceUUID() -> CBUUID
    func txUUID() -> CBUUID
    func rxUUID() -> CBUUID
    func maxSize() -> Int
}

public class BLEPeripheral: NSObject, CBPeripheralDelegate {
    
    var currentPeripheral:CBPeripheral!
    var delegate:BLEPeripheralDelegate!
    var uartService:CBService?
    var rxCharacteristic:CBCharacteristic?
    var txCharacteristic:CBCharacteristic?
    var knownServices:[CBService] = []
    var logger:Logger!
    
    init(peripheral:CBPeripheral, delegate:BLEPeripheralDelegate, logger:Logger?=DefaultLogger()){
        super.init()
        self.currentPeripheral = peripheral
        self.currentPeripheral.delegate = self
        self.delegate = delegate
        self.logger = logger
    }
    
    
    func didConnect() {
        if currentPeripheral.services != nil{
            logger.printLog( "didConnect Skipping service discovery")
            peripheral(currentPeripheral, didDiscoverServices: nil)
            return
        }
        
        logger.printLog("didConnect Starting service discovery")
        currentPeripheral.discoverServices([delegate.serviceUUID()])
    }
    
    
    func writeString(string:NSString){
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
            currentPeripheral.writeValue(data, forCharacteristic: txCharacteristic!, type: writeType)
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
                self.currentPeripheral.writeValue(newData, forCharacteristic: self.txCharacteristic!, type: writeType)
                
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
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.delegate.connectionFinalized()
            })
        }
        
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
        
        logger.printLog( "didUpdateValueForCharacteristic \(characteristic.value)")
        if error != nil {
            logger.printLog( "didUpdateValueForCharacteristic \(error.debugDescription)")
            return
        }
        
        if (characteristic == self.rxCharacteristic){
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.delegate.didReceiveData(characteristic.value!)
            })
            
        }
        
        
        
    }
    
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
        
        if error != nil {
            logger.printLog( "didDiscoverIncludedServicesForService \(error.debugDescription)")
            return
        }
        
        logger.printLog( "didDiscoverIncludedServicesForService service: \(service.description) has \(service.includedServices!.count) included services")
        
        for s in (service.includedServices! as [CBService]) {
            logger.printLog( "didDiscoverIncludedServicesForService \(s.description)")
        }
        
    }
    
    
    public func handleError(errorString:String) {
        
        logger.printLog( "Error \(errorString)")
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate.didEncounterError(errorString)
        })
        
    }
    
    
}