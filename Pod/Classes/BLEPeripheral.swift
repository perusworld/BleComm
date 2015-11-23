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
    func writeRawData(data:NSData)
    func features() -> [String]
}

public class SimpleBLEPeripheral: NSObject, CBPeripheralDelegate, BLEPeripheral {
    let fUUID = CBUUID(string:"fff3")
    var currentPeri:CBPeripheral!
    var delegate:BLEPeripheralDelegate!
    var uartService:CBService?
    var dataHandler:DataHandler?
    var rxCharacteristic:CBCharacteristic?
    var txCharacteristic:CBCharacteristic?
    var knownServices:[CBService] = []
    var logger:Logger!
    var exposedFeatures:[String] = []
    
    init(peripheral:CBPeripheral, delegate:BLEPeripheralDelegate, logger:Logger?=DefaultLogger()){
        super.init()
        self.currentPeri = peripheral
        self.currentPeri.delegate = self
        self.delegate = delegate
        self.logger = logger
    }

    public func currentPeripheral() -> CBPeripheral {
        return self.currentPeri
    }

    public func features() -> [String] {
        return exposedFeatures
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
        dataHandler!.writeString(string)
    }
    
    
    public func writeRawData(data:NSData) {
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
        let chars = service.characteristics
        
        for chr in (chars as [CBCharacteristic]?)! {
            logger.printLog( "chr.UUID \(chr.UUID.representativeString())")
            switch chr.UUID {
            case delegate.rxUUID():
                logger.printLog("didDiscoverCharacteristicsForService \(service.description) : RX")
                rxCharacteristic = chr
                peripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic!)
                peripheral.discoverDescriptorsForCharacteristic(rxCharacteristic!)
                break
            case delegate.txUUID():
                logger.printLog("didDiscoverCharacteristicsForService \(service.description) : TX")
                txCharacteristic = chr
                break
            default:
                break
            }
            
        }
        
    }

    public func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        var found = false
        if error != nil {
            logger.printLog("didDiscoverDescriptorsForCharacteristic \(error.debugDescription)")
        }
        else {
            if characteristic.descriptors!.count != 0 {
                for d in characteristic.descriptors! {
                    if let desc = d as CBDescriptor! {
                        if (desc.UUID == fUUID) {
                            peripheral.readValueForDescriptor(desc)
                            found = true
                        }
                    }
                }
            }
        }

        if (!found) {
            exposedFeatures = ["simple"]
            postFeatureDetection()
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

    public func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        logger.printLog( "desc \(descriptor.value)")
        if error != nil {
            logger.printLog( "didUpdateValueForDescriptor \(error.debugDescription)")
            return
        }

        if (fUUID == descriptor.UUID){
            if let string = NSString(data: descriptor.value as! NSData, encoding:NSUTF8StringEncoding) {
                logger.printLog( "descVal \(string)")
                if (0 < string.length) {
                    exposedFeatures = string.componentsSeparatedByString(",")
                } else {
                    exposedFeatures = ["simple"]
                }
            } else {
                exposedFeatures = ["simple"]
            }
            postFeatureDetection()
        }
    }

    func postFeatureDetection() {
        if (exposedFeatures.contains("protocol")) {
            dataHandler = ProtocolDataHandler(self, delegate: self.delegate)
        } else {
            dataHandler = DataHandler(self, delegate: self.delegate)
        }

        if rxCharacteristic != nil && txCharacteristic != nil {
            dataHandler!.onConnectionFinalized()
        }

    }

    func onData(newData: NSData) {
        dataHandler!.onData(newData)
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

        logger.printLog("Error \(errorString)")

        dispatch_async(dispatch_get_main_queue(), {
            () -> Void in
            self.delegate.didEncounterError(errorString)
        })

    }
}
