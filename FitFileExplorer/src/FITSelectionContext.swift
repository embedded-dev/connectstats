//
//  FITSelectionContext.swift
//  GarminConnect
//
//  Created by Brice Rosenzweig on 28/11/2016.
//  Copyright © 2016 Brice Rosenzweig. All rights reserved.
//

import Foundation
import FitFileParser


class FITSelectionContext {
    
    
    static let kFITNotificationConfigurationChanged = Notification.Name( "kFITNotificationConfigurationChanged" )
    //static let kFITNotificationMessageChanged       = Notification.Name( "kFITNotificationMessageChanged" )
    //static let kFITNotificationFieldChanged         = Notification.Name( "kFITNotificationFieldChanged" )

    // MARK: - FitFile
    
    
    let fitFile : FitFile
    lazy var interp : FITFitFileInterpret = FITFitFileInterpret(fitFile: self.fitFile)
    
    // MARK: - Configuration
    
    var speedUnit : GCUnit = GCUnit.kph()
    var distanceUnit : GCUnit = GCUnit.meter()
    
    var enableY2 : Bool = false
    var prettyField : Bool = false;
    
    var queue : [FITSelectionContext] = []
    
    enum DateTimeFormat {
        case full, timeOnly, elapsed
    }
    
    var dateTimeFormat : DateTimeFormat = .elapsed
    var dateStarted : Date? = nil
    // MARK: - Message Selection
    
    var messageTypeDescription : String {
        if let type = self.fitFile.messageTypeDescription(messageType: self.messageType) {
            return type
        }else{
            return "Unknown Message Type"
        }
    }
    var messageType: FitMessageType {
        didSet{
            // If new message does not exist, do nothing
            // else update with some defaults
            if !fitFile.hasMessageType(messageType: messageType) {
                self.messageType = oldValue;
            }else{
                
                if(messageType != oldValue){
                    self.messages = self.fitFile.messages(forMessageType: self.messageType)
                    self.updateWithDefaultForCurrentMessageType()
                    self.notify()
                }
            }
        }
    }
    
    var messages :[FitMessage]

    var message :FitMessage? {
        let useIdx = self.messageIndex < self.messages.count ? self.messageIndex : 0
        var rv : FitMessage?
        
        if useIdx < messages.count {
            rv = messages[useIdx]
        }
        return rv
    }
    
    /// Last few selected Fields
    var messageIndex : Int = 0 {
        didSet {
            if messageIndex >= self.messages.count {
                messageIndex = 0;
            }
        }
    }
    
    // MARK: - Dependent/Stats messages
    var preferredDependendMessageType : [FitMessageType] = [FitMessageType.record,FitMessageType.lap,FitMessageType.session]
    var statsUsing : FitMessageType?
    var statsFor : FitMessageType?
    

    //MARK: - Field Selections
    /// Selected numbers fields in order, lastObject is latest
    fileprivate var selectedNumberFields : [FitFieldKey] = []
    /// Selected location fields in order, lastObject is latest
    fileprivate var selectedLocationFields : [FitFieldKey] = []

    var selectedXField : FitFieldKey = "timestamp"

    var selectedYField :FitFieldKey? {
        get {
            return self.selectedNumberFields.last
        }
        set {
            if let val = newValue {
                if self.selectedNumberFields.count > 0 {
                    self.selectedNumberFields[self.selectedNumberFields.count-1] = val
                }else{
                    self.selectedNumberFields.append(val)
                }
            }
        }
    }

    var selectedY2Field :FitFieldKey? {
        get {
            let cnt = self.selectedNumberFields.count
            return cnt > 1 ? self.selectedNumberFields[cnt-2] : nil
        }
        set {
            if let val = newValue {
                let cnt = self.selectedNumberFields.count
                if cnt > 1 {
                    self.selectedNumberFields[cnt-2] = val
                }else if( cnt > 0){
                    self.selectedNumberFields.insert(val, at: 0)
                }
            }
        }
    }
    
    var selectedLocationField :FitFieldKey?{
        get {
            return self.selectedLocationFields.last
        }
        set {
            if let val = newValue {
                if self.selectedLocationFields.count > 0 {
                    self.selectedLocationFields[self.selectedLocationFields.count-1] = val
                }else{
                    self.selectedLocationFields.append(val)
                }
            }
        }
    }

    
    // MARK: - Initialization and Queue management

    init(fitFile:FitFile){
        self.fitFile = fitFile;
        self.messageType = self.fitFile.preferredMessageType()
        self.messages = self.fitFile.messages(forMessageType: self.messageType)
        self.statsFor = self.messageType
        updateDependent()
        if let file_id = fitFile.messages(forMessageType: .file_id).first,
           let started = file_id.time(field: "time_created") {
            self.dateStarted = started
            
        }
    }
    
    init(withCopy other:FITSelectionContext){
        self.fitFile = other.fitFile
        self.messageType = other.messageType
        self.enableY2 = other.enableY2
        self.distanceUnit = other.distanceUnit
        self.speedUnit = other.speedUnit
        self.prettyField = other.prettyField
        self.selectedXField = other.selectedXField
        self.selectedLocationFields = other.selectedLocationFields
        self.selectedNumberFields = other.selectedNumberFields
        self.statsUsing = other.statsUsing
        self.statsFor = other.statsFor
        self.preferredDependendMessageType = other.preferredDependendMessageType
        self.messages = other.messages
        
    }
    
