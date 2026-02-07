import SwiftUI

// MARK: - License Certificate Icon

struct LicenseCertificateIcon: View {
    let isActivated: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            // Certificate body
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .fill(Color(white: 0.15))
                .frame(width: size, height: size * 0.78)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            // Top accent stripe
            VStack(spacing: 0) {
                UnevenRoundedRectangle(
                    topLeadingRadius: size * 0.14,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: size * 0.14
                )
                .fill(isActivated ? Color.green.opacity(0.6) : Color.orange.opacity(0.6))
                .frame(height: 3)

                Spacer()
            }
            .frame(width: size, height: size * 0.78)

            // Text lines
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: size * 0.55, height: 2)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: size * 0.40, height: 2)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: size * 0.48, height: 2)
            }
            .offset(y: 1)

            // Seal badge
            Image(systemName: isActivated ? "checkmark.seal.fill" : "seal.fill")
                .font(.system(size: size * 0.24, weight: .semibold))
                .foregroundStyle(isActivated ? .green.opacity(0.55) : .orange.opacity(0.4))
                .offset(x: size * 0.18, y: size * 0.16)
        }
        .frame(width: size, height: size * 0.78)
    }
}

// MARK: - License Card (unified for both states)

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
        HStack(spacing: 14) {
            // Left: text info
            VStack(alignment: .leading, spacing: 4) {
                Text("Licensed to:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(nonEmpty(email) ?? "Not provided")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let keyHint = nonEmpty(keyHint) {
                    Text("Key: \(keyHint)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if let verifiedAt {
                    Text("Verified \(verifiedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            // Right: certificate icon
            LicenseCertificateIcon(isActivated: true, size: 72)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Live Preview Card (pre-activation, same layout)

struct LicenseLivePreviewCard: View {
    let email: String
    let keyDisplay: String
    let isActivated: Bool
    var accentColor: Color = .blue
    var enableInteractiveEffects: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            // Left: text info
            VStack(alignment: .leading, spacing: 4) {
                Text("License key:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(keyDisplay)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let email = nonEmpty(email) {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)

            // Right: certificate icon
            LicenseCertificateIcon(isActivated: isActivated, size: 72)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
