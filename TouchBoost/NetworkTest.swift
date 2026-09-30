import SwiftUI
import Network

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
        pinger = SimplePinger(host: host)
        pinger?.onReply = { [weak self] rtt in
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
        pinger?.start()
        isRunning = true
        statusText = "Medindo \(host)…"
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pinger?.sendProbe()
        }
        pinger?.sendProbe()
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

/// Ping ICMP via Network.framework (iOS 13+).
final class SimplePinger {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "touchboost.pinger")
    private var identifier: UInt16 = UInt16.random(in: 0...UInt16.max)
    private var sequence: UInt16 = 0
    var onReply: ((Double?) -> Void)?

    init(host: String) {
        let params = NWParameters()
        params.protocolStack = .icmp
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: .any,
            using: params
        )
    }

    func start() {
        connection.stateUpdateHandler = { _ in }
        connection.start(queue: queue)
    }

    func stop() {
        connection.cancel()
    }

    func sendProbe() {
        sequence &+= 1
        let packet = ICMPHeader.buildEchoRequest(identifier: identifier, sequence: sequence)
        let startTime = Date()
        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            guard let self = self else { return }
            if error != nil {
                DispatchQueue.main.async { self.onReply?(nil) }
                return
            }
            self.receiveReply(startTime: startTime)
        })
    }

    private func receiveReply(startTime: Date) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self = self else { return }
            guard error == nil, let data = data else {
                DispatchQueue.main.async { self.onReply?(nil) }
                return
            }
            // Dependendo da plataforma o pacote vem com o cabeçalho IP (20 bytes) antes do ICMP.
            var bytes = [UInt8](data)
            if bytes.first == 0x45, bytes.count > 20 {
                bytes = Array(bytes.dropFirst(20))
            }
            let recvID = bytes.count >= 8 ? ((UInt16(bytes[4]) << 8) | UInt16(bytes[5])) : 0
            if bytes.count >= 8, bytes[0] == 0, recvID == self.identifier {
                let rtt = Date().timeIntervalSince(startTime)
                DispatchQueue.main.async { self.onReply?(rtt) }
            } else {
                DispatchQueue.main.async { self.onReply?(nil) }
            }
        }
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
        NavigationView {
            Form {
                Section {
                    TextField("Host (IP ou domínio)", text: $model.host)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if model.isRunning {
                        Button(role: .destructive) {
                            model.stop()
                        } label: {
                            Label("Parar medição", systemImage: "stop.fill")
                        }
                    } else {
                        Button {
                            model.start()
                        } label: {
                            Label("Iniciar medição", systemImage: "play.fill")
                        }
                    }
                } header: {
                    Text("Alvo")
                } footer: {
                    Text("1.1.1.1 (Cloudflare) é um bom padrão para medir até a internet. Use o IP do seu roteador (ex.: 192.168.0.1) para medir até ele — se essa latência estiver alta, o problema é Wi-Fi, não a operadora.")
                }

                if let s = model.stats {
                    Section("Estatísticas") {
                        statRow("Mínimo", s.min)
                        statRow("Média", s.avg)
                        statRow("Máximo", s.max)
                        statRow("Jitter", s.jitter)
                        HStack {
                            Text("Perda de pacotes")
                            Spacer()
                            Text(String(format: "%.1f%% (%d/%d)", model.lossPercent, model.lost, model.sent))
                                .foregroundColor(model.lossPercent > 3 ? .red : .green)
                                .monospacedDigit()
                        }
                    }
                } else {
                    Section("Estatísticas") {
                        Text("\(model.sent) pacotes enviados, \(model.lost) perdidos")
                            .foregroundColor(.secondary)
                    }
                }

                if !model.pings.isEmpty {
                    Section("Últimos pings") {
                        ForEach(Array(model.pings.suffix(10).enumerated().reversed()), id: \.offset) { _, value in
                            HStack {
                                Circle()
                                    .fill(value < 30 ? Color.green : (value < 80 ? Color.yellow : Color.red))
                                    .frame(width: 8, height: 8)
                                Spacer()
                                Text(String(format: "%.1f ms", value))
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    Text(model.statusText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Teste de Rede")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private func statRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.1f ms", value))
                .monospacedDigit()
                .foregroundColor(value < 30 ? .green : (value < 80 ? .yellow : .red))
        }
    }
}
