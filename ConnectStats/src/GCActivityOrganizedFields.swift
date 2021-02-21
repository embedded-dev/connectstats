//  MIT License
//
//  Created on 26/11/2020 for ConnectStats
//
//  Copyright (c) 2020 Brice Rosenzweig
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//



import Foundation
import RZUtilsSwift

class GCActivityOrganizedFields : NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool = true
    
    
    let kPrimaryFields = "primaryFields"
    let kOtherFields = "otherFields"
    let kVersion = "version"

    
    @objc var groupedPrimaryFields : [ [GCField] ] = []
    @objc var groupedOtherFields : [ [GCField] ] = []
    
    @objc var geometry : RZNumberWithUnitGeometry = RZNumberWithUnitGeometry()
    
    @objc override required init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        guard let primary = coder.decodeObject(forKey: kPrimaryFields) as? [ [GCField]] else { return nil }
        guard let other = coder.decodeObject(forKey: kOtherFields) as? [[GCField]] else { return nil }
        
        self.groupedPrimaryFields = primary
        self.groupedOtherFields = other

        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(1, forKey: kVersion)
        coder.encode(self.groupedPrimaryFields, forKey: kPrimaryFields)
        coder.encode(self.groupedOtherFields, forKey: kOtherFields)
    }
    
    @objc func updateGeometry(for activity : GCActivity){
        
        self.geometry = RZNumberWithUnitGeometry()
        self.geometry.numberAlignment = .right
        self.geometry.unitAlignment = .left
        self.geometry.timeAlignment = .center
        for fields in self.groupedPrimaryFields {
            for field in fields {
                guard let nu = activity.numberWithUnit(for: field) else { continue }
                self.geometry.adjust(for: nu,
                                     numberAttribute: GCViewConfig.attribute(rzAttribute.value),
                                     unitAttribute: GCViewConfig.attribute(rzAttribute.unit))
            }
        }
        
    }
    
}
