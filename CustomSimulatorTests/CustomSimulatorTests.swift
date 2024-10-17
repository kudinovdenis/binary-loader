import XCTest
import BinaryUtils
import KLActivityLogger

class ActivityTestCase: XCTestCase {
    
    var activity: Activity!
    
    override func setUp() {
        let composer = HumanReadableMessageComposer(outputStyle: .short)
        let logWriter = LogWriterImpl(logMessageComposer: composer, logWriteDestination: SwiftPrintDestination(maxLogLevel: .debug))
        activity = Activity(name: "Test", logWriter: logWriter)
        activity.start()
    }
    
    override func tearDown() {
        activity.markAsReadyToFinish()
    }
    
}

final class RamEditorTests: ActivityTestCase {
    
    func testCreateZeroBytes() throws {
        // Arrange
        let editor = try RamEditor(parentActivity: activity, size: 0)
        
        // Assert
        XCTAssert(editor.size == 0)
    }
    
    func testCreate1Byte() throws {
        // Arrange
        let editor = try RamEditor(parentActivity: activity, size: 1)
        
        // Assert
        XCTAssert(editor.size == 1)
    }
    
    func testWriteAndReadUInt8() throws {
        // Arrange
        let value: UInt8 = .max
        let editor = try RamEditor(parentActivity: activity, size: numericCast(value.sizeInBytes))
        
        // Act
        try editor.write(integer: value)
        
        // Assert
        try editor.setVirtualOffset(0)
        XCTAssert(try editor.readNext() == value)
    }
    
    func testWriteAndReadUInt32() throws {
        // Arrange
        let value: UInt8 = .max
        let editor = try RamEditor(parentActivity: activity, size: numericCast(value.sizeInBytes))
        
        // Act
        try editor.write(integer: value)
        
        // Assert
        try editor.setVirtualOffset(0)
        XCTAssert(try editor.readNext() == value)
    }
    
    func testWriteAndReadUInt64() throws {
        // Arrange
        let value: UInt8 = .max
        let editor = try RamEditor(parentActivity: activity, size: numericCast(value.sizeInBytes))
        
        // Act
        try editor.write(integer: value)
        
        // Assert
        try editor.setVirtualOffset(0)
        XCTAssert(try editor.readNext() == value)
    }
    
    func testWriteAndReadNegativeInt64() throws {
        // Arrange
        let value: UInt8 = .min
        let editor = try RamEditor(parentActivity: activity, size: numericCast(value.sizeInBytes))
        
        // Act
        try editor.write(integer: value)
        
        // Assert
        try editor.setVirtualOffset(0)
        XCTAssert(try editor.readNext() == value)
    }
    
    func testWriteAndReadAtOffset() throws {
        // Arrange
        let editor = try RamEditor(parentActivity: activity, size: 100)
        
        // Act
        let value = 123
        let offset = 50
        try editor.write(integer: value, atOffset: offset)
        XCTAssertEqual(0, editor.virtualOffset)
        
        // Assert
        try editor.setVirtualOffset(offset)
        XCTAssertEqual(try editor.readNext(), value)
    }
    
    func testWriteChangesOffset() throws {
        // Arrange
        let value = 123
        let editor = try RamEditor(parentActivity: activity, size: numericCast(value.sizeInBytes))
        
        // Act
        try editor.write(integer: value)
        
        // Assert
        XCTAssertEqual(numericCast(value.sizeInBytes), editor.virtualOffset)
    }
    
    // Child
    
    func testChildCreatedWithBaseReaderOffset() throws {
        // Arrange
        let editor = try RamEditor(parentActivity: activity, size: 100)
        
        // Act
        let value = 123
        let offset = 50
        try editor.write(integer: value, atOffset: offset)
        let child = try editor.baseReader().child(startingAt: offset)
        
        // Assert
        XCTAssertEqual(value, try child.readNext())
    }
    
    func testChildWithOffset() throws {
        // Arrange
        let editor = try RamEditor(parentActivity: activity, size: 100)
        
        // Act
        let value = 123
        let offset = 50
        try editor.write(integer: value, atOffset: offset)
        let child = try editor.child(startingAt: offset)
        
        // Assert
        XCTAssertEqual(value, try child.readNext())
    }
    
}
