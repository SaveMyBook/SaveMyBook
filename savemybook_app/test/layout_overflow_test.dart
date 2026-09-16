import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/support.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/features/account/account_privacy_screen.dart';
import 'package:savemybook_app/features/account/app_permissions_screen.dart';
import 'package:savemybook_app/features/account/ai_consent_sheet.dart';
import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/admin/ai/admin_ai_screen.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/models/category.dart';
import 'package:savemybook_app/features/admin/admin_announcement_screen.dart';
import 'package:savemybook_app/features/admin/admin_backup_screen.dart';
import 'package:savemybook_app/features/admin/admin_book_screen.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_screen.dart';
import 'package:savemybook_app/features/admin/admin_category_screen.dart';
import 'package:savemybook_app/features/admin/admin_deletion_screen.dart';
import 'package:savemybook_app/features/admin/admin_dispute_screen.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/features/admin/admin_level_screen.dart';
import 'package:savemybook_app/features/admin/admin_maintenance_log_screen.dart';
import 'package:savemybook_app/features/admin/admin_member_detail_screen.dart';
import 'package:savemybook_app/features/admin/admin_member_screen.dart';
import 'package:savemybook_app/features/admin/admin_operation_log_screen.dart';
import 'package:savemybook_app/features/admin/admin_order_detail_screen.dart';
import 'package:savemybook_app/features/admin/admin_order_screen.dart';
import 'package:savemybook_app/features/admin/admin_report_screen.dart';
import 'package:savemybook_app/features/admin/admin_stats_screen.dart';
import 'package:savemybook_app/features/admin/admin_ticket_screen.dart';
import 'package:savemybook_app/features/admin/admin_wallet_screen.dart';
import 'package:savemybook_app/features/home/announcement_screen.dart';
import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/books/image_crop_screen.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/features/orders/cart_screen.dart';
import 'package:savemybook_app/features/account/change_password_screen.dart';
import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/chat_list_screen.dart';
import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/features/chat/groups/create_group_screen.dart';
import 'package:savemybook_app/features/chat/settings/chat_room_settings_screen.dart';
import 'package:savemybook_app/features/chat/media/chat_album.dart';
import 'package:savemybook_app/features/chat/mentions/chat_mention_controller.dart';
import 'package:savemybook_app/features/chat/transfer/transfer_card.dart';
import 'package:savemybook_app/features/chat/widgets/chat_entry.dart';
import 'package:savemybook_app/features/chat/widgets/chat_input_bar.dart';
import 'package:savemybook_app/widgets/image_viewer.dart';
import 'package:savemybook_app/widgets/buyer/book_strip.dart';
import 'package:savemybook_app/models/chat.dart';
import 'package:savemybook_app/features/orders/dispute_screen.dart';
import 'package:savemybook_app/features/account/edit_profile_screen.dart';
import 'package:savemybook_app/features/books/favorites_screen.dart';
import 'package:savemybook_app/features/account/help_center_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/auth/legal_consent_screen.dart';
import 'package:savemybook_app/features/account/legal_doc_screen.dart';
import 'package:savemybook_app/features/auth/login_screen.dart';
import 'package:savemybook_app/features/auth/phone_sign_in_screen.dart';
import 'package:savemybook_app/features/auth/social_profile_screen.dart';
import 'package:savemybook_app/features/admin/admin_auth_screen.dart';
import 'package:savemybook_app/features/security/set_password_screen.dart';
import 'package:savemybook_app/features/security/sign_in_methods_card.dart';
import 'package:savemybook_app/models/auth_social.dart';
import 'package:savemybook_app/services/social_auth_service.dart';
import 'package:savemybook_app/features/account/member_level_screen.dart';
import 'package:savemybook_app/features/home/notification_screen.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/selling/pending_income_screen.dart';
import 'package:savemybook_app/features/account/profile_screen.dart';
import 'package:savemybook_app/features/orders/purchase_history_screen.dart';
import 'package:savemybook_app/features/auth/register_screen.dart';
import 'package:savemybook_app/features/selling/sales_history_screen.dart';
import 'package:savemybook_app/features/security/login_devices_screen.dart';
import 'package:savemybook_app/features/security/security_center_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_screen.dart';
import 'package:savemybook_app/features/account/settings_screen.dart';
import 'package:savemybook_app/features/account/share_profile_screen.dart';
import 'package:savemybook_app/features/account/support_ticket_screen.dart';
import 'package:savemybook_app/features/account/wallet_screen.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import 'fake_auth_gateway.dart';

const longName = 'Alexandria Montgomery-Wellington';
const longTitle = 'The Extraordinarily Long Title of a Second-hand Book About Everything';
const longCabinet = 'National Taiwan University Main Library Smart Locker';
const now = '2026-09-14T10:30:00.000Z';

Map<String, dynamic> user(int id) => {
      'user_id': id,
      'nickname': longName,
      'email': 'alexandria.montgomery@example.com',
      'avatar_url': null,
      'role': id == 9 ? 'admin' : 'buyer_seller',
      'bio': 'I read everything from classic literature to programming books.',
      'phone': '0912345678',
      'created_at': now,
    };

Map<String, dynamic> cabinet() => {
      'cabinet_id': 3,
      'cabinet_name': longCabinet,
      'address': 'No. 1, Sec. 4, Roosevelt Rd., Da’an Dist., Taipei City 106319',
      'open_time': '1970-01-01T08:00:00.000Z',
      'close_time': '1970-01-01T22:00:00.000Z',
    };

Map<String, dynamic> book(int id, {String status = 'on_sale'}) => {
      'book_id': id,
      'seller_id': 2,
      'title': longTitle,
      'author': 'Johann Wolfgang von Goethe-Schiller',
      'publisher': 'Penguin Random House International Publishing',
      'publish_date': '2020-05',
      'isbn': '9789571234567',
      'category_id': 1,
      'cabinet_id': 3,
      'condition_level': 'like_new',
      'condition_note': 'Slight wear on the cover corners.',
      'price': 123456,
      'quantity': 1,
      'status': status,
      'view_count': 987654,
      'description': 'A long description ' * 10,
      'created_at': now,
      'users': user(2),
      'book_images': <Map<String, dynamic>>[],
      'book_categories': {'category_name': 'Literature & Fiction Classics'},
      'smart_cabinets': cabinet(),
    };

Map<String, dynamic> order(int id, String status) => {
      'order_id': id,
      'order_no': 'SMB20260914103000123456',
      'buyer_id': 1,
      'seller_id': 2,
      'total_amount': 1234567,
      'status': status,
      'pickup_code': '123456',
      'created_at': now,
      'order_items': [
        {'item_id': 1, 'book_id': 5, 'quantity': 1, 'unit_price': 1234567, 'subtotal': 1234567, 'books': book(5)},
      ],
      'smart_cabinets': cabinet(),
      'cabinet_slots': {'slot_id': 1, 'slot_number': 'A12'},
      'users_orders_buyer_idTousers': user(1),
      'users_orders_seller_idTousers': user(2),
      'transaction_disputes': <Map<String, dynamic>>[],
    };

Map<String, dynamic> adminOrder(int id, String status) => {
      'order_id': id,
      'order_no': 'SMB20260914103000123456',
      'status': status,
      'total_amount': 1234567,
      'created_at': now,
      'pickup_code': '123456',
      'buyer': user(1),
      'seller': user(2),
      'cabinet': cabinet(),
      'items': [
        {'book_id': 5, 'title': longTitle, 'unit_price': 1234567, 'subtotal': 1234567, 'quantity': 1, 'image_url': null},
      ],
    };

