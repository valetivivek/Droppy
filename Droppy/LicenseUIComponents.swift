import SwiftUI

// MARK: - License Card (unified full-width design)

struct LicenseIdentityCard: View {
    let title: String
    let subtitle: String
    let email: String
    let keyHint: String?
    let verifiedAt: Date?
    var accentColor: Color = .blue
    let footer: AnyView?
    var enableInteractiveEffects: Bool

    init(
        title: String,
        subtitle: String,
        email: String,
        keyHint: String?,
        verifiedAt: Date?,
        accentColor: Color = .blue,
        footer: AnyView? = nil,
        enableInteractiveEffects: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.email = email
        self.keyHint = keyHint
        self.verifiedAt = verifiedAt
        self.accentColor = accentColor
        self.footer = footer
        self.enableInteractiveEffects = enableInteractiveEffects
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent bar
            Rectangle()
                .fill(Color.green)
                .frame(height: 3)

            // Card content
            VStack(alignment: .leading, spacing: 14) {
                // Header row
                HStack(alignment: .center) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                // Info grid
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(label: "Email", value: nonEmpty(email) ?? "Not provided")

                    if let keyHint = nonEmpty(keyHint) {
                        infoRow(label: "Key", value: keyHint, mono: true)
                    }

                    if let verifiedAt {
                        infoRow(
                            label: "Verified",
                            value: verifiedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: mono ? .monospaced : .default))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Live Preview Card (same look, updates in real-time during activation)

struct LicenseLivePreviewCard: View {
    let email: String
    let keyDisplay: String
    let isActivated: Bool
    var accentColor: Color = .blue
    var enableInteractiveEffects: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent bar
            Rectangle()
                .fill(isActivated ? Color.green : Color.orange)
                .frame(height: 3)

            // Card content
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(alignment: .center) {
                    Image(systemName: isActivated ? "checkmark.seal.fill" : "key.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isActivated ? .green : .orange)

                    Text("Droppy License")
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Text(isActivated ? "Active" : "Pending")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isActivated ? .green : .orange)
                }

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(label: "Key", value: keyDisplay, mono: true)

                    if let email = nonEmpty(email) {
                        infoRow(label: "Email", value: email)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func infoRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: mono ? .monospaced : .default))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
