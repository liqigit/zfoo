import Foundation

class ByteBuffer {
    var buffer: [Int8] = Array<Int8>(repeating: 0, count: 128)
    var writeOffset: Int = 0
    var readOffset: Int = 0
    
    func adjustPadding(_ predictionLength: Int, _ beforewriteIndex: Int) {
        // 因为写入的是可变长的int，如果预留的位置过多，则清除多余的位置
        let currentwriteIndex = writeOffset
        let predictionCount = writeIntCount(predictionLength)
        let length = currentwriteIndex - beforewriteIndex - predictionCount
        let lengthCount = writeIntCount(length)
        let padding = lengthCount - predictionCount
        if (padding == 0) {
            writeOffset = beforewriteIndex
            writeInt(length)
            writeOffset = currentwriteIndex
        } else {
            let bytes = Array<Int8>(buffer[(currentwriteIndex - length)..<currentwriteIndex])
            writeOffset = beforewriteIndex
            writeInt(length)
            writeBytes(bytes)
        }
    }
    
    func compatibleRead(_ beforeReadIndex: Int, _ length: Int) -> Bool {
        return length != -1 && readOffset < length + beforeReadIndex
    }
    
    func getBuffer() -> [Int8] {
        return buffer
    }
    
    func getWriteOffset() -> Int {
        return writeOffset
    }
    
    func setWriteOffset(_ writeIndex: Int) {
        writeOffset = writeIndex
    }
    
    func getReadOffset() -> Int {
        return readOffset
    }
    
    func setReadOffset(_ readIndex: Int) {
        readOffset = readIndex
    }
    
    func isReadable() -> Bool {
        return writeOffset > readOffset
    }
    
    func writeBytes(_ bytes: [Int8]) {
        let length = bytes.count
        buffer[writeOffset..<(writeOffset + length)] = bytes[0..<length]
        writeOffset += length
    }
    
    func readBytes(_ length: Int) -> [Int8] {
        let bytes = buffer[readOffset..<(readOffset + length)]
        readOffset += length
        return Array<Int8>(bytes)
    }
    
    func writeUBytes(_ bytes: [UInt8]) {
        let length = bytes.count
        ensureCapacity(length)
        for ubyte in bytes {
            writeUByte(ubyte)
        }
    }
    
    func toBytes() -> [Int8] {
        return Array<Int8>(buffer[0..<writeOffset])
    }
    
    func getCapacity() -> Int {
        return buffer.count - writeOffset;
    }
    
    func ensureCapacity(_ capacity: Int) {
        while (capacity - getCapacity() > 0) {
            let newSize = buffer.count * 2
            var newBytes = Array<Int8>(repeating: 0, count: newSize)
            newBytes.append(contentsOf: buffer)
            buffer = newBytes
        }
    }
    
    func writeBool(_ value: Bool) {
        ensureCapacity(1)
        buffer[writeOffset] = value ? 1 : 0
        writeOffset += 1
    }
    
    func readBool() -> Bool {
        let value = buffer[readOffset] == 1 ? true : false
        readOffset += 1
        return value
    }

    func writeByte(_ value: Int8) {
        ensureCapacity(1)
        buffer[writeOffset] = value
        writeOffset += 1
    }
    
    func readByte() -> Int8 {
        let value = buffer[readOffset]
        readOffset += 1
        return value
    }
    
    func writeUByte(_ value: UInt8) {
        ensureCapacity(1)
        buffer[writeOffset] = Int8(bitPattern: value)
        writeOffset += 1
    }
    
    func readUByte() -> UInt8 {
        let value = buffer[readOffset]
        readOffset += 1
        return UInt8(bitPattern: value)
    }
    
    func writeShort(_ value: Int16) {
        ensureCapacity(2)
        buffer[writeOffset] = Int8(bitPattern: UInt8(value >> 8 & 0xFF))
        buffer[writeOffset + 1] = Int8(bitPattern: UInt8(value & 0xFF))
        writeOffset += 2
    }
    