Map<String, dynamic> chatReservation() => {
      'reservation_id': 8,
      'book': {'book_id': 5, 'title': longTitle, 'price': 123456, 'status': 'on_sale', 'image_url': null},
      'buyer_id': 1,
      'seller_id': 2,
      'status': 'confirmed',
      'hours': 72,
      'message': 'I will pick it up on Saturday afternoon after my morning classes.',
      'pickup_deadline': now,
      'is_holding': true,
      'created_at': now,
    };

Map<String, dynamic> chatMember(int id, {String role = 'member'}) => {
      ...user(id),
      'alias': id == 3 ? 'Study group partner with a long alias' : null,
      'role': role,
      'joined_at': now,
    };

Map<String, dynamic> chatRoomRow(int i) {
  final group = i.isEven;
  return {
    'room_id': i,
    'type': group ? 'group' : 'direct',
    'title': group ? 'Advanced Statistics Study Group for the Autumn Semester' : longName,
    'avatar_url': null,
    'partner': group ? null : {...user(2), 'alias': i == 1 ? longName : null},
    'member_count': group ? 100 : 2,
    'pinned': i <= 2,
    'pinned_at': i <= 2 ? now : null,
    'muted': i == 2,
    'blocked': false,
    'last_message': {'content': 'Is this book still available? I would like to pick it up tomorrow.', 'message_type': 'text', 'kind': i == 2 ? 'voice' : 'text', 'sender_id': i.isOdd ? 1 : 2, 'sender_name': longName, 'is_read': i == 1, 'created_at': now},
    'unread_count': 128,
    'mention_unread': i == 2,
    'updated_at': now,
  };
}

Map<String, dynamic> chatTransfer(int id, {String kind = 'transfer', String status = 'completed', int from = 1, int to = 2, int room = 1}) => {
      'transfer_id': id,
      'transfer_no': 'TF2026091410300012345$id',
      'kind': kind,
      'room_id': room,
      'message_id': 8 + id,
      'from_user_id': from,
      'to_user_id': to,
      'amount': 123456,
      'note': 'Deposit for the textbook I will pick up at the locker on Saturday',
      'status': status,
      'created_at': now,
      'responded_at': status == 'pending' ? null : now,
      'expires_at': '2099-01-01T00:00:00.000Z',
    };

Map<String, dynamic> chatGroupInfo() => {
      'room_id': 2,
      'type': 'group',
      'name': 'Second-hand Textbook Exchange Group for Engineering Students',
      'avatar_url': null,
      'created_by': 1,
      'my_role': 'owner',
      'members': [for (final id in [1, 2, 3, 4]) {...user(id), 'role': id == 1 ? 'owner' : 'member', 'alias': id == 3 ? 'Study Buddy With An Extremely Long Alias' : null, 'joined_at': now}],
      'partner': null,
      'muted': true,
      'pinned': true,
    };

Map<String, dynamic> chatMeta(int roomId) => roomId == 2
    ? {
        'members_read': [
          {'user_id': 2, 'last_read_message_id': 12},
          {'user_id': 3, 'last_read_message_id': 12},
          {'user_id': 4, 'last_read_message_id': 6},
        ],
        'typing_user_ids': [2, 3, 4],
        'aliases': {'3': 'Study Buddy With An Extremely Long Alias'},
        'edited': <Object>[],
        'recalled_ids': <int>[],
        'has_more': true,
        'reservations': <Object>[],
        'transfers': [chatTransfer(1, room: 2, to: 3), chatTransfer(2, kind: 'request', status: 'pending', from: 1, to: 4, room: 2)],
        'muted': true,
        'room': {'type': 'group', 'title': 'Second-hand Textbook Exchange Group for Engineering Students', 'avatar_url': null, 'member_count': 100},
      }
    : {
        'read_upto': 6,
        'partner_typing': true,
        'recalled_ids': <int>[],
        'has_more': true,
        'reservations': [chatReservation()],
        'transfers': [chatTransfer(1), chatTransfer(2, kind: 'request', status: 'pending', from: 1, to: 2)],
        'members_read': [
          {'user_id': 2, 'last_read_message_id': 6},
        ],
        'aliases': <String, String>{},
        'edited': <Object>[],
        'room': {'type': 'direct', 'title': longName, 'avatar_url': null, 'member_count': 2},
      };

List<Map<String, dynamic>> chatMessages(int roomId) {
  final group = roomId == 2;
  final kinds = group
      ? ['notice', 'text', 'text', 'image', 'text', 'voice', 'text', 'recalled', 'text', 'transfer', 'transfer', 'text', 'album', 'album']
      : ['text', 'image', 'voice', 'book', 'reservation', 'recalled', 'text', 'text', 'transfer', 'transfer', 'album'];
  const long = 'This is a fairly long chat message that should wrap nicely. This is a fairly long chat message that should wrap nicely. ';
  return List.generate(kinds.length, (n) {
    final i = n + 1;
    final kind = kinds[n];
    final sender = group ? [1, 2, 2, 3, 1, 4, 3, 2, 1, 1, 1, 1, 2, 1][n] : (i.isEven ? 1 : 2);
    final albumUrls = [for (var k = 0; k < (group && i == 13 ? 7 : 2); k++) '/uploads/chat/album$k.jpg'];
    final mentionText = group && i == 3 ? '@$longName $long' : group && i == 5 ? '@Everyone $long' : null;
    final transferId = kind == 'transfer' ? kinds.sublist(0, n).where((k) => k == 'transfer').length + 1 : 0;
    return {
      'message_id': i,
      'room_id': roomId,
      'sender_id': sender,
      'content': kind == 'transfer' ? '[transfer]{"transfer_id":$transferId}' : mentionText ?? long,
      'message_type': kind == 'text' ? 'text' : kind == 'image' ? 'image' : 'system',
      'kind': kind,
      'body': kind == 'text' ? mentionText ?? long : kind == 'image' ? '/uploads/chat/a.jpg' : kind == 'notice' ? '$longName created the group' : null,
      'mentions': mentionText == null
          ? <Object>[]
          : [
              {'user_id': i == 3 ? 1 : 0, 'start': 0, 'length': i == 3 ? longName.length + 1 : 9},
            ],
      'payload': switch (kind) {
        'voice' => {'url': '/uploads/voice/a.m4a', 'duration': 118},
        'book' => {'book_id': 5, 'title': longTitle, 'price': 123456, 'image_url': null},
        'reservation' => chatReservation(),
        'album' => {'urls': albumUrls},
        'transfer' => group
            ? (transferId == 1 ? chatTransfer(1, room: 2, to: 3) : chatTransfer(2, kind: 'request', status: 'pending', from: 1, to: 4, room: 2))
            : (transferId == 1 ? chatTransfer(1) : chatTransfer(2, kind: 'request', status: 'pending', from: 1, to: 2)),
        _ => null,
      },
      'is_read': i < 6,
      'created_at': now,
      'edited_at': kind == 'text' && i.isEven ? now : null,
      'reply_to': kind == 'text' && i > 6
          ? {'message_id': 2, 'sender_id': group ? 2 : 1, 'sender_nickname': longName, 'kind': group ? 'text' : 'image', 'preview': long, 'image_url': group ? null : '/uploads/chat/a.jpg'}
          : null,
      'users': {'user_id': sender, 'nickname': longName, 'avatar_url': null},
    };
  });
}

const longReason = 'Because you saved several mystery novels by the same author last week';

