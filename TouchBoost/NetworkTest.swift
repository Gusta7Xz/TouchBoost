import SwiftUI
import Network
import Darwin

final class NetworkTestModel: ObservableObject {
    @Published var isRunning = false
    @Published var pings: [Double] = []
    @Published var sent = 0
    @Published var lost = 0
    @Published var host = "1.1.1.1"
    @Published var statusText = "Parado"

    private var timer: Timer?
    private var pinger: SimplePinger?

    struct Stats {
        let min: Double, avg: Double, max: Double, jitter: Double
    }

    var stats: Stats? {
        guard pings.count >= 2 else { return nil }
        let sorted = pings.sorted()
        let avg = sorted.reduce(0, +) / Double(sorted.count)
        var jitterSum = 0.0
        for i in 1..<pings.count {
            jitterSum += abs(pings[i] - pings[i - 1])
        }
        return Stats(min: sorted.first!, avg: avg, max: sorted.last!, jitter: jitterSum / Double(pings.count - 1))
    }

    var lossPercent: Double {
        sent == 0 ? 0 : (Double(lost) / Double(sent)) * 100
    }

    func start() {
        stop()
        sent = 0
        lost = 0
        pings.removeAll()
        let newPinger = SimplePinger()
        newPinger.onReply = { [weak self] rtt in
            DispatchQueue.main.async {
                guard let self = self, self.isRunning else { return }
                self.sent += 1
                if let rtt = rtt {
                    self.pings.append(rtt * 1000)
                    if self.pings.count > 200 { self.pings.removeFirst(self.pings.count - 200) }
                } else {
                    self.lost += 1
                }
            }
        }
        newPinger.onError = { [weak self] message in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.timer?.invalidate()
                self.timer = nil
                self.pinger = nil
                self.isRunning = false
                self.statusText = message
            }
        }
        pinger = newPinger
        newPinger.start(host: host)
        isRunning = true
        statusText = "Medindo \(host)…"
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pinger?.sendProbe()
        }
        // Primeiro disparo após abrir o socket (sendProbe é thread-safe).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.pinger?.sendProbe()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pinger?.stop()
        pinger = nil
        isRunning = false
        statusText = "Parado"
    }
}

/// Ping ICMP via socket DGRAM (SOCK_DGRAM + IPPROTO_ICMP) — o modo
/// "ping sem privilégio" que o iOS permite, sem precisar de entitlements.
final class SimplePinger {
    private let queue = DispatchQueue(label: "touchboost.pinger")
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var destAddr = sockaddr_in()
    private var identifier: UInt16 = UInt16.random(in: 1...UInt16.max)
    private var sequence: UInt16 = 0
    /// Sequências enviadas e ainda sem resposta: seq -> data de envio.
    private var pending: [UInt16: Date] = [:]
    var onReply: ((Double?) -> Void)?
    var onError: ((String) -> Void)?

    func start(host: String) {
        queue.async { [weak self] in
            self?.openSocketAndResolve(host: host)
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.closeSocket()
        }
    }

    private func openSocketAndResolve(host: String) {
        closeSocket()

        // Resolve o host (IP direto ou domínio) para IPv4.
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_ICMP
        var results: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &results) == 0, let first = results else {
            DispatchQueue.main.async { self.onError?("Não consegui resolver o host \(host)") }
            return
        }
        defer { freeaddrinfo(results) }
        memset(&destAddr, 0, MemoryLayout<sockaddr_in>.size)
        memcpy(&destAddr, first.pointee.ai_addr, min(Int(first.pointee.ai_addrlen), MemoryLayout<sockaddr_in>.size))

        socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard socketFD >= 0 else {
            DispatchQueue.main.async { self.onError?("Falha ao abrir socket ICMP (errno \(errno))") }
            return
        }

        var addr = destAddr
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        let connectOK = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectOK == 0 else {
            close(socketFD)
            socketFD = -1
            DispatchQueue.main.async { self.onError?("Falha ao conectar (errno \(errno))") }
            return
        }

        // Fonte de leitura: dispara sempre que há pacote para receber.
        let source = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.readReply()
        }
        source.setCancelHandler { [weak self] in
            guard let self = self, self.socketFD >= 0 else { return }
            close(self.socketFD)
            self.socketFD = -1
        }
        source.resume()
        readSource = source
    }

    private func closeSocket() {
        readSource?.cancel()
        readSource = nil
        pending.removeAll()
        // O fd é fechado no cancelHandler da fonte de leitura.
    }

    func sendProbe() {
        queue.async { [weak self] in
            guard let self = self, self.socketFD >= 0 else { return }
            self.sequence &+= 1
            let seq = self.sequence
            let packet = ICMPHeader.buildEchoRequest(identifier: self.identifier, sequence: seq)
            var bytes = [UInt8](packet)
            let sent = bytes.withUnsafeMutableBufferPointer { buf in
                send(self.socketFD, buf.baseAddress, buf.count, 0)
            }
            guard sent > 0 else {
                DispatchQueue.main.async { self.onReply?(nil) }
                return
            }
            self.pending[seq] = Date()
            // Timeout de 3 s: sem resposta conta como perda.
            self.queue.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                if self.pending.removeValue(forKey: seq) != nil {
                    DispatchQueue.main.async { self.onReply?(nil) }
                }
            }
        }
    }

    private func readReply() {
        var buffer = [UInt8](repeating: 0, count: 2048)
        var fromAddr = sockaddr()
        var fromLen = socklen_t(MemoryLayout<sockaddr>.size)
        let n = recvfrom(socketFD, &buffer, buffer.count, 0, &fromAddr, &fromLen)
        guard n >= 8 else { return }
        let bytes = Array(buffer[0..<n])
        // Socket ICMP datagram entrega o pacote sem cabeçalho IP.
        guard bytes[0] == 0 else { return } // Echo Reply
        let recvID = (UInt16(bytes[4]) << 8) | UInt16(bytes[5])
        let recvSeq = (UInt16(bytes[6]) << 8) | UInt16(bytes[7])
        guard recvID == identifier, let startTime = pending.removeValue(forKey: recvSeq) else { return }
        let rtt = Date().timeIntervalSince(startTime)
        DispatchQueue.main.async { self.onReply?(rtt) }
    }
}

