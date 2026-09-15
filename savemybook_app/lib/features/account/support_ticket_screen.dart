import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/support.dart';
import '../../services/ai_status.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/responsive.dart';
import '../../widgets/guards.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../utils/app_labels.dart';
import '../../utils/motion.dart';
import '../../i18n/strings.dart';
import 'ai_support_entry.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final ApiService _api = ApiService();
  List<SupportTicket> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    AiStatus.refresh();
  }

  Future<void> _load() async {
    final tickets = await _api.fetchMyTickets();
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _isLoading = false;
    });
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewTicketScreen()),
    );
    if (created == true && mounted) _load();
  }

  Future<void> _open(SupportTicket ticket) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticket.ticketId)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: Text(S.askQuestion),
      ),
      body: Column(
        children: [
          AppHeader(title: S.contactUs, icon: Icons.support_agent_rounded),
          const AiSupportEntry(maxWidth: Breakpoints.readingMaxWidth, horizontal: 20),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _tickets.isEmpty
                          ? ListView(
                              key: const ValueKey('empty'),
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.support_agent_rounded,
                                  message: S.noEnquiriesYet,
                                ),
                              ],
                            )
                          : LayoutBuilder(builder: (context, constraints) => ListView.builder(
                              key: const ValueKey('items'),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: 20, top: 16, bottom: 96),
                              itemCount: _tickets.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_tickets[i], c),
                              ),
                            ))),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(SupportTicket ticket, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _open(ticket),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: ticket.statusText, color: c.ticketStatusColor(ticket.status)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ticket.lastMessage ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.forum_outlined, size: 13, color: c.textHint),
              const SizedBox(width: 4),
              Text('${ticket.messageCount}', style: TextStyle(fontSize: 11, color: c.textHint)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ticket.categoryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
              const SizedBox(width: 8),
              Text(formatRelative(ticket.updatedAt), style: TextStyle(fontSize: 11, color: c.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}

class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _category = 'other';
  bool _isSaving = false;
  bool _showErrors = false;
  bool _sent = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    final subject = _subjectController.text.trim();
    final content = _contentController.text.trim();
    setState(() => _showErrors = true);

    if (subject.isEmpty) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.enterSubject, isError: true);
      return;
    }
    if (content.length < 5) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.addMoreDetailSoSupportCan, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final error = await _api.createTicket(
      subject: subject,
      category: _category,
      content: content,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    _sent = true;
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, S.sentSupportReplySoon);
    Navigator.pop(context, true);
  }

  bool get _isDirty =>
      !_sent && (_subjectController.text.trim().isNotEmpty || _contentController.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return UnsavedGuard(
      isDirty: _isDirty && !_isSaving,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(title: S.askQuestion, icon: Icons.edit_outlined),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: LayoutBuilder(builder: (context, constraints) => ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: responsiveListPadding(constraints, maxWidth: Breakpoints.formMaxWidth, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 40),
                  children: [
                    FadeSlideIn(
                      child: FormRowCard(
                        label: S.type,
                        child: AppSelect<String>(
                          value: _category,
                          title: S.type,
                          options: [
                            for (final e in AppLabels.ticketCategory.entries)
                              AppSelectOption(value: e.key, label: e.value, icon: _categoryIcon(e.key)),
                          ],
                          onChanged: _isSaving ? null : (value) => setState(() => _category = value),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      index: 1,
                      child: FormRowCard(
                        label: S.subject,
                        isRequired: true,
                        child: AppTextField(
                          controller: _subjectController,
                          hint: S.sumUpOneLine,
                          maxLength: 100,
                          enabled: !_isSaving,
                          textInputAction: TextInputAction.next,
                          errorText: _showErrors && _subjectController.text.trim().isEmpty ? S.enterSubject : null,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      index: 2,
                      child: FormRowCard(
                        label: S.content,
                        alignTop: true,
                        isRequired: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AppTextField(
                              controller: _contentController,
                              hint: S.whatHappenedIncludeOrderNumberIf,
                              minLines: 5,
                              maxLines: 10,
                              maxLength: 1000,
                              enabled: !_isSaving,
                              keyboardType: TextInputType.multiline,
                              errorText: _showErrors && _contentController.text.trim().length < 5
                                  ? S.addMoreDetailSoSupportCan
                                  : null,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_contentController.text.characters.length}/1000',
                              style: TextStyle(fontSize: 11, color: c.textHint),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: S.actionSubmit,
                      icon: Icons.send_rounded,
                      height: 50,
                      isLoading: _isSaving,
                      onPressed: _submit,
                    ),
                  ],
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(String key) {
    switch (key) {
      case 'account':
        return Icons.person_outline_rounded;
      case 'trade':
        return Icons.swap_horiz_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_outlined;
      case 'cabinet':
        return Icons.inventory_2_outlined;
      case 'bug':
        return Icons.bug_report_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;

  final bool asAdmin;

  const TicketDetailScreen({super.key, required this.ticketId, this.asAdmin = false});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  SupportTicket? _ticket;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ticket = await _api.fetchTicket(widget.ticketId);
    if (!mounted) return;
    setState(() {
      _ticket = ticket;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final error = await _api.replyTicket(widget.ticketId, text);
    if (!mounted) return;
    setState(() => _isSending = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    HapticFeedback.lightImpact();
    _controller.clear();
    await _load();
  }

  Future<void> _close() async {
    final ok = await showConfirmDialog(
      context,
      title: S.close,
      message: S.notAbleReplyAfterClosing,
      confirmLabel: S.close,
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    final error = await runBusy(context, () => _api.closeTicket(widget.ticketId));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.enquiryClosed);
      _load();
    }
  }

  Future<void> _changeStatus() async {
    final c = AppColors.of(context);
    final status = await showAppPicker<String>(
      context,
      title: S.changeStatus,
      selected: _ticket?.status,
      options: [
        for (final e in AppLabels.ticketStatus.entries)
          AppSelectOption(
            value: e.key,
            label: e.value,
            icon: Icons.circle,
            iconColor: c.ticketStatusColor(e.key),
          ),
      ],
    );
    if (status == null || status == _ticket?.status || !mounted) return;

    final error = await runBusy(context, () => _api.updateTicketStatus(widget.ticketId, status));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.statusUpdated);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ticket = _ticket;
    final canReply = ticket != null && !ticket.isClosed;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: ticket?.subject ?? S.enquiry,
            icon: Icons.support_agent_rounded,
            actions: [
              if (widget.asAdmin)
                HeaderIconButton(icon: Icons.tune_rounded, onTap: _changeStatus)
              else if (canReply)
                HeaderIconButton(icon: Icons.check_circle_outline_rounded, onTap: _close),
            ],
          ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : ticket == null
                      ? EmptyView(
                          icon: Icons.support_agent_rounded,
                          message: S.enquiryNotFound,
                        )
                      : LayoutBuilder(builder: (context, constraints) => ListView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          controller: _scrollController,
                          padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: 20, top: 16, bottom: 16),
                          children: [
                            _buildMeta(ticket, c),
                            const SizedBox(height: 16),
                            for (var i = 0; i < ticket.messages.length; i++)
                              FadeSlideIn(
                                index: i,
                                offsetY: 10,
                                stagger: const Duration(milliseconds: 24),
                                child: _buildMessage(ticket.messages[i], c),
                              ),
                          ],
                        )),
            ),
          ),
          if (canReply) _buildInputBar(c),
        ],
      ),
    );
  }

  Widget _buildMeta(SupportTicket ticket, AppColors c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          StatusBadge(
            label: ticket.statusText,
            color: ticket.isClosed ? c.iconInactive : c.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(ticket.categoryText, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ),
          if (widget.asAdmin && ticket.userName.isNotEmpty)
            Flexible(
              child: Text(ticket.userName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _buildMessage(TicketMessage message, AppColors c) {
    final isMine = !message.isStaff;
    final alignRight = widget.asAdmin ? message.isStaff : isMine;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!alignRight) ...[
                UserAvatar(imageUrl: message.senderAvatar, radius: 14),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(MediaQuery.of(context).size.width, Breakpoints.readingMaxWidth) * 0.7,
                  ),
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.standard,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: alignRight ? c.accent : c.card,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(alignRight ? 14 : 4),
                        bottomRight: Radius.circular(alignRight ? 4 : 14),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: alignRight ? Colors.white : c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: alignRight ? 0 : 36,
              right: alignRight ? 2 : 0,
              top: 4,
            ),
            child: Text(
              '${message.isStaff ? S.support : message.senderName}・${formatRelative(message.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: c.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AppColors c) {
    return ResponsiveListPadding(
      maxWidth: Breakpoints.readingMaxWidth,
      top: 10,
      bottom: MediaQuery.of(context).padding.bottom + 10,
      builder: (context, padding) => _buildInputBarBody(c, padding),
    );
  }

  Widget _buildInputBarBody(AppColors c, EdgeInsets padding) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _controller,
              hint: S.writeReply,
              maxLines: 4,
              maxLength: 1000,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (_, value, _) {
              final ready = value.text.trim().isNotEmpty && !_isSending;
              return PressableScale(
                onTap: ready ? _send : null,
                child: AnimatedContainer(
                  duration: Motion.micro,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ready || _isSending ? c.accent : c.accent.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