Map<String, dynamic> aiSettingsData() => {
      'settings': {
        'enabled': true,
        'default_provider': 'gemini',
        'providers': {
          'deepseek': {'model': 'deepseek-flash-extended-context-preview-2026-09', 'input_per_m': 0.14, 'cached_input_per_m': 0.0028, 'output_per_m': 0.28, 'search_price_per_k': 0, 'search_free_per_month': 0},
          'gemini': {'model': 'gemini-3.1-flash-lite', 'input_per_m': 0.25, 'cached_input_per_m': 0.025, 'output_per_m': 1.5, 'search_price_per_k': 14, 'search_free_per_month': 5000},
          'openai': {'model': 'gpt-5-nano', 'input_per_m': 123.456, 'cached_input_per_m': 0.005, 'output_per_m': 999.99, 'search_price_per_k': 10, 'search_free_per_month': 0},
        },
        'features': {
          'support': {'enabled': true, 'provider': null},
          'listing_assist': {'enabled': true, 'provider': 'openai', 'web_search': true},
          'recommend': {'enabled': false, 'provider': null},
          'moderation': {'enabled': true, 'provider': 'deepseek', 'action': 'block'},
        },
        'limits': {'monthly_budget_usd': 12345, 'daily_per_user': {'support': 10000, 'listing_assist': 15, 'recommend': 0}},
      },
      'providers': [
        {'id': 'deepseek', 'name': 'DeepSeek', 'key_configured': false, 'vision': false, 'web_search': false, 'default_model': 'deepseek-flash'},
        {'id': 'gemini', 'name': 'Gemini', 'key_configured': true, 'vision': true, 'web_search': true, 'default_model': 'gemini-3.1-flash-lite'},
        {'id': 'openai', 'name': 'OpenAI', 'key_configured': true, 'vision': true, 'web_search': true, 'default_model': 'gpt-5-nano'},
      ],
      'migration_ready': false,
    };

Map<String, dynamic> aiUsageData() => {
      'period': 'month',
      'summary': {'requests': 1234567, 'errors': 98765, 'input_tokens': 9876543210, 'output_tokens': 123456789, 'search_calls': 45678, 'cost_usd': 9876.54321, 'month_cost_usd': 11111.2, 'monthly_budget_usd': 12345, 'budget_used_ratio': 0.9, 'projected_month_cost_usd': 23456.78},
      'by_feature': [
        for (final f in ['support', 'listing_assist', 'recommend', 'moderation', 'test'])
          {'feature': f, 'requests': 123456, 'cost_usd': f == 'test' ? 0.0042 : 1234.5678, 'input_tokens': 1, 'output_tokens': 1, 'errors': 9999},
      ],
      'by_provider': [
        {'provider': 'deepseek', 'model': 'deepseek-flash-extended-context-preview-2026-09', 'requests': 999999, 'cost_usd': 4321.1234, 'avg_latency_ms': 12345},
        {'provider': 'gemini', 'model': 'gemini-3.1-flash-lite', 'requests': 12, 'cost_usd': 0.00042, 'avg_latency_ms': 840},
      ],
      'daily': [
        for (var i = 1; i <= 30; i++)
          {'date': '2026-09-${i.toString().padLeft(2, '0')}', 'requests': 1234 * i, 'cost_usd': i * 12.5, 'by_feature': {'support': i * 5.0, 'listing_assist': i * 4.0, 'recommend': i * 2.5, 'moderation': i * 1.0}},
      ],
      'top_users': many((i) => {'user_public_id': '0123456789abcdef0123456789abcde$i', 'nickname': longName, 'requests': 1234567, 'cost_usd': 12345.6789}, 5),
      'recent_errors': many((i) => {'created_at': now, 'feature': 'listing_assist', 'provider': 'openai', 'model': 'gpt-5-nano-2025-08-07-very-long-model-identifier', 'error_code': i.isEven ? 'QUOTA' : 'SOME_VERY_LONG_UNMAPPED_PROVIDER_ERROR_CODE_FROM_UPSTREAM', if (i.isEven) 'error_detail': 'You exceeded your current quota. Quota exceeded for metric: generate_content_free_tier_requests, limit: 0, model: gemini-3.1-flash-lite ' * 3}, 6),
      'pending_reviews': 9999,
    };

Map<String, dynamic> aiReviewRow(int i) => {
      'book_id': i,
      'book': {'book_id': i, 'title': longTitle, 'price': 123456, 'image_url': null},
      'seller': user(2),
      'verdict': i.isEven ? 'reject' : 'review',
      'reasons': ['The description includes a phone number and asks buyers to pay outside the platform', 'The photos appear to show a phone case rather than a book'],
      'categories': ['contact', 'not_book', 'misleading', 'price'],
      'status': 'pending',
      'created_at': now,
    };

const aiSupportLong = 'You can drop the book off at any smart locker.\n\n**Steps**\n- Open the order and tap Drop off\n- Scan the QR code on the locker screen\n1. Put the book in the open slot and close the door firmly so that it locks\n2. Wait for the confirmation notification';

List<AiChatItem> aiSupportItems() => [
      AiChatItem(id: 'a', isUser: true, content: 'How do I drop off a book I sold? ' * 3, animate: false),
      AiChatItem(id: 'b', isUser: false, content: aiSupportLong, animate: false),
      AiChatItem(id: 'c', isUser: true, content: 'The locker did not open after scanning and my order is stuck', animate: false),
      AiChatItem(id: 'd', isUser: false, content: 'I am sorry about that. This needs a staff member to check the locker log.', suggestHandoff: true, animate: false),
      AiChatItem(id: 'e', isUser: true, content: 'Please transfer me', state: AiChatState.failed, error: 'The AI service is temporarily unavailable. Please try again later.', animate: false),
      AiChatItem(id: 'f', isUser: true, content: 'One more question', state: AiChatState.failed, error: 'You have reached today\'s AI usage limit. Please try again tomorrow.', blocked: true, animate: false),
    ];

const aiChatReply = 'Here are mystery novels that read well in short bursts, all currently on sale and within your budget.\n\n- Fast paced chapters that finish in one commute\n- No prior reading needed';

List<AiBookChatItem> aiBookChatItems() {
  final books = [for (var i = 1; i <= 6; i++) Book.fromJson(book(i))];
  return [
    AiBookChatItem(id: 'a', isUser: true, content: 'I want a mystery novel I can read on the train, under 300 coins ' * 2, animate: false),
    AiBookChatItem(
      id: 'b',
      isUser: false,
      content: aiChatReply,
      books: [for (final b in books) AiBookSuggestion(book: b, reason: longReason)],
      suggestions: const ['Any Japanese authors?', 'Something even cheaper please', 'Show me hardcovers only'],
      animate: false,
    ),
    AiBookChatItem(id: 'c', isUser: true, content: 'Anything without a cliffhanger?', state: AiBookChatState.failed, error: 'The AI service is temporarily unavailable. Please try again later.', animate: false),
    AiBookChatItem(id: 'd', isUser: true, content: 'One more question', state: AiBookChatState.failed, error: 'You have reached today\'s AI usage limit. Please try again tomorrow.', blocked: true, animate: false),
  ];
}

