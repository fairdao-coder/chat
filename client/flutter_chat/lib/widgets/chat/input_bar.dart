import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'action_item.dart';
import 'emoji_set.dart';

/// 聊天页底栏：语音入口、输入框、表情面板、更多面板，以及录音态操作条。
///
/// 录音的**状态**（是否正在录、秒数）由页面持有，这里只负责渲染与回调，
/// 避免同一份状态分散在两处。
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final VoidCallback onFile;
  final bool uploading;
  final bool recording;
  final int recordSeconds;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordStop;
  final VoidCallback? onRecordCancel;

  /// 是否允许发送文件（含图片），由后台开关控制。
  final bool allowFile;

  /// 是否允许发送语音消息，由后台开关控制。
  final bool allowVoice;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onImage,
    required this.onFile,
    required this.uploading,
    this.recording = false,
    this.recordSeconds = 0,
    this.onRecordStart,
    this.onRecordStop,
    this.onRecordCancel,
    this.allowFile = true,
    this.allowVoice = true,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focus;

  /// 录音状态动画：红点呼吸 + 波形律动。
  late AnimationController _pulse;
  var _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onTextChanged);
    _focus = FocusNode();
    _focus.addListener(_onFocusChanged);
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      _controller = widget.controller;
      _controller.addListener(_onTextChanged);
      _hasText = _controller.text.trim().isNotEmpty;
    }
    if (widget.recording) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      if (_pulse.isAnimating) _pulse.stop();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final v = _controller.text.trim().isNotEmpty;
    if (v != _hasText) setState(() => _hasText = v);
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    final newText = text.replaceRange(sel.start, sel.end, emoji);
    final newSel = TextSelection.collapsed(offset: sel.start + emoji.length);
    _controller.value = TextEditingValue(text: newText, selection: newSel);
  }

  void _showPlusSheet() {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? cs.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('更多'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChatActionItem(
                      icon: Icons.image_outlined,
                      label: context.tr('图片'),
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.of(c).pop();
                        widget.onImage();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChatActionItem(
                      icon: Icons.attach_file_outlined,
                      label: context.tr('文件'),
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.of(c).pop();
                        widget.onFile();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiSheet() {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark ? cs.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: 316,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Text(
                      context.tr('常用表情'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    // 退格：支持 emoji 代理对，点击后面板保持打开，可连续输入。
                    IconButton(
                      tooltip: context.tr('删除'),
                      icon: const Icon(Icons.backspace_outlined, size: 20),
                      onPressed: _backspace,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: kCommonEmojis.length,
                  itemBuilder: (c, i) => InkWell(
                    onTap: () => _insertEmoji(kCommonEmojis[i]),
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: Text(kCommonEmojis[i],
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 删除光标前的一个字符（正确处理 emoji 代理对）。
  void _backspace() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final sel = _controller.selection;
    final end =
        (sel.end >= 0 && sel.end <= text.length) ? sel.end : text.length;
    var start =
        (sel.start >= 0 && sel.start <= text.length) ? sel.start : text.length;
    if (start == end) {
      if (start == 0) return;
      start--;
      // 高位代理项（emoji 占两个 code unit），再退一格整体删除。
      if (start > 0 &&
          text.codeUnitAt(start) >= 0xD800 &&
          text.codeUnitAt(start) <= 0xDBFF) {
        start--;
      }
    }
    final newText = text.replaceRange(start, end, '');
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // 录音模式：整条切换为录音操作面板（取消 / 状态 / 完成）。
    if (widget.recording) {
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: dark ? cs.surface : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: _buildRecordingRow(cs),
        ),
      );
    }

    final busy = widget.uploading;
    // 上传中固定显示发送态（内含进度圈），其余时刻按有无文本切换 发送/更多。
    final rightChild = widget.uploading
        ? _buildSendButton(context, cs, key: const ValueKey('send'))
        : _hasText
            ? _buildSendButton(context, cs, key: const ValueKey('send'))
            : (widget.allowFile
                ? IconAction(
                    key: const ValueKey('plus'),
                    icon: Icons.add_circle_outline_rounded,
                    tooltip: context.tr('更多'),
                    onTap: busy ? null : _showPlusSheet,
                  )
                : const SizedBox.shrink(key: ValueKey('none')));

    return SafeArea(
      top: false,
      child: Container(
        // 微信风格浅灰底栏，顶部 0.5 细线分隔，无阴影。
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF121212) : const Color(0xFFF7F7F7),
          border: Border(
            top: BorderSide(
              color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFD9D9D9),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 语音（受后台「允许发送语音」开关控制）
              if (widget.allowVoice)
                IconAction(
                  icon: Icons.mic_none_rounded,
                  tooltip: context.tr('语音'),
                  onTap: busy ? null : widget.onRecordStart,
                ),
              // 输入框（白底浅灰边框，小圆角，高度充足）
              Expanded(child: _buildInputPill(cs, dark)),
              // 表情
              IconAction(
                icon: Icons.emoji_emotions_outlined,
                tooltip: context.tr('表情'),
                onTap: busy ? null : _showEmojiSheet,
              ),
              // 发送 / 更多（平滑切换）
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: rightChild,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 微信风格输入框：白底、浅灰细边框、小圆角、高度 46，文字/光标垂直居中。
  Widget _buildInputPill(ColorScheme cs, bool dark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minHeight: 28, maxHeight: 40),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E5E5),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.send,
        minLines: 1,
        maxLines: 5,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: AppColors.brand,
        style: TextStyle(
          fontSize: 14,
          height: 1.2,
          color: dark ? Colors.white : const Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          hintText: context.tr('输入消息…'),
          hintStyle: TextStyle(
            color: dark ? const Color(0xFF888888) : const Color(0xFFB3B3B3),
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          isCollapsed: true,
        ),
        onSubmitted: (_) => widget.onSend(),
      ),
    );
  }

  /// 微信风格发送按钮：有文字时绿色小圆角矩形「发送」，上传中显示进度圈。
  Widget _buildSendButton(BuildContext context, ColorScheme cs, {Key? key}) {
    return Material(
      key: key,
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: widget.uploading ? null : widget.onSend,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: widget.uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  context.tr('发送'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  /// 录音面板：呼吸红点 + 律动波形 + 秒数，左取消 / 右完成。
  Widget _buildRecordingRow(ColorScheme cs) {
    return Row(
      children: [
        TextButton(
          onPressed: widget.onRecordCancel,
          style: TextButton.styleFrom(
            foregroundColor: cs.error,
            minimumSize: const Size(52, 40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(context.tr('取消'), style: const TextStyle(fontSize: 14)),
        ),
        Expanded(
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value * 2 * math.pi;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t)),
                      child: const Icon(Icons.fiber_manual_record,
                          color: Colors.red, size: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${context.tr('正在录音')} ${widget.recordSeconds}″',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 10),
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 3,
                        height: 6 + 8 * (0.5 + 0.5 * math.sin(t + i * 1.1)),
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        Material(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onRecordStop,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: Text(
                context.tr('完成'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
