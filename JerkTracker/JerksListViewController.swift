//
//  JerksListViewController.swift
//  JerkTracker
//
//  Created by Vasiliy Dumanov on 2/20/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit

private final class TextFieldDelegate : NSObject, UITextFieldDelegate {
    var validateNotEmptyCallback: ((Bool) -> ())!
    private(set) var currentText: String = ""
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? ""
        validateNotEmptyCallback(!newText.isEmpty)
        currentText = newText
        return true
    }
}

class JerksListViewController: UIViewController {
    private var _jerkFileNames: [String] = []
    private var _jerkFilePaths: [String] = []
    private var _tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Jerks List"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addJerkAction))
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadJerkFiles()
    }
    
    private func loadJerkFiles() {
        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let jerksDirPath = (documentsPath as NSString).appendingPathComponent("Jerks")
        _jerkFileNames = try! fm.contentsOfDirectory(atPath: jerksDirPath)
        _jerkFilePaths = _jerkFileNames.map { name in
            (jerksDirPath as NSString).appendingPathComponent(name)
        }
        _tableView.reloadData()
    }
    
    private func setupTableView() {
        _tableView = UITableView(frame: view.bounds).then {
            $0.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            $0.register(UITableViewCell.self, forCellReuseIdentifier: "JerkCell")
            $0.dataSource = self
            $0.delegate = self
            $0.backgroundColor = .black
        }
        view.addSubview(_tableView)
    }
    
    @objc private func addJerkAction() {
        let tfDelegate = TextFieldDelegate()
        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            let recordVC = RecordJerkViewController(jerkName: tfDelegate.currentText)
            self?.navigationController?.pushViewController(recordVC, animated: true)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        tfDelegate.validateNotEmptyCallback = { isNotEmpty in
            okAction.isEnabled = isNotEmpty
        }
        let alert = UIAlertController(title: nil, message: "Create jerk", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Enter jerk name"
            tf.delegate = tfDelegate
        }
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
}

extension JerksListViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _jerkFileNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "JerkCell", for: indexPath)
        cell.textLabel?.text = _jerkFileNames[indexPath.row]
        cell.backgroundColor = .black
        cell.textLabel?.textColor = .white
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let jerkFileUrl = URL(fileURLWithPath: _jerkFilePaths[indexPath.row])
        let activityViewController = UIActivityViewController(activityItems: [jerkFileUrl], applicationActivities: nil)
        present(activityViewController, animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let alert = UIAlertController(title: nil, message: "Delete \(_jerkFileNames[indexPath.row])?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "No", style: .cancel) { _ in
            
        })
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [unowned self] _ in
            try! FileManager.default.removeItem(atPath: self._jerkFilePaths[indexPath.row])
            self._jerkFilePaths.remove(at: indexPath.row)
            self._jerkFileNames.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        })
        present(alert, animated: true, completion: nil)
    }
}