AiListingAssist aiAssistResult() => AiListingAssist.fromJson({
      'fields': {'title': longTitle, 'subtitle': 'An Unabridged Annotated Edition With Extended Commentary', 'author': 'Johann Wolfgang von Goethe-Schiller', 'publisher': 'Penguin Random House International Publishing', 'publish_date': '2020-05', 'publish_date_precision': 'month', 'isbn': '9789571234567', 'page_count': 1248, 'language': 'zh-Hant', 'description': 'A long description ' * 20},
      'description_source': 'mixed',
      'category': {'category_id': 2, 'name': 'Computer Science & Programming', 'confidence': 0.82},
      'condition': {'level': 'good', 'confidence': 0.45, 'reasons': ['Slight wear on the cover corners and a crease along the spine', 'No visible water damage']},
      'price': {'suggested': 12345, 'min': 10000, 'max': 99999, 'original_price': 99999, 'currency': 'TWD', 'reasons': ['List price 99999, good condition, about half of the list price']},
      'sources': [{'title': 'Open Library: The Extraordinarily Long Title of a Second-hand Book', 'url': 'https://openlibrary.org/books/OL1M'}, {'title': '', 'url': 'https://www.books.com.tw/products/0010000000'}],
      'warnings': ['The photos were too dark to judge the condition reliably; add a clear photo of the spine'],
      'provider': 'gemini',
      'model': 'gemini-3.1-flash-lite',
    });

List<Map<String, dynamic>> many(Map<String, dynamic> Function(int i) build, [int n = 4]) =>
    List.generate(n, (i) => build(i + 1));

