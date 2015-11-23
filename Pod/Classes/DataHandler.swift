//
// Created by Saravana Shanmugam on 11/23/15.
//

import Foundation

public class DataHandler {

    var peripheral:BLEPeripheral
    var delegate:BLEPeripheralDelegate

    init(_ peripheral:BLEPeripheral, delegate:BLEPeripheralDelegate) {
        self.peripheral = peripheral
        self.delegate = delegate
    }

    func writeRawData(data:NSData) {
        peripheral.writeRawData(data)
    }

    public func onConnectionFinalized() {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate.connectionFinalized()
        })
    }

    public func onData(newData: NSData) {
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            let string = NSString(data: newData, encoding:NSUTF8StringEncoding)
            self.delegate.didReceiveData(string!)
        })
    }

    public func writeString(string:NSString){
        let data = NSData(bytes: string.UTF8String, length: string.length)
        writeRawData(data)
    }

}

public class ProtocolDataHandler : DataHandler {
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

    override init(_ peripheral:BLEPeripheral, delegate:BLEPeripheralDelegate) {
        super.init(peripheral, delegate: delegate)
    }

    public override func onConnectionFinalized() {
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


    public override func onData(newData: NSData) {
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
                //let string = NSString(data: newData, encoding: NSUTF8StringEncoding)
                //("Unknown data packet \(string)");
                break
            }
        }
    }

    public override func writeString(string:NSString){
        if (self.dataLength < string.length) {
            var toIndex = 0
            var dataMarker = self.ChunkedData
            for (var index = 0; index < string.length; index = index + self.dataLength) {
                let data:NSMutableData = NSMutableData()
                toIndex = min(index + self.dataLength, string.length)
                let chunk = string.substringWithRange(NSRange(location:index, length:toIndex-index)) as NSString
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