    func readShort() -> Int16 {
        let value = Int16(UInt8(bitPattern: buffer[readOffset])) << 8 | Int16(UInt8(bitPattern: buffer[readOffset + 1]))
        readOffset += 2
        return value
    }
    
    func writeIntCount(_ intValue: Int) -> Int {
        let longValue = Int64(intValue)
        let value = UInt64(bitPattern: ((longValue << 1) ^ (longValue >> 63)))
        if (value >> 7 == 0) {
            return 1
        }
        if (value >> 14 == 0) {
            return 2
        }
        if (value >> 21 == 0) {
            return 3
        }

        if (value >> 28 == 0) {
            return 4
        }
        return 5
    }
    
    func writeRawInt(_ value: Int32) {
        writeUByte(UInt8(value >> 24 & 0xFF))
        writeUByte(UInt8(value >> 16 & 0xFF))
        writeUByte(UInt8(value >> 8 & 0xFF))
        writeUByte(UInt8(value & 0xFF))
    }
    
    func readRawInt() -> Int32 {
        let value = Int32(readUByte()) << 24 | Int32(readUByte()) << 16 | Int32(readUByte()) << 8 | Int32(readUByte())
        return value
    }
  
    func writeRawLong(_ value: Int64) {
        writeUByte(UInt8(value >> 56 & 0xFF))
        writeUByte(UInt8(value >> 48 & 0xFF))
        writeUByte(UInt8(value >> 40 & 0xFF))
        writeUByte(UInt8(value >> 32 & 0xFF))
        writeUByte(UInt8(value >> 24 & 0xFF))
        writeUByte(UInt8(value >> 16 & 0xFF))
        writeUByte(UInt8(value >> 8 & 0xFF))
        writeUByte(UInt8(value & 0xFF))
    }
    
    func readRawLong() -> Int64 {
        let value = Int64(readUByte()) << 56 | Int64(readUByte()) << 48 | Int64(readUByte()) << 40 | Int64(readUByte()) << 32 | Int64(readUByte()) << 24 | Int64(readUByte()) << 16 | Int64(readUByte()) << 8 | Int64(readUByte())
        return value
    }
    
    func writeInt(_ value: Int) {
        var v = value
        if (v > 2147483647) {
            v = 2147483647
        } else if (v < -2147483648) {
            v = -2147483648
        }
        writeLong(Int64(v))
    }
    
    func readInt() -> Int {
        return Int(readLong())
    }
    
    func writeLong(_ longValue: Int64) {
        let value = UInt64(bitPattern: ((longValue << 1) ^ (longValue >> 63)))
        
        if (value >> 7 == 0) {
            writeUByte(UInt8(value))
            return;
        }
        
        if (value >> 14 == 0) {
            writeUByte(UInt8((value & 0x7F) | 0x80))
            writeUByte(UInt8(value >> 7))
            return;
        }
        
        if (value >> 21 == 0) {
            writeUByte(UInt8(value & 0x7F | 0x80))
            writeUByte(UInt8((value >> 7 & 0x7F) | 0x80))
            writeUByte(UInt8(value >> 14))
            return;
        }
        
        if ((value >> 28) == 0) {
            writeUByte(UInt8(value & 0x7F | 0x80))
            writeUByte(UInt8((value >> 7 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 14 & 0x7F) | 0x80))
            writeUByte(UInt8(value >> 21))
            return;
        }
        
        if (value >> 35 == 0) {
            writeUByte(UInt8(value & 0x7F | 0x80))
            writeUByte(UInt8((value >> 7 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 14 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 21 & 0x7F) | 0x80))
            writeUByte(UInt8(value >> 28))
            return;
        }
        
        if (value >> 42 == 0) {
            writeUByte(UInt8(value & 0x7F | 0x80))
            writeUByte(UInt8((value >> 7 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 14 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 21 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 28 & 0x7F) | 0x80))
            writeUByte(UInt8(value >> 35))
            return;
        }
        
        if (value >> 49 == 0) {
            writeUByte(UInt8(value & 0x7F | 0x80))
            writeUByte(UInt8((value >> 7 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 14 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 21 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 28 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 35 & 0x7F) | 0x80))
            writeUByte(UInt8(value >> 42))
            return;
        }
        
        if ((value >> 56) == 0) {
            writeUByte(UInt8(value & 0x7F | 0x80))
            writeUByte(UInt8((value >> 7 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 14 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 21 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 28 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 35 & 0x7F) | 0x80))
            writeUByte(UInt8((value >> 42 & 0x7F) | 0x80))
            writeUByte(UInt8(value >> 49))
            return;
        }
        
        writeUByte(UInt8(value & 0x7F | 0x80))
        writeUByte(UInt8((value >> 7 & 0x7F) | 0x80))
        writeUByte(UInt8((value >> 14 & 0x7F) | 0x80))
        writeUByte(UInt8((value >> 21 & 0x7F) | 0x80))
        writeUByte(UInt8((value >> 28 & 0x7F) | 0x80))
        writeUByte(UInt8((value >> 35 & 0x7F) | 0x80))
        writeUByte(UInt8((value >> 42 & 0x7F) | 0x80))
        writeUByte(UInt8((value >> 49 & 0x7F) | 0x80))
        writeUByte(UInt8(value >> 56))
    }
    
