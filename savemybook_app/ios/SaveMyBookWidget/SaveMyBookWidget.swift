import Foundation
import SwiftUI
import WidgetKit

private let appGroupId = "group.today.savemybook.app"

struct SummaryEntry: TimelineEntry {
    let date: Date
    let signedIn: Bool
    let pickupCount: Int
    let depositCount: Int
    let unreadCount: Int
    let coins: String
    let pickupCode: String
    let pickupCabinet: String
    let updatedAt: String
    let language: String

    static var placeholder: SummaryEntry {
        SummaryEntry(
            date: Date(),
            signedIn: true,
            pickupCount: 1,
            depositCount: 0,
            unreadCount: 2,
            coins: "120",
            pickupCode: "123456",
            pickupCabinet: "",
            updatedAt: "",
            language: WidgetText.systemLanguage()
        )
    }

    static func load() -> SummaryEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        func value(_ key: String) -> String {
            if let raw = defaults?.object(forKey: key) {
                return "\(raw)"
            }
            return ""
        }
        let storedLanguage = value("smb_lang")
        let coins = value("smb_coins")
        return SummaryEntry(
            date: Date(),
            signedIn: value("smb_signed_in") == "1",
            pickupCount: Int(value("smb_pickup_count")) ?? 0,
            depositCount: Int(value("smb_deposit_count")) ?? 0,
            unreadCount: Int(value("smb_unread_chat")) ?? 0,
            coins: coins.isEmpty ? "0" : coins,
            pickupCode: value("smb_pickup_code"),
            pickupCabinet: value("smb_pickup_cabinet"),
            updatedAt: value("smb_updated_at"),
            language: storedLanguage.isEmpty ? WidgetText.systemLanguage() : storedLanguage
        )
    }
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        let entry = SummaryEntry.load()
        completion(context.isPreview && !entry.signedIn ? SummaryEntry.placeholder : entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        completion(Timeline(entries: [SummaryEntry.load()], policy: .never))
    }
}

enum WidgetText {
    static func systemLanguage() -> String {
        let preferred = (Locale.preferredLanguages.first ?? "").lowercased()
        if preferred.hasPrefix("zh") {
            if preferred.contains("hans") || preferred.hasSuffix("-cn") || preferred.hasSuffix("-sg") {
                return "zh_Hans"
            }
            return "zh_Hant"
        }
        for code in ["en", "ja", "ko"] where preferred.hasPrefix(code) {
            return code
        }
        return "zh_Hant"
    }

    static func get(_ key: String, _ language: String) -> String {
        table[language]?[key] ?? table["zh_Hant"]?[key] ?? key
    }

    private static let table: [String: [String: String]] = [
        "zh_Hant": [
            "appName": "救舊我的書",
            "widgetName": "取書與訊息",
            "widgetDescription": "取書碼、待存書、未讀訊息與代幣一目瞭然",
            "signedOut": "登入以查看",
            "pickup": "待取書",
            "deposit": "待存書",
            "unread": "未讀訊息",
            "coins": "代幣",
            "updated": "更新於 {t}",
            "pickupCode": "取書碼 {t}",
            "noPickup": "目前沒有待取書籍",
        ],
        "en": [
            "appName": "救舊我的書",
            "widgetName": "Pickups & messages",
            "widgetDescription": "Pickup codes, drop-offs, unread messages and coins at a glance",
            "signedOut": "Sign in to view",
            "pickup": "Pickup",
            "deposit": "Drop-off",
            "unread": "Unread",
            "coins": "Coins",
            "updated": "Updated {t}",
            "pickupCode": "Pickup code {t}",
            "noPickup": "No books waiting for pickup",
        ],
        "ja": [
            "appName": "救舊我的書",
            "widgetName": "受け取りとメッセージ",
            "widgetDescription": "受け取りコード・預け入れ・未読メッセージ・コインをひと目で確認",
            "signedOut": "ログインして表示",
            "pickup": "受取待ち",
            "deposit": "預入待ち",
            "unread": "未読",
            "coins": "コイン",
            "updated": "{t} 更新",
            "pickupCode": "受け取りコード {t}",
            "noPickup": "受け取り待ちの本はありません",
        ],
        "ko": [
            "appName": "救舊我的書",
            "widgetName": "수령 및 메시지",
            "widgetDescription": "수령 코드, 보관 대기, 읽지 않은 메시지와 코인을 한눈에",
            "signedOut": "로그인하여 보기",
            "pickup": "수령 대기",
            "deposit": "보관 대기",
            "unread": "안 읽음",
            "coins": "코인",
            "updated": "{t} 업데이트",
            "pickupCode": "수령 코드 {t}",
            "noPickup": "수령 대기 중인 책이 없습니다",
        ],
        "zh_Hans": [
            "appName": "救舊我的書",
            "widgetName": "取书与消息",
            "widgetDescription": "取书码、待存书、未读消息与代币一目了然",
            "signedOut": "登录以查看",
            "pickup": "待取书",
            "deposit": "待存书",
            "unread": "未读消息",
            "coins": "代币",
            "updated": "更新于 {t}",
            "pickupCode": "取书码 {t}",
            "noPickup": "目前没有待取书籍",
        ],
    ]
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(red: red / 255, green: green / 255, blue: blue / 255)
}

