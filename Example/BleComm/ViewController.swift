//
//  ViewController.swift
//  BleComm
//
//  Created by Saravana Perumal Shanmugam on 09/22/2015.
//  Copyright (c) 2015 Saravana Perumal Shanmugam. All rights reserved.
//

import UIKit
import CoreBluetooth
import BleComm

class ViewController: UIViewController, Logger, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var txtMsg: UITextField!
    @IBOutlet weak var btnConnect: UIButton!
    @IBOutlet weak var tblLogs: UITableView!
    
    var bleComm:  BLEComm?
    var logs = [String]()
    
    var deviceId : NSUUID!
    
    let textCellIdentifier = "TextCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        tblLogs.delegate = self
        tblLogs.dataSource = self
        bleComm = BLEComm (
            deviceId : deviceId,
            serviceUUID: demoServiceUUID(),
            txUUID: txCharacteristicsUUID(),
            rxUUID: rxCharacteristicsUUID(),
            onConnect:{
                self.printLog("Connected");
                self.btnConnect.setTitle("Disconnect", forState: UIControlState.Normal);
            },
            onDisconnect:{
                self.printLog("Disconnect")
                self.btnConnect.setTitle("Connect", forState: UIControlState.Normal);
            },
            onData: {
                (string:NSString?)->() in
                self.printLog(string! as String)
            },
            logger: self
        )
        txtMsg.delegate = self
    }
    
    override func viewWillDisappear(animated: Bool) {
        bleComm!.disconnect()
    }

    @IBAction func connectDisconnect(sender: UIButton) {
        if ("Disconnect" == sender.titleLabel!.text) {
            self.printLog("Going to disconnect");
            bleComm!.disconnect();
        } else {
            self.printLog("Going to connect");
        }
    }
    
    @IBAction func sendMessage(sender: UIButton) {
        self.bleComm!.writeString(txtMsg.text!)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func demoServiceUUID() -> CBUUID {
        return CBUUID(string:"fff0")
    }
    
    func txCharacteristicsUUID() ->  CBUUID {
        return CBUUID(string:"fff1")
    }
    
    func rxCharacteristicsUUID() -> CBUUID {
        return CBUUID(string:"fff2")
    }

    func printLog(obj:AnyObject, funcName:String) {
        logs.insert("\(funcName) \(obj.classForCoder?.description()) ", atIndex: 0);
        tblLogs.reloadData()
    }
    
    func printLog(obj:AnyObject, funcName:String, _ logString:String="") {
        logs.insert(logString, atIndex: 0)
        tblLogs.reloadData()
    }
    
    func printLog(logString:String) {
        logs.insert(logString, atIndex: 0)
        tblLogs.reloadData()
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(textCellIdentifier, forIndexPath: indexPath) as UITableViewCell
        let row = indexPath.row
        cell.textLabel?.text = logs[row]
        return cell
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}