    func readLong() -> Int64 {
        var b = UInt64(readUByte())
        var value = b & 0x7F
        if ((b & 0x80) != 0) {
            b = UInt64(readUByte())
            value |= (b & 0x7F) << 7
            if ((b & 0x80) != 0) {
                b = UInt64(readUByte())
                value |= (b & 0x7F) << 14
                if ((b & 0x80) != 0) {
                    b = UInt64(readUByte())
                    value |= (b & 0x7F) << 21
                    if ((b & 0x80) != 0) {
                        b = UInt64(readUByte())
                        value |= (b & 0x7F) << 28
                        if ((b & 0x80) != 0) {
                            b = UInt64(readUByte())
                            value |= (b & 0x7F) << 35
                            if ((b & 0x80) != 0) {
                                b = UInt64(readUByte())
                                value |= (b & 0x7F) << 42
                                if ((b & 0x80) != 0) {
                                    b = UInt64(readUByte())
                                    value |= (b & 0x7F) << 49
                                    if ((b & 0x80) != 0) {
                                        b = UInt64(readUByte())
                                        value |= b << 56
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return Int64(bitPattern: value >> 1) ^ -(Int64(bitPattern: value) & 1)
    }
    
    func writeFloat(_ value: Float32) {
        let v = value.bitPattern.bigEndian
        writeRawInt(Int32(bitPattern: v))
    }
    
    func readFloat() -> Float32 {
        let value = UInt32(bitPattern: readRawInt()).bigEndian
        return Float32(bitPattern: value)
    }
    
    func writeDouble(_ value: Float64) {
        let v = value.bitPattern.bigEndian
        writeRawLong(Int64(bitPattern: v))
    }
    
    func readDouble() -> Float64 {
        let value = UInt64(bitPattern: readRawLong()).bigEndian
        return Float64(bitPattern: value)
    }
    
    func writeString(_ value: String) {
        if (value.isEmpty) {
            writeInt(0)
            return
        }
        if let data = value.data(using: .utf8) {
            let byteArray = [UInt8](data)
            let bytes = byteArray.map { Int8(bitPattern: $0) }
            writeInt(bytes.count)
            writeBytes(bytes)
        }
    }
    
    func readString() -> String {
        let length = readInt()
        if (length <= 0) {
            return ""
        }
        let int8Array = readBytes(length)
        let bytes = int8Array.map { UInt8(bitPattern: $0) }
        let value = String(bytes: bytes, encoding: .utf8)!
        return value
    }
    
    func writePacket(_ packet: Any?, _ protocolId: Int) {
        let pro = ProtocolManager.getProtocol(protocolId)
        pro.write(self, packet)
    }
    
    func readPacket(_ protocolId: Int) -> Any {
        let pro = ProtocolManager.getProtocol(protocolId)
        return pro.read(self)
    }
}
