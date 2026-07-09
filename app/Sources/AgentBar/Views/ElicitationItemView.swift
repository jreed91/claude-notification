import SwiftUI

/// Renders one MCP elicitation request: the server's message plus a form for the
/// requested fields (text / number / toggle / picker). "Send" accepts the elicitation
/// with the collected values; Decline and Cancel return those MCP actions; "Answer in
/// terminal" falls back via passthrough. When no fields could be parsed from the
/// request schema, only the non-form actions are offered.
struct ElicitationItemView: View {
    @ObservedObject var item: PendingItem
    let request: ElicitationRequest
    let queue: QueueStore

    @State private var text: [String: String] = [:]
    @State private var bools: [String: Bool] = [:]
    @State private var choices: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let server = request.serverName, !server.isEmpty {
                Text(server)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(request.message)
                .font(.subheadline.weight(.medium))

            ForEach(request.fields) { field in
                fieldView(field)
            }

            HStack {
                if !request.fields.isEmpty {
                    Button("Send") { submit() }
                        .buttonStyle(.borderedProminent)
                }
                Button("Decline") { queue.declineElicitation(item: item) }
                Button("Cancel") { queue.cancelElicitation(item: item) }
                Spacer()
                Button("Answer in terminal") { queue.passthrough(item: item) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func fieldView(_ field: ElicitationField) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(field.required ? "\(field.title) *" : field.title)
                .font(.caption.weight(.medium))
            if let description = field.description, !description.isEmpty {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            switch field.kind {
            case .boolean:
                Toggle(isOn: boolBinding(field.key)) { EmptyView() }
                    .labelsHidden()
            case .choice:
                Picker("", selection: choiceBinding(field.key)) {
                    ForEach(field.choices, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            case .text, .number, .integer:
                TextField(field.kind == .text ? "" : "Number", text: textBinding(field.key))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Bindings

    private func textBinding(_ key: String) -> Binding<String> {
        Binding(get: { text[key] ?? "" }, set: { text[key] = $0 })
    }

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { bools[key] ?? false }, set: { bools[key] = $0 })
    }

    private func choiceBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { choices[key] ?? defaultChoice(for: key) },
            set: { choices[key] = $0 }
        )
    }

    private func defaultChoice(for key: String) -> String {
        request.fields.first { $0.key == key }?.choices.first ?? ""
    }

    // MARK: - Submission

    private func submit() {
        var content: [String: Any] = [:]
        for field in request.fields {
            switch field.kind {
            case .boolean:
                content[field.key] = bools[field.key] ?? false
            case .choice:
                let value = choices[field.key] ?? field.choices.first ?? ""
                if !value.isEmpty { content[field.key] = value }
            case .integer:
                let raw = (text[field.key] ?? "").trimmingCharacters(in: .whitespaces)
                if let value = Int(raw) { content[field.key] = value }
            case .number:
                let raw = (text[field.key] ?? "").trimmingCharacters(in: .whitespaces)
                if let value = Double(raw) { content[field.key] = value }
            case .text:
                let value = text[field.key] ?? ""
                if !value.isEmpty { content[field.key] = value }
            }
        }
        queue.submitElicitation(item: item, content: content)
    }
}
