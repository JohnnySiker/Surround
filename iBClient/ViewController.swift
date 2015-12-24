//
//  ViewController.swift
//  iBClient
//
//  Created by Jonathan Velazquez on 11/12/15.
//  Copyright © 2015 Jonathan Velazquez. All rights reserved.
//

import UIKit
import CoreBluetooth
import AVFoundation

enum tableToDisplay {
    case Peripherals,Services,Characteristics
    func description()->String {
        switch self {
        case .Peripherals:
            return "Peripherals"
        case .Services:
            return "Services"
        case .Characteristics:
            return "Characteristics"
        }
    }
}

struct peripheralAttributes {
    var peripheral:CBPeripheral!
    var services:[CBService] = []
    var characteristic:[CBCharacteristic] = []
    var preferService: CBService!
    var preferCharacteristic: CBCharacteristic!
}


class TableViewDelegate : NSObject, UITableViewDelegate {
    
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        switch wt {
        case .Peripherals:
            myCentralManager.connectPeripheral(clients[indexPath.row], options: [CBConnectPeripheralOptionNotifyOnConnectionKey:true])
            
            break
        case .Services:
            serviceSelected = services[indexPath.row]
            peripheralConnected.discoverCharacteristics(nil, forService: serviceSelected)
            break
        case .Characteristics:
            print("Selecciono una caracteristica")
            characteristicSelected = characteristics[indexPath.row]
            peripheralConnected.readValueForCharacteristic(characteristicSelected)
            peripheralConnected.setNotifyValue(true, forCharacteristic: characteristicSelected)
            break
        }

    }
    
}


class TableViewDataSource: NSObject, UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch wt {
        case .Peripherals:
            return clients.count
        case .Services:
            return services.count
        case .Characteristics:
            return characteristics.count
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tb.dequeueReusableCellWithIdentifier("cell")
        switch wt {
        case .Peripherals:
            cell?.textLabel?.text = clients[indexPath.row].name!
            break
        case .Services:
            cell?.textLabel?.text = services[indexPath.row].UUID.description
            print(services[indexPath.row])
            break
        case .Characteristics:
            cell?.textLabel?.text = characteristics[indexPath.row].UUID.description
            print(services[indexPath.row])
            break
        }
        
        return cell!
        
    }

}



class ViewController: UIViewController,CBCentralManagerDelegate,CBPeripheralDelegate {
    
    @IBOutlet weak var tb: UITableView!
    
    var clients:[CBPeripheral] = []
    var services:[CBService] = []
    var characteristics:[CBCharacteristic] = []
    
    
    var myCentralManager:CBCentralManager!
    var peripheralConnected:CBPeripheral!
    var serviceSelected:CBService!
    var characteristicSelected:CBCharacteristic!
    
    var wt:tableToDisplay = tableToDisplay.Peripherals
    
    var player:AVAudioPlayer!
    
    var chunk:[NSData] = []
    var didSent = false
    var archivo:NSData!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tb.delegate = TableViewDelegate()
        tb.dataSource = TableViewDataSource()
       
        myCentralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        
        
    }
    
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        if let _ = clients.indexOf(peripheral){
            print("Peripheral ya existe")
        }else{
            clients.append(peripheral)
            tb.reloadData()
        }
    }
    
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        switch central.state {
        case .PoweredOn:
            print("Estado del central manager: .PoweredOn")
            myCentralManager.scanForPeripheralsWithServices(nil, options: nil)
            break
        case .PoweredOff:
            print("Estado del central manager: .PoweredOff")
        case .Resetting:
            print("Estado del central manager: .Resetting")
            break
        case .Unauthorized:
            print("Estado del central manager: .Unauthorized")
            break
        case .Unknown:
            print("Estado del central manager: .Unknown")
            break
        case .Unsupported:
            print("Estado del central manager: .Unsupported")
            break
        }
    }
    
    
    
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("Se conecto satisfactoriamente a \(peripheral.name!)")
        self.peripheralConnected = peripheral
        self.peripheralConnected.delegate = self
        self.peripheralConnected.discoverServices(nil)
        self.myCentralManager.stopScan()
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Fallo conexion con \(peripheral.name!)")
        clients = []
        myCentralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Se desconecto el Peripheral \(peripheral.name!)")
        clients = []
        myCentralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func updatePeripherals(){
        clients = []
        myCentralManager.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if error == nil {
            wt = .Services
            services = []
            services = peripheral.services!
            tb.reloadData()
        }else{
            print("Error al obtener servicios")
        }
        
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if error == nil {
            characteristics = service.characteristics!
            wt = .Characteristics
            tb.reloadData()
        }else{
            print("Error al obtener las caracteristicas del servicio")
            print(error!)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error == nil {
            
            let data  = characteristic.value!
            
            if (NSString(data: data, encoding: NSUTF8StringEncoding)! == "EOF") {
             didSent = false
                print("Se recibio paquete")
                archivo = chunkToData(chunk)
                print(NSString(data: archivo, encoding: NSUTF8StringEncoding))
                //reproducir()
            }
            
            
            if didSent {
                chunk.append(data)
            }
            
            if (NSString(data: data, encoding: NSUTF8StringEncoding)! == "EOM") {
                print("Comenzando a recibir")
                didSent = true
            }
            
            if !didSent {
                print(NSString(data: data, encoding: NSUTF8StringEncoding))
            }
            
        }else{
            print(error)
        }
        
    }
    
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error == nil {
            print("Se notificara sobre esta caracteristica \(characteristic.UUID)")
        }else{
            print("Error actualizacion de caracteristica \(error!)")
        }
        
    }
    
    
    func chunkToData(data:[NSData])->NSData{
        var arrayData:[UInt16] = []
        for i in data{
            let count = i.length / sizeof(UInt16)
            var dataArray = [UInt16](count: count, repeatedValue: 0)
            i.getBytes(&dataArray, length:count * sizeof(UInt16))
            arrayData.append(dataArray[0])
        }
        var d = NSData(bytes: arrayData, length: arrayData.count * sizeof(UInt16))
        return d
    }
    

    func reproducir(){
        do{
            try player = AVAudioPlayer(data: archivo)
            player.prepareToPlay()
            player.play()
        }catch let error {
            print("Error al convertir data a sonido \(error)")
        }
     
    }
    

}