struct WidgetPalette {
    let background: Color
    let tile: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color

    init(dark: Bool) {
        background = dark ? rgb(30, 30, 30) : Color.white
        tile = dark ? rgb(42, 42, 42) : rgb(243, 245, 247)
        primaryText = dark ? rgb(232, 232, 232) : rgb(21, 30, 39)
        secondaryText = dark ? rgb(158, 158, 158) : Color.black.opacity(0.54)
        accent = dark ? rgb(143, 169, 184) : rgb(98, 125, 141)
    }
}

extension View {
    @ViewBuilder
    func summaryWidgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            self.containerBackground(for: .widget) { color }
        } else {
            self.padding(14).background(color)
        }
    }
}

struct SummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    let entry: SummaryEntry

    private var palette: WidgetPalette {
        WidgetPalette(dark: colorScheme == .dark)
    }

    private func text(_ key: String) -> String {
        WidgetText.get(key, entry.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.signedIn {
                if family == .systemSmall {
                    smallGrid
                } else {
                    mediumContent
                }
            } else {
                Spacer(minLength: 0)
                Text(text("signedOut"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .summaryWidgetBackground(palette.background)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(text("appName"))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(palette.accent)
                .lineLimit(1)
            Spacer(minLength: 4)
            if entry.signedIn && !entry.updatedAt.isEmpty && family != .systemSmall {
                Text(text("updated").replacingOccurrences(of: "{t}", with: entry.updatedAt))
                    .font(.system(size: 11))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private var smallGrid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                tile(value: "\(entry.pickupCount)", label: text("pickup"), highlight: entry.pickupCount > 0)
                tile(value: "\(entry.depositCount)", label: text("deposit"), highlight: entry.depositCount > 0)
            }
            HStack(spacing: 6) {
                tile(value: "\(entry.unreadCount)", label: text("unread"), highlight: entry.unreadCount > 0)
                tile(value: entry.coins, label: text("coins"), highlight: false)
            }
        }
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                tile(value: "\(entry.pickupCount)", label: text("pickup"), highlight: entry.pickupCount > 0)
                tile(value: "\(entry.depositCount)", label: text("deposit"), highlight: entry.depositCount > 0)
                tile(value: "\(entry.unreadCount)", label: text("unread"), highlight: entry.unreadCount > 0)
                tile(value: entry.coins, label: text("coins"), highlight: false)
            }
            HStack(spacing: 5) {
                Image(systemName: entry.pickupCount > 0 && !entry.pickupCode.isEmpty ? "key.fill" : "books.vertical")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(palette.accent)
                Text(pickupDetail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(1)
            }
        }
    }

    private var pickupDetail: String {
        if entry.pickupCount == 0 {
            return text("noPickup")
        }
        var parts: [String] = []
        if !entry.pickupCode.isEmpty {
            parts.append(text("pickupCode").replacingOccurrences(of: "{t}", with: entry.pickupCode))
        }
        if !entry.pickupCabinet.isEmpty {
            parts.append(entry.pickupCabinet)
        }
        return parts.isEmpty ? text("pickup") : parts.joined(separator: " · ")
    }

    private func tile(value: String, label: String, highlight: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(highlight ? palette.accent : palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.tile))
    }
}

struct SaveMyBookSummaryWidget: Widget {
    let kind: String = "SaveMyBookSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetText.get("widgetName", WidgetText.systemLanguage()))
        .description(WidgetText.get("widgetDescription", WidgetText.systemLanguage()))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SaveMyBookWidgetBundle: WidgetBundle {
    var body: some Widget {
        SaveMyBookSummaryWidget()
    }
}
