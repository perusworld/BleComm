import Foundation
import CoreBluetooth

public enum ConnectionStatus {
    case Disconnected
    case Scanning
    case Connected
}


public class BLEComm : NSObject, CBCentralManagerDelegate, BLEPeripheralDelegate {
    var centralManager : CBCentralManager!
    var currentPeripheral:BLEPeripheral?
    var sUUID:CBUUID!
    var tUUID:CBUUID!
    var rUUID:CBUUID!
    var mxSize:Int!
    var logger:Logger!
    
    var connectionCallback:(()->())?
    var disconnectionCallback:(()->())?
    var dataCallback:((data:NSData?, string:String?)->())?
    
    public private(set) var connectionStatus:ConnectionStatus = ConnectionStatus.Disconnected {
        didSet {
            if connectionStatus != oldValue {
                switch connectionStatus {
                case .Connected:
                    connectionCallback?()
                default:
                    disconnectionCallback?()
                }
            }
        }
    }
    
    public func didReceiveData(newData: NSData) {
        logger.printLog(self, funcName: "didReceiveData", "\(newData.stringRepresentation())")
        let string = NSString(data: newData, encoding:NSUTF8StringEncoding)
        dataCallback?(data: newData, string: string! as String)
    }
    
    public func connectionFinalized() {
        logger.printLog(self, funcName: "connectionFinalized")
        connectionStatus = .Connected
    }
    
    
    public func uartDidEncounterError(error: NSString) {
        logger.printLog(self, funcName: "uartDidEncounterError", error as String)
        
    }
    
    public func serviceUUID() -> CBUUID {
        return sUUID
    }
    
    public func txUUID() -> CBUUID {
        return tUUID
    }
    
    public func rxUUID() -> CBUUID {
        return rUUID
    }
    
    public func maxSize() -> Int {
        return mxSize
    }
    
    public func writeString(string:NSString) -> Bool
    {
        if let currentPeripheral = self.currentPeripheral {
            if connectionStatus == .Connected {
                currentPeripheral.writeString(string)
                return true
            }
        }
        return false
    }
    
    
    func writeRawData(data:NSData) -> Bool
    {
        if let currentPeripheral = self.currentPeripheral {
            if connectionStatus == .Connected {
                currentPeripheral.writeRawData(data)
                return true
            }
        }
        return false
    }
    
    public init(serviceUUID:CBUUID, txUUID:CBUUID, rxUUID:CBUUID, onConnect connectionCallback:(()->())? = nil, onDisconnect disconnectionCallback:(()->())? = nil, onData dataCallback:((data:NSData?, string:String?)->())? = nil, mxSize:Int?=512, logger:Logger?=DefaultLogger()) {
        super.init()
        self.sUUID = serviceUUID
        self.tUUID = txUUID
        self.rUUID = rxUUID
        self.mxSize = mxSize
        centralManager = CBCentralManager(delegate: self, queue: nil)
        self.connectionCallback = connectionCallback
        self.disconnectionCallback = disconnectionCallback
        self.dataCallback = dataCallback
        self.logger = logger
    }
    
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn {
            central.scanForPeripheralsWithServices([serviceUUID()], options: nil)
            logger.printLog(self, funcName: "Searching for BLE Devices")
        } else if central.state == .PoweredOff {
            logger.printLog(self, funcName: "Powered off")
            connectionStatus = ConnectionStatus.Disconnected
        }
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        centralManager!.stopScan()
        if peripheral.state == CBPeripheralState.Connected || peripheral.state == CBPeripheralState.Connecting {
            centralManager!.cancelPeripheralConnection(peripheral)
        }
        currentPeripheral = BLEPeripheral(peripheral: peripheral, delegate: self, logger: logger)
        centralManager!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
    }
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        logger.printLog(self, funcName: "Discovering peripheral services")
        currentPeripheral?.didConnect()
    }
    
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        logger.printLog(self, funcName: "Peripheral Disconnected:" , "\(peripheral.name)")
        
        if currentPeripheral?.currentPeripheral == peripheral {
            connectionStatus = ConnectionStatus.Disconnected
            currentPeripheral = nil
        }
    }
}