Object? fakeData(String method, String path) {
  final statuses = ['pending_deposit', 'deposited', 'completed', 'refunding', 'cancelled'];
  final routes = <String, Object? Function()>{
    'GET /auth/me': () => user(1),
    'GET /users/me/stats': () => {'balance': 9876543.5, 'book_count': 12345, 'favorite_count': 99999, 'unread_notification_count': 999, 'cart_count': 99},
    'GET /users/me/level': () => {
          'points': 1234567,
          'completed_orders': 98765,
          'current_level': {'level_id': 3, 'level_name': 'Platinum Collector Elite', 'min_points': 100000, 'max_points': null, 'benefits': 'Free delivery and priority support'},
          'next_level': {'level_id': 4, 'level_name': 'Diamond Legendary Reader', 'min_points': 2000000, 'max_points': null, 'benefits': 'Everything'},
          'points_to_next': 765433,
          'levels': many((i) => {'level_id': i, 'level_name': 'Level Name Number $i Extended', 'min_points': i * 100000, 'max_points': i * 200000, 'benefits': 'Benefit description for this membership tier'}),
        },
    'GET /users/me/notification-settings': () => {'order': true, 'message': false, 'promotion': true},
    'GET /users/me/deletion': () => {'pending': false, 'grace_days': 30},
    'GET /users/me/qrcode': () => {'user_id': 1, 'nickname': longName, 'qr_data': 'https://api.savemybook.today/u/0123456789abcdef0123456789abcdef'},
    'GET /books': () => many((i) => {...book(i), 'review_status': i == 2 ? 'pending' : (i == 3 ? 'rejected' : null)}),
    'GET /ai/status': () => {'support': true, 'listing_assist': true, 'recommend': true, 'book_chat': true, 'web_search': true, 'consented': true, 'providers_in_use': ['DeepSeek', 'Google Gemini', 'OpenAI']},
    'GET /ai/support/session': () => {'session_id': 1, 'status': 'open', 'messages': [for (final (i, m) in aiSupportItems().take(4).indexed) {'message_id': i + 1, 'role': m.isUser ? 'user' : 'assistant', 'content': m.content, 'created_at': now}]},
    'GET /ai/recommendations': () => many((i) => {'book': book(i), 'reason': longReason}, 6),
    'GET /ai/book-chat/session': () => {
          'session_id': 8,
          'messages': [
            {'message_id': 1, 'role': 'user', 'content': 'I want a mystery novel for my commute, under 300 coins', 'books': <Object>[], 'created_at': now},
            {'message_id': 2, 'role': 'assistant', 'content': aiChatReply, 'books': many((i) => {'book': book(i), 'reason': longReason}, 6), 'created_at': now},
          ],
        },
    'GET /admin/ai/settings': aiSettingsData,
    'GET /admin/ai/usage': aiUsageData,
    'GET /admin/ai/reviews': () => many(aiReviewRow, 5),
    'GET /books/5': () => book(5),
    'GET /categories': () => [
          {'category_id': 1, 'category_name': 'Literature & Fiction Classics', 'parent_id': null, 'sort_order': 0, 'other_book_categories': <Object>[]},
          {'category_id': 2, 'category_name': 'Computer Science & Programming', 'parent_id': null, 'sort_order': 1, 'other_book_categories': <Object>[]},
        ],
    'GET /cart': () => many((i) => {'cart_id': i, 'book_id': i, 'quantity': 1, 'books': book(i)}),
    'GET /favorites': () => many((i) => book(i)),
    'GET /favorites/ids': () => [1, 2],
    'GET /orders': () => many((i) => order(i, statuses[i % statuses.length])),
    'GET /orders/7': () => order(7, 'deposited'),
    'GET /wallet': () => {'balance': 9876543.5, 'frozen_amount': 123456, 'total_income': 98765432, 'total_expense': 12345678, 'pending_income': 7654321},
    'GET /wallet/transactions': () => many((i) => {'txn_id': i, 'type': ['purchase', 'sale_income', 'transfer_in', 'transfer_out', 'refund', 'admin_adjust'][i % 6], 'amount': i.isEven ? 1234567 : -1234567, 'balance_after': 9876543, 'description': 'Order SMB20260914103000123456 refund', 'created_at': now, 'orders': {'order_id': i, 'order_no': 'SMB20260914103000123456', 'order_items': [{'books': book(i)}]}}),
    'GET /wallet/pending': () => many((i) => order(i, 'deposited')),
    'GET /notifications': () => many((i) => {'notification_id': i, 'type': ['order', 'message', 'system', 'promotion'][i % 4], 'title': 'Your book "$longTitle" has been sold', 'content': 'Order SMB20260914103000123456 was placed. Please drop the book off at $longCabinet within seven days.', 'related_id': i, 'related_type': 'order', 'is_read': i.isEven, 'created_at': now}),
    'GET /notifications/unread-count': () => {'unread_count': 999},
    'GET /announcements': () => many((i) => {'announcement_id': i, 'title': 'Scheduled maintenance for the smart locker network this weekend', 'content': 'We will upgrade the locker firmware. ' * 5, 'type': ['general', 'maintenance', 'promotion', 'policy'][i % 4], 'is_published': true, 'published_at': now, 'created_at': now, 'users': user(9)}),
    'GET /chat/rooms': () => many(chatRoomRow),
    'GET /chat/rooms/1': () => {'room_id': 1, 'type': 'direct', 'name': '', 'avatar_url': null, 'created_by': 1, 'my_role': 'member', 'members': [chatMember(1), chatMember(2)], 'partner': {...user(2), 'alias': longName}, 'muted': true, 'pinned': true},
    'GET /chat/rooms/2': () => {'room_id': 2, 'type': 'group', 'name': 'Advanced Statistics Study Group for the Autumn Semester', 'avatar_url': null, 'created_by': 1, 'my_role': 'owner', 'members': [chatMember(1, role: 'owner'), ...many((i) => chatMember(i + 1, role: i == 1 ? 'owner' : 'member'), 6)], 'partner': null, 'muted': false, 'pinned': true},
    'GET /chat/unread-count': () => {'unread_count': 999},
    'GET /cart/book-ids': () => [1, 5],
    'GET /cabinets': () => many((i) => {...cabinet(), 'cabinet_id': i, 'available_slots': i == 2 ? 0 : 123, 'latitude': '25.0173000', 'longitude': '121.5398000', 'distance_m': i * 1234}),
    'GET /auth/providers': () => {
          'social_enabled': true,
          'providers': [for (final id in AuthProviders.ids) {'id': id, 'enabled': true, 'signup': true, 'configured': true}],
        },
    'GET /users/me/identities': () => {
          'password_set': false,
          'identities': [
            {'provider': 'google', 'display_name': longName, 'masked_email': 'al***@example.com', 'masked_phone': null, 'created_at': now, 'last_login_at': now},
            {'provider': 'phone', 'display_name': null, 'masked_email': null, 'masked_phone': '09**-***-678', 'created_at': now, 'last_login_at': now},
          ],
        },
    'GET /admin/auth/settings': () => {
          'settings': {
            'social_enabled': true,
            'providers': {
              'google': {'enabled': true, 'signup': true},
              'apple': {'enabled': true, 'signup': true},
              'phone': {'enabled': true, 'signup': false},
              'line': {'enabled': false, 'signup': false},
              'discord': {'enabled': false, 'signup': false},
            },
          },
          'providers': [
            {'id': 'google', 'name': 'Google', 'configured': true},
            {'id': 'apple', 'name': 'Apple', 'configured': true},
            {'id': 'phone', 'name': '手機號碼', 'configured': true},
            {'id': 'line', 'name': 'LINE', 'configured': false},
            {'id': 'discord', 'name': 'Discord', 'configured': false},
          ],
          'migration_ready': true,
        },
    'GET /security': () => {'available': true, 'has_payment_pin': true, 'pin_locked_until': null, 'biometric_pay_enabled': true},
    'GET /security/sessions': () => many((i) => {'session_id': i, 'device_name': i == 1 ? 'iPhone 17 Pro Max' : 'Samsung Galaxy Z Fold7 Ultra Enterprise Edition', 'platform': i.isOdd ? 'ios' : 'android', 'app_version': '1.0.0', 'ip_address': '2001:0db8:85a3:0000:0000:8a2e:0370:7334', 'created_at': now, 'last_seen_at': now, 'biometric_pay': i == 1, 'is_current': i == 1}),
    'GET /push/devices': () => many((i) => {'device_id': i, 'platform': 'ios', 'token_tail': 'a1b2c3', 'created_at': now, 'last_seen_at': now}, 2),
    'GET /support/faqs': () => many((i) => {'faq_id': i, 'category': ['account', 'trade', 'wallet', 'cabinet'][i % 4], 'question': 'How do I get my coins back if the seller never drops the book off?', 'answer': 'Answer ' * 30, 'sort_order': i, 'is_visible': true}),
    'GET /support/tickets': () => many((i) => {'ticket_id': i, 'subject': 'My order has been stuck in pending deposit for more than a week', 'category': 'trade', 'status': ['open', 'pending', 'resolved', 'closed'][i % 4], 'message_count': 12, 'last_message': 'Could you please check it for me?', 'updated_at': now, 'created_at': now, 'user': user(1)}),
    'GET /support/tickets/1': () => {'ticket_id': 1, 'subject': 'My order has been stuck in pending deposit for more than a week', 'category': 'trade', 'status': 'pending', 'message_count': 2, 'updated_at': now, 'user': user(1), 'messages': many((i) => {'message_id': i, 'content': 'Message content ' * 8, 'is_staff': i.isEven, 'created_at': now, 'sender': user(i.isEven ? 9 : 1)}, 2)},
    'GET /support/legal/terms': () => {'doc_id': 1, 'doc_key': 'terms', 'title': 'Terms of Service', 'content': 'Article 1. ' * 200, 'version': 3, 'updated_at': now},
    'GET /reports/against-me': () => <Object>[],
    'GET /admin/overview': () => {'member_count': 1234567, 'pending_report_count': 9999, 'pending_dispute_count': 9999, 'active_cabinet_count': 999, 'today_order_count': 99999, 'open_ticket_count': 9999},
    'GET /admin/stats': () => {
          'days': 30,
          'series': List.generate(30, (i) => {'date': '2026-08-${(i + 1).toString().padLeft(2, '0')}', 'orders': 12345 + i, 'revenue': 98765432.0 + i, 'new_users': 23456, 'new_books': 34567}),
          'completed_order_count': 1234567,
          'completed_revenue': 987654321.0,
          'top_categories': many((i) => {'category_name': 'Literature & Fiction Classics $i', 'book_count': 123456 * i}),
        },
    'GET /admin/members': () => many((i) => {...user(i), 'is_active': i != 2, 'is_blacklisted': i == 3, '_count': {'books': 12345, 'orders_orders_buyer_idTousers': 6789, 'orders_orders_seller_idTousers': 4321}}),
    'GET /admin/members/5': () => {
          ...user(5), 'role': 'admin', 'is_active': true, 'is_blacklisted': false, 'book_count': 12345, 'completed_orders': 6789,
          'base_points': 67890, 'bonus_points': -1234, 'points': 66656,
          'current_level': {'level_id': 3, 'level_name': 'Platinum Collector Elite', 'min_points': 50000, 'max_points': null, 'benefits': ''},
          'levels': many((i) => {'level_id': i, 'level_name': 'Level Name Number $i', 'min_points': i * 10000, 'max_points': null, 'benefits': ''}),
          'permissions': {for (final k in ['can_manage_members', 'can_manage_levels', 'can_manage_content', 'can_manage_reports', 'can_manage_orders', 'can_manage_transactions', 'can_manage_wallets', 'can_manage_cabinets', 'can_manage_announcements', 'can_manage_support', 'can_view_stats', 'can_manage_system']) k: k != 'can_manage_system'},
          'grantable': {'can_manage_system': false},
        },
    'GET /admin/orders': () => many((i) => adminOrder(i, statuses[i % statuses.length])),
    'GET /admin/orders/7': () => {
          ...adminOrder(7, 'refunding'), 'payment_method': 'wallet', 'note': null, 'slot': {'slot_number': 'A12'},
          'timeline': {'created_at': now, 'payment_at': now, 'deposited_at': now},
          'refunds': [{'refund_id': 1, 'refund_type': 'manual', 'amount': 1234567, 'status': 'completed', 'reason': 'Book condition did not match the description', 'created_at': now, 'processed_at': now}],
          'disputes': [{'dispute_id': 1, 'reason': 'The book has water damage that was not mentioned', 'status': 'resolved', 'result': 'refund_manual', 'admin_note': 'Refunded', 'created_at': now, 'resolved_at': now}],
          'wallet_transactions': many((i) => {'txn_id': i, 'type': 'refund', 'amount': -1234567, 'balance_after': 9876543, 'description': 'Order SMB20260914103000123456 refund', 'created_at': now}, 2),
        },
    'GET /admin/books': () => many((i) => {'book_id': i, 'title': longTitle, 'isbn': '9789571234567', 'price': 123456, 'status': ['on_sale', 'reserved', 'sold', 'removed'][i % 4], 'condition_level': 'fair', 'category_id': 1, 'category_name': 'Literature & Fiction Classics', 'seller': user(2), 'view_count': 987654, 'pending_report_count': 99, 'image_url': null, 'created_at': now}),
    'GET /admin/categories': () => many((i) => {'category_id': i, 'category_name': 'Computer Science & Programming $i', 'sort_order': i, 'book_count': 123456}),
    'GET /admin/reports': () => many((i) => {'report_id': i, 'target_type': 'book', 'target_id': i, 'reason': 'Counterfeit copy with missing pages ' * 3, 'status': ['pending', 'reviewing', 'resolved', 'dismissed'][i % 4], 'created_at': now, 'users_reports_reporter_idTousers': user(1), 'target': {'title': longTitle, 'book_images': <Object>[]}}),
    'GET /admin/disputes': () => many((i) => {'dispute_id': i, 'order_id': i, 'reason': 'The book has water damage ' * 3, 'status': i.isEven ? 'resolved' : 'pending', 'result': i.isEven ? 'refund_manual' : null, 'created_at': now, 'users_transaction_disputes_applicant_idTousers': user(1), 'orders': {'order_id': i, 'order_no': 'SMB20260914103000123456', 'total_amount': 1234567, 'users_orders_buyer_idTousers': user(1), 'users_orders_seller_idTousers': user(2), 'order_items': [{'books': book(i)}]}}),
    'GET /admin/cabinets': () => many((i) => {...cabinet(), 'cabinet_id': i, 'latitude': 25.0173, 'longitude': 121.5398, 'total_slots': 200, 'available_slots': 123, 'is_active': i != 2, 'slot_summary': {'empty': 123, 'occupied': 45, 'reserved': 22, 'maintenance': 10}, 'cabinet_slots': many((j) => {'slot_id': j, 'slot_number': 'A${j.toString().padLeft(2, '0')}', 'status': 'occupied', 'updated_at': now}, 8)}),
    'GET /admin/maintenance-logs': () => many((i) => {'log_id': i, 'action': 'Changed slot status', 'detail': 'Changed A12 at $longCabinet to maintenance', 'users': user(9), 'created_at': now}),
    'GET /admin/wallets': () => many((i) => {...user(i), 'balance': 9876543.5, 'frozen_amount': 0, 'total_income': 98765432, 'total_expense': 12345678}),
    'GET /admin/levels': () => many((i) => {'level_id': i, 'level_name': 'Platinum Collector Elite $i', 'min_points': i * 1000000, 'max_points': (i + 1) * 1000000, 'benefits': 'Free delivery, priority support and exclusive early access'}),
    'GET /admin/faqs': () => many((i) => {'faq_id': i, 'category': 'trade', 'question': 'How do I get my coins back if the seller never drops the book off?', 'answer': 'Answer ' * 20, 'sort_order': i, 'is_visible': i != 2}),
    'GET /admin/legal': () => [{'doc_id': 1, 'doc_key': 'terms', 'title': 'Terms of Service', 'content': 'Article 1. ' * 50, 'version': 3, 'updated_at': now}],
    'GET /admin/tickets': () => many((i) => {'ticket_id': i, 'subject': 'My order has been stuck in pending deposit for more than a week', 'category': 'trade', 'status': ['open', 'pending', 'resolved', 'closed'][i % 4], 'message_count': 12, 'last_message': 'Could you please check it for me?', 'updated_at': now, 'user': user(1)}),
    'GET /admin/backups': () => many((i) => {'backup_id': i, 'file_name': 'savemybook-2026-09-14T03-00-00.sql.gz', 'size_bytes': 123456789, 'trigger_by': ['schedule', 'manual', 'pre_restore', 'schedule'][i % 4], 'status': i == 4 ? 'failed' : 'success', 'detail': i == 4 ? 'mysqldump: Got error: 1045: Access denied for user admin' : null, 'created_at': now, 'admin': user(9), 'available': true}),
    'GET /admin/deletions': () => many((i) => {...user(i), 'deletion_requested_at': now, 'purge_at': now}),
    'GET /admin/operation-logs': () => many((i) => {'log_id': i, 'action': 'Changed member status', 'target_type': 'user', 'target_id': i, 'summary': 'Changed account status and blocklist for $longName (alexandria.montgomery@example.com)', 'changes': [{'label': 'Account status', 'from': 'Active', 'to': 'Suspended'}, {'label': 'Price', 'from': '123456789 coins', 'to': '987654321 coins'}], 'can_undo': i.isOdd, 'reverted': i == 4 ? {'at': now, 'by': 9} : null, 'created_at': now, 'admin': user(9)}),
    'GET /announcements/all': () => many((i) => {'announcement_id': i, 'title': 'Scheduled maintenance for the smart locker network this weekend', 'content': 'Content ' * 20, 'type': ['general', 'maintenance', 'promotion', 'policy'][i % 4], 'is_published': i.isOdd, 'published_at': now, 'created_at': now, 'users': user(9)}),
  };

  final key = '$method $path';
  if (routes.containsKey(key)) return routes[key]!();
  final chatRoom = RegExp(r'^GET /chat/rooms/(\d+)/messages$').firstMatch(key);
  if (chatRoom != null) return chatMessages(int.parse(chatRoom.group(1)!));
  if (method == 'GET') return <Object>[];
  return <String, Object>{};
}

