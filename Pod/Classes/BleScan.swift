import Foundation
import CoreBluetooth

public class BLEScan : NSObject, CBCentralManagerDelegate {
    var centralManager : CBCentralManager!
    var sUUID:CBUUID!
    var logger:Logger!
    var entries: [String:NSUUID] = [:]
    var timout : NSTimer!
    
    var pherpheralCallback:((pheripherals:[String:NSUUID]?)->())?
    
    public init(serviceUUID:CBUUID, onScanDone pherpheralCallback:((pheripherals:[String:NSUUID]?)->())? = nil, logger:Logger?=DefaultLogger()) {
        super.init()
        self.sUUID = serviceUUID
        centralManager = CBCentralManager(delegate: self, queue: nil)
        self.pherpheralCallback = pherpheralCallback
        self.logger = logger
    }
    
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn {
            central.scanForPeripheralsWithServices([sUUID], options: nil)
            timout = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: #selector(BLEScan.stopScanning), userInfo: nil, repeats: false)
            logger.printLog("Searching for BLE Devices")
        } else if central.state == .PoweredOff {
            logger.printLog("Powered off")
        }
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        entries[peripheral.name!] = peripheral.identifier
    }
    
    func stopScanning() {
        centralManager!.stopScan()
        
        pherpheralCallback!(pheripherals: (entries))
    }
    
    
    
}
