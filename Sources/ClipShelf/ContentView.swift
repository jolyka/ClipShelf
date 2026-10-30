import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var settings: AppSettings
    @State private var showingSettings = false
    @State private var showingClearConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.55)

                if store.items.isEmpty {
                    emptyState
                } else {
                    historyGrid
                }

                Divider().opacity(0.55)
                footer
            }
        }
        .frame(width: 440, height: 610)
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
        }
        .confirmationDialog(
            "Очистить всю историю?",
            isPresented: $showingClearConfirmation
        ) {
            Button("Очистить", role: .destructive) { store.clearAll() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сохранённые в ClipShelf изображения будут удалены без возможности восстановления.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.39, green: 0.28, blue: 0.98), Color(red: 0.16, green: 0.64, blue: 0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClipShelf")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(itemCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(.quaternary, in: Circle())
            .help("Настройки")

            Button {
                showingClearConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(.quaternary, in: Circle())
            .help("Очистить историю")
            .disabled(store.items.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var historyGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.items) { item in
                    ClipboardCard(
                        item: item,
                        image: store.image(for: item),
                        copyAction: { store.copy(item) },
                        deleteAction: { store.delete(item) }
                    )
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.18), Color.purple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 7) {
                Text("История пока пуста")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                Text("Скопируйте текст или сделайте обычный скриншот —\nзапись автоматически появится здесь.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            HStack(spacing: 6) {
                Keycap("⇧")
                Keycap("⌘")
                Keycap("4")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var footer: some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
            Text(store.lastAction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text("Показать")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(settings.showShortcut.title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    private var itemCountText: String {
        let count = store.items.count
        if count == 0 { return "Текст и изображения" }
        if count == 1 { return "1 запись" }
        if (2...4).contains(count) { return "\(count) записи" }
        return "\(count) записей"
    }
}

private struct ClipboardCard: View {
    let item: ClipboardItem
    let image: NSImage?
    let copyAction: () -> Void
    let deleteAction: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if item.kind == .text {
                    textPreview
                } else if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 128)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 128)
                        .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
                }

                if isHovering {
                    HStack(spacing: 6) {
                        compactButton(icon: "doc.on.doc", help: "Скопировать", action: copyAction)
                        compactButton(icon: "trash", help: "Удалить", action: deleteAction)
                    }
                    .padding(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.createdAt, style: .relative)
                        .font(.system(size: 12, weight: .medium))
                    Text(metadataText)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(isHovering ? 0.22 : 0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.16 : 0.08), radius: isHovering ? 12 : 6, y: 3)
        .scaleEffect(isHovering ? 1.015 : 1)
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onTapGesture(perform: copyAction)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: "Скопировать", copyAction)
    }

    private var textPreview: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.22), Color.blue.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(item.text ?? "")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(6)
                .lineSpacing(3)
                .padding(12)
        }
        .frame(height: 128)
        .clipped()
    }

    private var metadataText: String {
        if item.kind == .text {
            return "Текст · \(formattedSize)"
        }
        return "\(item.pixelWidth ?? 0) × \(item.pixelHeight ?? 0) · \(formattedSize)"
    }

    private var accessibilityText: String {
        switch item.kind {
        case .image:
            return "Изображение \(item.pixelWidth ?? 0) на \(item.pixelHeight ?? 0), \(item.createdAt.formatted())"
        case .text:
            return "Текст: \(item.text ?? ""), \(item.createdAt.formatted())"
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(item.byteCount), countStyle: .file)
    }

    private func compactButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 27, height: 27)
                .background(.ultraThickMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct Keycap: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .frame(minWidth: 25, minHeight: 25)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Горячие клавиши")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Выберите сочетания, которые удобнее использовать.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                GridRow {
                    Text("Показать историю")
                    Picker("", selection: $settings.showShortcutID) {
                        ForEach(AppSettings.showPresets) { preset in
                            Text(preset.title).tag(preset.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                GridRow {
                    Text("Очистить историю")
                    Picker("", selection: $settings.clearShortcutID) {
                        ForEach(AppSettings.clearPresets) { preset in
                            Text(preset.title).tag(preset.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }

            Label(
                "ClipShelf хранит до 30 записей только на этом Mac.",
                systemImage: "lock.shield"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Label(
                "Обычные снимки ⇧⌘4 сразу добавляются в историю и буфер без системной миниатюры.",
                systemImage: "rectangle.on.rectangle.badge.plus"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 410)
    }
}