MockClient fakeApi() => MockClient((request) async {
      final path = request.url.path.replaceFirst('/api', '');
      final data = fakeData(request.method, path);
      final body = <String, Object?>{
        'success': true,
        'message': 'OK',
        'data': data,
        if (path == '/chat/rooms/1/messages') 'partner': user(2),
        if (path == '/chat/rooms/1/messages') 'meta': chatMeta(1),
        if (path == '/chat/rooms/2/messages') 'meta': chatMeta(2),
        if (path == '/cart') 'total_amount': 4938268,
        if (path == '/notifications') 'unread_count': 999,
        if (path == '/wallet/pending') 'total_amount': 4938268,
        if (path == '/admin/backups') 'keep': 14,
        if (path == '/ai/recommendations') 'meta': {'source': 'ai', 'generated_at': now},
        if (data is List) 'pagination': {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
      };
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

final testUser = User.fromJson(user(1));

Map<String, Widget Function()> get screens => {
      'Login': () => const LoginScreen(),
      'Register': () => const RegisterScreen(),
      'Home': () => const HomeScreen(),
      'Profile': () => const ProfileScreen(),
      'EditProfile': () => const EditProfileScreen(),
      'Settings': () => const SettingsScreen(),
      'AccountPrivacy': () => const AccountPrivacyScreen(),
      'AppPermissions': () => const AppPermissionsScreen(),
      'ChangePassword': () => const ChangePasswordScreen(),
      'ShareProfile': () => const ShareProfileScreen(),
      'MemberLevel': () => const MemberLevelScreen(),
      'Wallet': () => const WalletScreen(),
      'PendingIncome': () => const PendingIncomeScreen(),
      'Cart': () => const CartScreen(),
      'Favorites': () => const FavoritesScreen(),
      'BookDetail': () => BookDetailScreen(book: Book.fromJson(book(5))),
      'BookManage': () => const BookManageScreen(),
      'SellBook': () => const SellBookScreen(),
      'PurchaseHistory': () => const PurchaseHistoryScreen(),
      'SalesHistory': () => const SalesHistoryScreen(),
      'OrderDetail': () => OrderDetailScreen(order: Order.fromJson(order(7, 'deposited'))),
      'OrderDetailSeller': () => OrderDetailScreen(order: Order.fromJson(order(7, 'refunding')), asSeller: true),
      'Dispute': () => const DisputeScreen(orderId: 7),
      'Notifications': () => const NotificationScreen(),
      'AnnouncementDetail': () => AnnouncementDetailScreen(
          announcement: Announcement.fromJson({'announcement_id': 1, 'title': 'Scheduled maintenance for the smart locker network', 'content': 'Content ' * 50, 'type': 'maintenance', 'is_published': true, 'published_at': now})),
      'ChatList': () => const ChatListScreen(),
      'ChatRoom': () => const ChatRoomScreen(roomId: 1, partnerName: longName),
      'ChatRoomGroup': () => const ChatRoomScreen(roomId: 2),
      'ChatSettingsDirect': () => const ChatRoomSettingsScreen(roomId: 1),
      'ChatSettingsGroup': () => const ChatRoomSettingsScreen(roomId: 2),
      'CreateGroup': () => const CreateGroupScreen(),
      'TransferCards': () => const TransferCardsPreview(),
      'ChatAlbums': () => const ChatAlbumsPreview(),
      'ChatMentionPanel': () => const MentionPanelPreview(),
      'ImageGallery': () => ImageViewer.gallery(
            imageUrls: [for (var i = 0; i < 5; i++) 'https://api.savemybook.today/uploads/chat/album$i.jpg'],
            initialIndex: 1,
          ),
      'HelpCenter': () => const HelpCenterScreen(),
      'SupportTickets': () => const SupportTicketScreen(),
      'NewTicket': () => const NewTicketScreen(),
      'TicketDetail': () => const TicketDetailScreen(ticketId: 1),
      'LegalDoc': () => const LegalDocScreen(docKey: 'terms', fallbackTitle: 'Terms'),
      'LegalConsent': () => LegalConsentScreen(documents: [LegalDoc.fromJson({'doc_id': 1, 'doc_key': 'terms', 'title': 'Terms of Service and Community Guidelines', 'content': 'Article 1. ' * 300, 'version': 3, 'updated_at': now})]),
      'SecurityCenter': () => const SecurityCenterScreen(),
      'SignInMethods': () => const SignInMethodsPreview(),
      'SetPassword': () => const SetPasswordScreen(),
      'PhoneSignIn': () => const PhoneSignInScreen(),
      'PhoneSmsCode': () => const PhoneSmsCodePreview(),
      'SocialProfile': () => const SocialProfileScreen(provider: AuthProviders.phone),
      'AdminAuth': () => const AdminAuthScreen(),
      'LoginDevices': () => const LoginDevicesScreen(),
      'AdminHome': () => const AdminHomeScreen(),
      'AdminStats': () => const AdminStatsScreen(),
      'AdminMembers': () => const AdminMemberScreen(),
      'AdminMemberDetail': () => const AdminMemberDetailScreen(userId: 5),
      'AdminOrders': () => const AdminOrderScreen(),
      'AdminOrderDetail': () => const AdminOrderDetailScreen(orderId: 7, orderNo: 'SMB20260914103000123456'),
      'AdminBooks': () => const AdminBookScreen(),
      'AdminCategories': () => const AdminCategoryScreen(),
      'AdminReports': () => const AdminReportScreen(),
      'AdminDisputes': () => const AdminDisputeScreen(),
      'AdminCabinets': () => const AdminCabinetScreen(),
      'AdminMaintenanceLog': () => const AdminMaintenanceLogScreen(),
      'AdminWallets': () => const AdminWalletScreen(),
      'AdminLevels': () => const AdminLevelScreen(),
      'AdminTickets': () => const AdminTicketScreen(),
      'AdminBackups': () => const AdminBackupScreen(),
      'AdminDeletions': () => const AdminDeletionScreen(),
      'AdminOperationLog': () => const AdminOperationLogScreen(),
      'AdminAnnouncements': () => const AdminAnnouncementScreen(),
      'AdminAiUsage': () => const AdminAiScreen(),
      'AdminAiSettings': () => const AdminAiScreen(initialTab: 1, initialAdvancedOpen: true),
      'AdminAiReview': () => const AdminAiScreen(initialTab: 2),
      'AiSupport': () => const AiSupportScreen(),
      'AiSupportStates': () => AiSupportScreen(initialItems: aiSupportItems()),
      'AiBookChat': () => const AiBookChatScreen(),
      'AiBookChatStates': () => AiBookChatScreen(initialItems: aiBookChatItems()),
      'AiListingResultSheet': () => DialogPreview(
          show: (context) => showAiListingResultSheet(context, result: aiAssistResult(), targets: aiAssistTargets())),
      'AiListingResultSheetStep2': () => DialogPreview(
          show: (context) => showAiListingResultSheet(context,
              result: aiAssistResult(),
              targets: const AiListingTargets(supportsCondition: true, condition: 'fair', conditionTouched: true, supportsPrice: true, price: 500))),
      'AiListingProgress': () => DialogPreview(
          show: (context) => showModalBottomSheet<void>(
              context: context,
              builder: (_) => AiAssistProgressSheet(
                    steps: const ['Looking up book details', 'Searching the web for more details', 'Analyzing photos', 'Suggesting category, condition and price'],
                    run: () => Completer<AiResult<AiListingAssist>>().future,
                  ))),
      'AiRecommendStrip': () => const AiRecommendStripPreview(),
      'AiConsentSheet': () => DialogPreview(
          show: (context) => showAiConsentSheet(context,
              status: const AiStatusInfo(support: true, listingAssist: true, recommend: true, providersInUse: ['DeepSeek', 'Google Gemini', 'OpenAI']))),
      'AiConsentSheetSingle': () => DialogPreview(
          show: (context) => showAiConsentSheet(context, status: const AiStatusInfo(listingAssist: true, providersInUse: ['Google Gemini']))),
      'AdminDeleteBookDialog': () => DialogPreview(
          show: (context) => showAdminDeleteBookDialog(
              context, AdminBook.fromJson({'book_id': 5, 'title': longTitle, 'price': 123456, 'status': 'on_sale', 'condition_level': 'fair', 'seller': user(2)}))),
      'ImageCropLoading': () => const ImageCropScreen(sourcePath: '/nonexistent/photo.jpg', circular: true),
      'ImageCropSquare': () => const CropViewPreview(aspectRatio: 1),
      'ImageCropWide': () => const CropViewPreview(aspectRatio: 4 / 3),
      'ImageCropCircle': () => const CropViewPreview(circular: true),
    };

AiListingTargets aiAssistTargets() => AiListingTargets(
      fields: const {'title': 'Short title', 'author': '', 'publisher': 'Penguin Random House International Publishing', 'publish_date': '', 'isbn': '', 'description': ''},
      categories: [
        Category(categoryId: 1, categoryName: 'Literature & Fiction Classics', sortOrder: 0),
        Category(categoryId: 2, categoryName: 'Computer Science & Programming', sortOrder: 1),
      ],
      categoryId: 1,
      supportsCategory: true,
      supportsCondition: true,
      supportsPrice: true,
      deferConditionAndPrice: true,
    );

class AiRecommendStripPreview extends StatelessWidget {
  const AiRecommendStripPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final books = [for (var i = 1; i <= 4; i++) Book.fromJson(book(i))];
    return Scaffold(
      body: ListView(
        children: [
          DiscoveryPanel(tabs: [
            DiscoveryTab(id: 'picked', title: 'Picked for you', icon: Icons.auto_awesome_rounded, books: books, reasons: {for (final b in books) b.bookId: longReason}),
          ]),
        ],
      ),
    );
  }
}

ui.Image syntheticPhoto(int width, int height) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  canvas.drawRect(
    rect,
    Paint()..shader = const LinearGradient(colors: [Color(0xFF3A6073), Color(0xFFE8CBC0)]).createShader(rect),
  );
  for (var i = 0; i < 6; i++) {
    canvas.drawCircle(
      Offset(width * (0.15 + i * 0.14), height * (0.3 + (i % 2) * 0.35)),
      height * 0.12,
      Paint()..color = Color(0xFFFFFFFF).withValues(alpha: 0.35),
    );
  }
  return recorder.endRecording().toImageSync(width, height);
}

class CropViewPreview extends StatefulWidget {
  final double aspectRatio;
  final bool circular;

  const CropViewPreview({super.key, this.aspectRatio = 1, this.circular = false});

  @override
  State<CropViewPreview> createState() => _CropViewPreviewState();
}

class _CropViewPreviewState extends State<CropViewPreview> {
  late final ui.Image _image = syntheticPhoto(1600, 1000);

  @override
  void dispose() {
    _image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ImageCropView(image: _image, aspectRatio: widget.aspectRatio, circular: widget.circular);
}

class DialogPreview extends StatefulWidget {
  final Future<Object?> Function(BuildContext context) show;

  const DialogPreview({super.key, required this.show});

  @override
  State<DialogPreview> createState() => _DialogPreviewState();
}

class _DialogPreviewState extends State<DialogPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.show(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

class TransferCardsPreview extends StatelessWidget {
  const TransferCardsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final states = <(ChatTransfer, bool)>[
      (ChatTransfer.fromJson(chatTransfer(1)), true),
      (ChatTransfer.fromJson(chatTransfer(2, from: 2, to: 1)), false),
      (ChatTransfer.fromJson(chatTransfer(3, kind: 'request', status: 'pending', from: 1, to: 2)), false),
      (ChatTransfer.fromJson(chatTransfer(4, kind: 'request', status: 'pending', from: 2, to: 1)), true),
      (ChatTransfer.fromJson(chatTransfer(5, kind: 'request', status: 'declined')), false),
      (ChatTransfer.fromJson(chatTransfer(6, kind: 'request', status: 'cancelled')), true),
      (ChatTransfer.fromJson({...chatTransfer(7, kind: 'request', status: 'pending'), 'expires_at': '2020-01-01T00:00:00.000Z'}), false),
      (ChatTransfer.fromJson(chatTransfer(8, from: 2, to: 3)), false),
    ];
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (i, (transfer, mine)) in states.indexed)
            Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: TransferCardView(
                    transfer: transfer,
                    myId: 1,
                    isMine: mine,
                    busy: i == 3,
                    nameOf: (_) => longName,
                    onAction: (_) {},
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatAlbumsPreview extends StatelessWidget {
  const ChatAlbumsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final failed = ChatUploadSlot('/nonexistent/c.jpg')..failed.value = true;
    final uploading = ChatUploadSlot('/nonexistent/b.jpg')..progress.value = 0.4;
    final done = ChatUploadSlot('/nonexistent/a.jpg')..url = '/uploads/chat/a.jpg';
    final albums = <Widget>[
      ChatAlbumView(urls: const ['/uploads/chat/a.jpg', '/uploads/chat/b.jpg'], heroPrefix: 'a2', onOpen: (_) {}),
      ChatAlbumView(urls: const ['/a.jpg', '/b.jpg', '/c.jpg'], heroPrefix: 'a3', onOpen: (_) {}),
      ChatAlbumView(urls: [for (var i = 0; i < 12; i++) '/uploads/chat/$i.jpg'], heroPrefix: 'a12', onOpen: (_) {}),
      ChatAlbumView(urls: const [null, null, null], slots: [done, uploading, failed], heroPrefix: 'p3', onFailedTap: () {}),
    ];
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final (i, album) in albums.indexed)
            Align(
              alignment: i.isEven ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width * 0.7 > 420 ? 420 : width * 0.7), child: album),
              ),
            ),
        ],
      ),
    );
  }
}

