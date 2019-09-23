//
//  ViewController.swift
//  Archery Motion Study
//
//  Created by Juan Ignacio Rodríguez Liébana on 13/09/2019.
//  Copyright © 2019 liebanajr. All rights reserved.
//

import UIKit
import CoreData
import Firebase

class filesViewController: UITableViewController{
    
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var deleteButton: UIBarButtonItem!
    
    let fileManager = FileManager()
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    var filesArray : [MotionDataFile] = []
    
    var exportedFileName = ""
    
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as NSArray
    var documentDir :String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(updateTableWithDirectoryData), name: Notification.Name("NewDataAvailable"), object: nil)
        
        
        documentDir = paths.firstObject as! String + "/MotionData"
        print("Motion data directory: \(documentDir)")
        
        uploadFiles()
        
        updateTableWithDirectoryData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filesArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "fileItemCell", for: indexPath) as! FileItemViewCell
        
        if #available(iOS 13, *) {
            cell.uploadedCheckmark.image = UIImage(systemName: "cloud.fill")
        }
        
        let item = filesArray[indexPath.row]
        cell.fileNameLabel.text = item.fileName
        cell.uploadedCheckmark.isHidden = item.isUploaded ? false : true
        
        return cell
    }
    
    
//    Methods for deleting items
    @IBAction func deleteButtonPressed(_ sender: Any) {
        
        let alert = UIAlertController(title: "Eliminar datos", message: "¿Seguro que deseas eliminar los datos seleccionados de tu dispositivo?\nPor favor, antes de elminar los datos, comprueba que se han sincronizado correctamente y aparece una nube azul en la fila correspondiente", preferredStyle: .actionSheet)
        let actionDelete = UIAlertAction(title: "Eliminar seleccionados", style: .destructive) { (action) in
            let items = self.tableView.indexPathsForSelectedRows!
            self.deleteItems(itemPath: items)
        }
        let actionDeleteAll = UIAlertAction(title: "Eliminar todo", style: .destructive) { (action) in
            self.deleteItems(itemPath: nil)
        }
        alert.addAction(actionDelete)
        alert.addAction(actionDeleteAll)
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    
    }
    func deleteItems(itemPath: [IndexPath]?) {
        
        let dir = self.documentDir
        
        if itemPath == nil{
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: dir)
                for path in contents {
                    try fileManager.removeItem(atPath: dir + "/" + path)
                }
                for object in filesArray {
                    context.delete(object)
                }
                try context.save()
                print("Removed all items at \(dir)")
                updateTableWithDirectoryData()
            } catch {
                print("Error removing files: \(error)")
            }
            return
        }
        
        for item in itemPath! {
            let file = filesArray[item.row]
            let fileName = file.fileName!
            do {
                try fileManager.removeItem(atPath: dir + "/" + fileName)
                context.delete(file)
                try context.save()
                print("Removed item: \(fileName)")
                updateTableWithDirectoryData()
            } catch {
                print("Error removing file \(fileName): \(error)")
            }
        }
        
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteItems(itemPath: [indexPath])
        }
    }
    
//    Updates the UI with new data
    @objc func updateTableWithDirectoryData (){
        
        do {

            filesArray.removeAll(keepingCapacity: false)

            let request : NSFetchRequest<MotionDataFile> = MotionDataFile.fetchRequest()
            filesArray = try context.fetch(request)
            
            print("Updated table view with data:")
            for item in filesArray{
                print("\(item.fileName!) isUploaded: \(item.isUploaded)")
            }

        } catch {
            print("Error looking for files in database: \(error)")
        }
        DispatchQueue.main.async {
            self.tableView.isEditing = false
            self.editButton.title = "Edit"
            self.editButton.style = .plain
//            self.uploadButton.isEnabled = false
            self.deleteButton.isEnabled = false
//            self.updateButton.isEnabled = true
            self.tableView.reloadData()
        }
        
    }
    
//    Sharing data
    
    func uploadFiles() {

        for motionDataFileItem in filesArray {
            
            if !motionDataFileItem.isUploaded {
                
                let fileName = motionDataFileItem.fileName!
                let storage = Storage.storage()
                let storageRef = storage.reference()
                let motionDataDestination = storageRef.child("motion-study-v1/" + fileName)
                let srcURL = URL(fileURLWithPath: documentDir + "/" + fileName)
                

                let uploadTask = motionDataDestination.putFile(from: srcURL, metadata: nil) { metadata, error in
                    if error != nil {
                      // Uh-oh, an error occurred!
                        print("Error uploading file: \(error!)")
                        return
                    }
                }

                uploadTask.observe(.success) { (snapshot) in
                    
                    print("Uploaded \(fileName) successfully!!")
                    motionDataFileItem.setValue(true, forKey: "isUploaded")
                    do {
                        try self.context.save()
                    } catch {
                        print("Error while saving context: \(error)")
                    }
                    self.updateTableWithDirectoryData()
                    uploadTask.removeAllObservers()
                }
                
            }
        }
        
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.indexPathsForSelectedRows == nil {
            deleteButton.isEnabled = false
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if !tableView.isEditing {
            let file = filesArray[indexPath.row]
            exportedFileName = documentDir + "/" + file.fileName!
            tableView.deselectRow(at: indexPath, animated: true)

            
            self.performSegue(withIdentifier: "goToGraph", sender: self)
            exportedFileName = ""
            
        }
        
        deleteButton.isEnabled = true
        
        
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToGraph" {
            let vc = segue.destination as? ChartViewController
            vc?.importedFileName = exportedFileName
        }
    }
    
    @IBAction func editButtonPressed(_ sender: Any) {
        
        if tableView.isEditing {
            tableView.setEditing(false, animated: true)
            editButton.title = "Edit"
            editButton.style = .plain
            deleteButton.isEnabled = false
        } else {
            tableView.setEditing(true, animated: true)
            editButton.title = "Done"
            editButton.style = .done
        }
        
    }
    
    
    

}

