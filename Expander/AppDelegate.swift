//
//  AppDelegate.swift
//  Expander
//
//  Created by 陳奕利 on 2021/8/8.
//

import Cocoa
import SwiftUI
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	//var window: NSWindow?
	// status bar
	var window: NSWindow!
	var statusbarItem: NSStatusItem!
	var statusbarMenu: NSMenu!
	var model: ExpanderModel!
	// timer for reload ipdate
	var timer: DispatchSourceTimer?
	/*
	## get user permisission
	- https://developer.apple.com/forums/thread/24288
	*/
	// MARK: - remove sandbox to show notification
	//
	func getuserPermission() {
		// for key-press detection
		AXIsProcessTrustedWithOptions(
		[kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
		// for notification
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { 
		_, _ in
	    }
	}
	var appData: AppData!
	
	@objc func openPreferences() {
		let contentView = ContentView().environment(\.managedObjectContext, persistentContainer.viewContext).environmentObject(self.appData)
		// Create the window and set the content view.
		window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
			styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
			backing: .buffered, defer: false)
		window.center()
		NSToolbar.prefToolBar.delegate = self
		window.toolbar = .prefToolBar
		window.contentView = NSHostingView(rootView: contentView)
		window.makeKeyAndOrderFront(nil)
		window.isReleasedWhenClosed = false
		window.makeKey()
	}
	
	//
	var isOn: Bool = true
	//
	let userDefaults = UserDefaults.standard
	//
	var allowNotification: Bool {
		get {
			userDefaults.bool(forKey: "showNotification")
		}
	}
	//
	@objc func toggleExpander() {
		self.isOn.toggle()
		self.setStatusBarIcon()
		if self.allowNotification && !self.isOn {
			self.sendNotification()
		}
	}
	
	func createImage(imgName: String) -> NSImage {
		let image = NSImage(named: imgName)!
		image.isTemplate = true
		image.size = NSSize(width: 16, height: 16)
		return image
	}
	//
	func setStatusBarIcon() {
		let onImage = createImage(imgName: "onImage")
		let offImage = createImage(imgName: "offImage")
		if self.isOn {
			self.statusbarItem.button?.image = onImage
		} else {
			self.statusbarItem.button?.image = offImage
		}
	}
	//
	func createStatusBar() {
		self.statusbarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		self.statusbarMenu = NSMenu()
		self.setStatusBarIcon()
		self.statusbarItem.menu = self.statusbarMenu
		let toggle = NSMenuItem()
		toggle.title = "toggle"
		toggle.action = #selector(toggleExpander)
		toggle.keyEquivalentModifierMask = [.command, .shift]
		toggle.keyEquivalent = "e"
		self.statusbarMenu.addItem(toggle)
		self.statusbarMenu.addItem(withTitle: "Preferences", action: #selector(openPreferences), keyEquivalent: ",")
		self.statusbarMenu.addItem(NSMenuItem.separator())
		self.statusbarMenu.addItem(withTitle: "Quit Expander",
							action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
	}
	
	func initData() {
		userDefaults.register(defaults: [
			"sortMethod": "snippetTrigger",
			"showNotification": false,
			"passiveMode": false,
			"passiveExpandKey": "\\",
			"dateformat": 0
			])
		self.appData = AppData()
	}
	//
    func sendNotification() {
       let content = UNMutableNotificationContent()
       content.title = "Expander is disabled"
       content.subtitle = "Press cmd+shift+e to renable Expander."
       content.sound = UNNotificationSound.default
       let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
       let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
		UNUserNotificationCenter.current().add(request)
    }
	//
	func postLoadIPdataNotification() {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: "loadipdata"), object: self)
	}
	func loadIPdata() {
		timer = DispatchSource.makeTimerSource()
		timer?.schedule(deadline: .now(), repeating: DispatchTimeInterval.seconds(3600), leeway: DispatchTimeInterval.seconds(60))
		timer?.setEventHandler(handler: postLoadIPdataNotification)
	}
	//
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
		// Add `@Environment(\.managedObjectContext)` in the views that will need the context.
		self.initData()
		self.createStatusBar()
		self.getuserPermission()
		self.openPreferences()
		self.model = ExpanderModel()
		// load ip address
		self.loadIPdata()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	// MARK: - Core Data stack

	lazy var persistentContainer: NSPersistentContainer = {
	    /*
	     The persistent container for the application. This implementation
	     creates and returns a container, having loaded the store for the
	     application to it. This property is optional since there are legitimate
	     error conditions that could cause the creation of the store to fail.
	    */
	    let container = NSPersistentContainer(name: "Expander")
	    container.loadPersistentStores(completionHandler: { (storeDescription, error) in
	        if let error = error {
	            // Replace this implementation with code to handle the error appropriately.
	            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

	            /*
	             Typical reasons for an error here include:
	             * The parent directory does not exist, cannot be created, or disallows writing.
	             * The persistent store is not accessible, due to permissions or data protection when the device is locked.
	             * The device is out of space.
	             * The store could not be migrated to the current model version.
	             Check the error message to determine what the actual problem was.
	             */
	            fatalError("Unresolved error \(error)")
	        }
	    })
	    return container
	}()

	// MARK: - Core Data Saving and Undo support

	@IBAction func saveAction(_ sender: AnyObject?) {
	    // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
	    let context = persistentContainer.viewContext

	    if !context.commitEditing() {
	        NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
	    }
	    if context.hasChanges {
	        do {
	            try context.save()
	        } catch {
	            // Customize this code block to include application-specific recovery steps.
	            let nserror = error as NSError
	            NSApplication.shared.presentError(nserror)
	        }
	    }
	}

	func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
	    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
	    return persistentContainer.viewContext.undoManager
	}

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
	    // Save changes in the application's managed object context before the application terminates.
	    let context = persistentContainer.viewContext

	    if !context.commitEditing() {
	        NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
	        return .terminateCancel
	    }

	    if !context.hasChanges {
	        return .terminateNow
	    }

	    do {
	        try context.save()
	    } catch {
	        let nserror = error as NSError

	        // Customize this code block to include application-specific recovery steps.
	        let result = sender.presentError(nserror)
	        if (result) {
	            return .terminateCancel
	        }

	        let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
	        let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
	        let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
	        let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
	        let alert = NSAlert()
	        alert.messageText = question
	        alert.informativeText = info
	        alert.addButton(withTitle: quitButton)
	        alert.addButton(withTitle: cancelButton)

	        let answer = alert.runModal()
	        if answer == .alertSecondButtonReturn {
	            return .terminateCancel
	        }
	    }
	    // If we got here, it is time to quit.
	    return .terminateNow
	}
}

/*
 
*/