class MentionPanelPreview extends StatefulWidget {
  const MentionPanelPreview({super.key});

  @override
  State<MentionPanelPreview> createState() => _MentionPanelPreviewState();
}

class _MentionPanelPreviewState extends State<MentionPanelPreview> {
  final _text = TextEditingController(text: '@');
  final _focus = FocusNode();
  late final _mentions = ChatMentionController(_text)
    ..enabled = true
    ..members = [
      for (var i = 2; i < 9; i++)
        ChatMentionCandidate(userId: i, name: i == 3 ? 'Study Buddy With An Extremely Long Alias' : longName, nickname: longName),
    ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _mentions.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Spacer(),
          ChatInputBar(
            controller: _text,
            focusNode: _focus,
            mentions: _mentions,
            onSend: (_) {},
            onAttach: () {},
            onToggleQuickReplies: () {},
            onVoice: (_) {},
            onVoiceUnavailable: (_) {},
            onVoiceTooShort: () {},
          ),
        ],
      ),
    );
  }
}

class SignInMethodsPreview extends StatelessWidget {
  const SignInMethodsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SignInMethodsCard(
              initialProviders: fakeProviders(),
              initialIdentities: AuthIdentityList.fromJson({
                'password_set': false,
                'identities': [
                  {'provider': 'google', 'display_name': longName, 'masked_email': 'al***@example.com', 'created_at': now, 'last_login_at': now},
                  {'provider': 'phone', 'masked_phone': '09**-***-678', 'created_at': now, 'last_login_at': now},
                ],
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class PhoneSmsCodePreview extends StatefulWidget {
  const PhoneSmsCodePreview({super.key});

  @override
  State<PhoneSmsCodePreview> createState() => _PhoneSmsCodePreviewState();
}

class _PhoneSmsCodePreviewState extends State<PhoneSmsCodePreview> {
  late final PhoneSignInController _controller = PhoneSignInController(gateway: FakeAuthGateway());

  @override
  void initState() {
    super.initState();
    // 假的 Firebase 會同步回呼，狀態在第一次 build 之前就已經是「已寄出驗證碼」。
    _controller.send('+886912345678');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SmsCodeScreen(controller: _controller);
}

const locales = [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), Locale('en'), Locale('ja'), Locale('ko')];
const sizes = [Size(360, 740), Size(390, 844)];
const wideSizes = [Size(768, 1024), Size(1180, 820), Size(1440, 900)];
const wideLocales = ['zh-Hant', 'en'];

void main() {
  final problems = <String>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    SocialAuth.gateway = FakeAuthGateway();
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== 跑版結果：${problems.length} 處 =====\n${problems.join('\n')}');
  });

  for (final locale in locales) {
    for (final size in [...sizes, if (wideLocales.contains(locale.toLanguageTag())) ...wideSizes]) {
      for (final entry in screens.entries) {
        testWidgets('${entry.key} ${locale.toLanguageTag()} ${size.width.toInt()}', (tester) async {
          ApiService.authToken = 'test-token';
          ApiService.currentUser = testUser;

          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final text = details.exceptionAsString();
            if (text.contains('overflowed')) {
              final dump = details.toString();
              if (const bool.fromEnvironment('DUMP')) debugPrint(dump);
              final where = RegExp(r'/lib/([\w/]+\.dart:\d+)').allMatches(dump).map((m) => m.group(1)).toSet().take(2).join(' ← ');
              errors.add('${text.split('\n').first} @ $where');
            } else if (!text.contains('NetworkImageLoadException') && !text.contains('HTTP request failed')) {
              if (const bool.fromEnvironment('DUMP')) debugPrint(details.toString());
              errors.add('[例外] ${text.split('\n').first}');
            }
          };

          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          await http.runWithClient(() async {
            await tester.pumpWidget(MaterialApp(
              locale: locale,
              supportedLocales: LocaleProvider.supported,
              theme: AppTheme.build(Brightness.light),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                S = AppLocalizations.of(context);
                return child ?? const SizedBox.shrink();
              },
              home: entry.value(),
            ));
            for (var i = 0; i < 8; i++) {
              await tester.pump(const Duration(milliseconds: 250));
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 3));
          }, fakeApi);

          FlutterError.onError = previous;
          for (final e in errors.toSet()) {
            problems.add('${entry.key} [${locale.toLanguageTag()} ${size.width.toInt()}] $e');
          }
          expect(errors.toSet(), isEmpty, reason: '版面溢出或元件例外');
        });
      }
    }
  }
}
