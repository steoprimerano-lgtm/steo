import Foundation
import Darwin

// Invio Art-Net (ArtDmx, porta UDP 6454) verso il nodo.
final class ArtNetSender {
    private var fd: Int32 = -1
    private var sequence: UInt8 = 0
    private let queue = DispatchQueue(label: "artnet.sender")

    init() {
        fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if fd >= 0 {
            var yes: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
        }
    }

    deinit { if fd >= 0 { close(fd) } }

    func send(ip: String, universe: Int, dmx: Data) {
        queue.async { [weak self] in self?.sendNow(ip: ip, universe: universe, dmx: dmx) }
    }

    private func sendNow(ip: String, universe: Int, dmx: Data) {
        guard fd >= 0 else { return }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(6454).bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return }

        var packet = [UInt8](repeating: 0, count: 18 + 512)
        let id = Array("Art-Net".utf8)
        for i in 0..<id.count { packet[i] = id[i] }       // byte 7 resta 0
        packet[8] = 0x00; packet[9] = 0x50                  // OpDmx (0x5000, little endian)
        packet[10] = 0; packet[11] = 14                     // versione protocollo
        sequence = sequence >= 255 ? 1 : sequence + 1
        packet[12] = sequence; packet[13] = 0
        packet[14] = UInt8(universe & 0xff)
        packet[15] = UInt8((universe >> 8) & 0x7f)
        packet[16] = 0x02; packet[17] = 0x00                // 512 canali
        for (i, value) in dmx.prefix(512).enumerated() { packet[18 + i] = value }

        let size = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = packet.withUnsafeBytes { buffer in
            withUnsafePointer(to: &addr) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, buffer.baseAddress, buffer.count, 0, sa, size)
                }
            }
        }
    }
}