enum ICMPHeader {
    /// Monta um pacote ICMP Echo Request válido.
    static func buildEchoRequest(identifier: UInt16, sequence: UInt16) -> Data {
        var packet = Data(count: 64) // 8 header + 56 payload
        packet[0] = 8 // Echo Request
        packet[1] = 0
        packet.replaceSubrange(4..<6, with: withUnsafeBytes(of: identifier.bigEndian) { Data($0) })
        packet.replaceSubrange(6..<8, with: withUnsafeBytes(of: sequence.bigEndian) { Data($0) })
        packet.replaceSubrange(8..<64, with: (0..<56).map { UInt8($0 & 0xFF) })
        let checksum = computeChecksum(packet)
        packet.replaceSubrange(2..<4, with: withUnsafeBytes(of: checksum.bigEndian) { Data($0) })
        return packet
    }

    static func computeChecksum(_ data: Data) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        let bytes = [UInt8](data)
        while i < bytes.count - 1 {
            sum &+= (UInt32(bytes[i]) << 8) | UInt32(bytes[i + 1])
            i += 2
        }
        if bytes.count % 2 == 1 {
            sum &+= UInt32(bytes[bytes.count - 1]) << 8
        }
        while (sum >> 16) != 0 {
            sum = (sum & 0xFFFF) &+ (sum >> 16)
        }
        return UInt16(~sum & 0xFFFF)
    }

    static func isValidEchoReply(_ data: Data, identifier: UInt16) -> Bool {
        guard data.count >= 8, data[0] == 0 else { return false }
        let recvID = (UInt16(data[4]) << 8) | UInt16(data[5])
        return recvID == identifier
    }
}

struct NetworkTestView: View {
    @StateObject private var model = NetworkTestModel()

    var body: some View {
        TBScreen {
            TBHero(
                title: "TESTE DE REDE",
                subtitle: model.isRunning ? "Medindo \(model.host)…" : "Ping, jitter e perda de pacotes",
                systemImage: "wifi",
                stat1: model.stats.map { s in (String(format: "%.0f", s.avg), "Média ms") } ?? ("—", "Média ms"),
                stat2: model.stats.map { s in (String(format: "%.0f", s.jitter), "Jitter ms") } ?? ("—", "Jitter ms"),
                stat3: (String(format: "%.0f", model.lossPercent), "Perda %")
            )

            TBSectionHeader(title: "Alvo")

            TBCard {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .foregroundColor(TBTheme.accent)
                        TextField("IP ou domínio (ex.: 1.1.1.1)", text: $model.host)
                            .keyboardType(.asciiCapable)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))

                    if model.isRunning {
                        Button {
                            model.stop()
                        } label: {
                            Label("Parar medição", systemImage: "stop.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        TBPrimaryButton(title: "INICIAR MEDIÇÃO", systemImage: "play.fill") {
                            model.start()
                        }
                    }

                    Text("Dica: meça até 1.1.1.1 para testar a internet e até o IP do seu roteador para testar o Wi-Fi.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let s = model.stats {
                TBSectionHeader(title: "Estatísticas")

                TBCard {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            netStat("Mínimo", s.min)
                            netStat("Média", s.avg)
                            netStat("Máximo", s.max)
                        }
                        HStack(spacing: 10) {
                            netStat("Jitter", s.jitter)
                            netStat("Perda", model.lossPercent, suffix: "%")
                            netStat("Enviados", Double(model.sent), suffix: "", decimals: 0)
                        }
                    }
                }
            }

            if !model.pings.isEmpty {
                TBSectionHeader(title: "Últimos Pings")

                TBCard {
                    VStack(spacing: 8) {
                        sparkline(model.pings.suffix(60))
                        ForEach(Array(model.pings.suffix(5).enumerated().reversed()), id: \.offset) { _, value in
                            HStack {
                                Circle()
                                    .fill(value < 30 ? TBTheme.accent : (value < 80 ? Color.yellow : Color.red))
                                    .frame(width: 7, height: 7)
                                Spacer()
                                Text(String(format: "%.1f ms", value))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }

            Text(model.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func netStat(_ label: String, _ value: Double, suffix: String = " ms", decimals: Int = 0) -> some View {
        let fmt = "." + String(decimals) + "f"
        return VStack(spacing: 3) {
            Text(String(format: "%" + fmt, value) + suffix)
                .font(.system(.headline, design: .rounded).bold())
                .foregroundColor(value < 30 || label == "Enviados" ? TBTheme.accent : (value < 80 ? .yellow : .red))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private func sparkline(_ values: ArraySlice<Double>) -> some View {
        let vals = Array(values)
        let maxV = max(vals.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(vals.enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 1)
                    .fill(v < 30 ? TBTheme.accent : (v < 80 ? Color.yellow : Color.red))
                    .frame(height: max(3, CGFloat(v / maxV) * 44))
            }
        }
        .frame(height: 46, alignment: .bottom)
        .frame(maxWidth: .infinity)
    }
}
