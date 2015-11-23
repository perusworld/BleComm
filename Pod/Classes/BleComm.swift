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
    var deviceId: NSUUID!

    var connectionCallback:(()->())?
    var disconnectionCallback:(()->())?
    var dataCallback:((string:NSString?)->())?
    
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
    
    public func didReceiveData(string: NSString) {
        logger.printLog("didReceiveData \(string)")
        dataCallback?(string: string)
    }
    
    public func connectionFinalized() {
        logger.printLog("connectionFinalized")
        connectionStatus = .Connected
    }


    public func didEncounterError(error: NSString) {
        logger.printLog( "didEncounterError \(error as String)")
        
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
    
    public init(deviceId: NSUUID, serviceUUID:CBUUID, txUUID:CBUUID, rxUUID:CBUUID, onConnect connectionCallback:(()->())? = nil, onDisconnect disconnectionCallback:(()->())? = nil, onData dataCallback:((data:NSString?)->())? = nil, mxSize:Int?=100, logger:Logger?=DefaultLogger()) {
        super.init()
        self.deviceId = deviceId
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
            if (nil != deviceId) {
                for pher:AnyObject in central.retrievePeripheralsWithIdentifiers([deviceId]) {
                    if pher is CBPeripheral {
                        connectDevice(pher as! CBPeripheral)
                        return
                    }
                }
            }
            central.scanForPeripheralsWithServices([serviceUUID()], options: nil)
            logger.printLog("Searching for BLE Devices")
        } else if central.state == .PoweredOff {
            logger.printLog("Powered off")
            connectionStatus = ConnectionStatus.Disconnected
        }
    }
    
    public func connectDevice(peripheral: CBPeripheral)
    {
        if peripheral.state == CBPeripheralState.Connected || peripheral.state == CBPeripheralState.Connecting {
            centralManager!.cancelPeripheralConnection(peripheral)
        }
        currentPeripheral = SimpleBLEPeripheral(peripheral: peripheral, delegate: self, logger: logger)
        centralManager!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
        
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        centralManager!.stopScan()
        
        connectDevice(peripheral)
    }
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        logger.printLog("Discovering peripheral services")
        currentPeripheral?.didConnect()
    }
    
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        logger.printLog("Peripheral Disconnected: \(peripheral.name)")
        
        if currentPeripheral!.currentPeripheral() == peripheral {
            connectionStatus = ConnectionStatus.Disconnected
            currentPeripheral = nil
        }
    }
    
    public func disconnect() {
        if (ConnectionStatus.Connected == connectionStatus) {
            centralManager!.cancelPeripheralConnection(currentPeripheral!.currentPeripheral())
        }
    }
    
    
}