    func push(){
        if queue.count == 0 || queue.last != self{
            let saved = FITSelectionContext(withCopy:self)
            queue.append(saved)
        }
    }
    
    // MARK: - change selection
    
    func notify(){
        NotificationCenter.default.post(name: FITSelectionContext.kFITNotificationConfigurationChanged, object: self)
    }

    /// Update selection for index and record if number or location field selected
    func selectMessageField(field:FitFieldKey, atIndex idx: Int){
        let messages = self.messages
        
        let useIdx = idx < messages.count ? idx : 0
        
        if useIdx < messages.count {
            self.messageIndex = useIdx
            if let message = self.message{
                if message.numberWithUnit(field: field) != nil{
                    selectedNumberFields.append(field)
                }else if( message.coordinate(field: field) != nil){
                    selectedLocationFields.append(field)
                }
            }
        }
    }
    
    private func updateDependent(){
        for one in self.preferredDependendMessageType {
            if one != self.statsFor && self.fitFile.messages(forMessageType: one).count != 0{
                self.statsUsing = one
                break
            }
        }
    }
    
    /// Setup fields if new message selected
    private func updateWithDefaultForCurrentMessageType(){
        if self.messageType == FitMessageType.lap || self.messageType == FitMessageType.session {
            self.statsFor = self.messageType
        }
        
        messageIndex = 0
        selectedNumberFields = []
        if let first = self.message?.fieldKeysWithNumberWithUnit().first{
            selectedNumberFields.append(first)
        }
        selectedLocationFields = []
        if let first = self.message?.fieldKeysWithCoordinate().first{
            selectedLocationFields.append(first)
        }
        if( selectedXField == "timestamp" && self.message?.time(field: "start_time") != nil){
            selectedXField = "start_time"
        }else if( self.message?.time(field: selectedXField) == nil){
            selectedXField = "timestamp"
        }
        self.updateDependent()
    }
    
    // MARK: - Display
    
    
    
    
    /// Convert to relevant unit or just description
    ///
    /// - Parameter fieldValue: value to display
    /// - Returns: string
    func display( fieldValue : FitFieldValue) -> String {
        switch ( fieldValue.fitValue ){
        case .time(let date):
            switch self.dateTimeFormat {
            case .full:
                return (date as NSDate).datetimeFormat()
            case .timeOnly:
                return (date as NSDate).timeShortFormat()
            case .elapsed:
                if let started = self.dateStarted {
                    let elapsed = GCNumberWithUnit(name: "second", andValue: date.timeIntervalSince(started))
                    return elapsed.description
                }else{
                    return (date as NSDate).timeShortFormat()
                }
            }
        case .valueUnit:
            if let nu = fieldValue.numberWithUnit {
                return self.display(numberWithUnit: nu)
            }
        default:
            return fieldValue.displayString()
        }
        return fieldValue.displayString()
    }
    
    func display( numberWithUnit nu: GCNumberWithUnit) -> String{
        if GCUnit.getGlobalSystem() != .default {
            // for speed use better than mps
            if nu.unit.canConvert(to: GCUnit.mps() ) {
                return nu.convert(to: GCUnit.kph().forGlobalSystem()).description
            }else{
                return nu.convertToGlobalSystem().description
            }
        }else{
            return nu.description
        }
    }
    
    func displayField( fitMessageType: FitMessageType, fieldName : String ) -> NSAttributedString {
        var displayText = fieldName
        let paragraphStyle = NSMutableParagraphStyle()
        
        paragraphStyle.lineBreakMode = NSLineBreakMode.byTruncatingMiddle
        
        let disabledLabelColor = NSColor(named: "DisabledLabel") ?? NSColor.lightGray
        let highlightLabelColor = NSColor(named: "HighlightedLabel") ?? NSColor.black
        
        var attr = [ NSAttributedString.Key.font:NSFont.systemFont(ofSize: 12.0),
                     NSAttributedString.Key.foregroundColor:highlightLabelColor,
                     NSAttributedString.Key.paragraphStyle: paragraphStyle]
        
        if self.prettyField {
            if let field = self.interp.fieldKey(fitMessageType: fitMessageType, fitField: fieldName){
                displayText = field.displayName()
            }else{
                
                attr = [NSAttributedString.Key.font:NSFont.systemFont(ofSize: 12.0),
                        NSAttributedString.Key.foregroundColor:disabledLabelColor,
                        NSAttributedString.Key.paragraphStyle:paragraphStyle]
            }
        }
        return NSAttributedString(attr, with: displayText)
    }
    
    // MARK: - Extract Information about current selection
    
    func availableNumberFields() -> [String] {
        if let message = self.message {
            return message.fieldKeysWithNumberWithUnit()
        }
        return []
    }
    func availableDateFields() -> [String] {
        if let message = self.message {
            return message.fieldKeysWithTime()
        }
        return []
    }

}

extension FITSelectionContext: Equatable {
    static func ==(lhs: FITSelectionContext, rhs: FITSelectionContext) -> Bool {
        return lhs.selectedNumberFields == rhs.selectedNumberFields && lhs.selectedLocationFields == rhs.selectedLocationFields
    }
}
