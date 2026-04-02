import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/liquid_ui.dart';
import '../providers/onboarding_provider.dart';
import '../providers/routine_provider.dart';
import '../services/gemini_service.dart';
import '../widgets/animated_bot_avatar.dart';

class _Message {
  final String text;
  final bool isUser;
  _Message(this.text, {required this.isUser});
}

class CoachTab extends ConsumerStatefulWidget {
  const CoachTab({super.key});

  @override
  ConsumerState<CoachTab> createState() => _CoachTabState();
}

class _CoachTabState extends ConsumerState<CoachTab> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  
  late final GeminiChatSession _chatSession;
  final List<_Message> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _initChat() {
    final onboard = ref.read(onboardingProvider);
    final routine = ref.read(routineProvider);

    final sb = StringBuffer();
    sb.writeln('You are an elite productivity AI coach for the Optivus app.');
    sb.writeln('Coach Style: ${onboard.coachStyle}');
    sb.writeln('Accountability: ${onboard.accountabilityType}');
    
    if (onboard.goals.isNotEmpty) {
      sb.writeln('User Goals: ${onboard.goals.join(', ')}');
    }
    if (onboard.goodHabits.isNotEmpty) {
      sb.writeln('Good Habits (Building): ${onboard.goodHabits.join(', ')}');
    }
    if (onboard.badHabits.isNotEmpty) {
      sb.writeln('Bad Habits (Breaking): ${onboard.badHabits.join(', ')}');
    }
    if (routine.fixedBlocks.isNotEmpty) {
      final schedule = routine.fixedBlocks.map((b) => '${b.title} (${b.startLabel}-${b.endLabel})').join(', ');
      sb.writeln('User Fixed Schedule: $schedule');
    }

    _chatSession = GeminiService().startChat(sb.toString());

    final userName = onboard.coachName.isNotEmpty ? onboard.coachName : 'there';
    setState(() {
      _messages.add(_Message("Hey $userName! I've looked at your schedule. What would you like to work on today?", isUser: false));
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_Message(text, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(text);
      if (mounted) {
        setState(() {
          _messages.add(_Message(response, isUser: false));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_Message("I'm sorry, I'm having trouble connecting right now. Please try again later.", isUser: false));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                const AnimatedBotAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Optivus Coach',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: kPurple,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Your personal AI coach',
                        style: TextStyle(
                          fontSize: 14,
                          color: kSub.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Message List
        Expanded(
          child: ListView.separated(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(24),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isTyping) {
                return _buildTypingIndicator();
              }
              final msg = _messages[index];
              return _buildMessageBubble(msg);
            },
          ),
        ),

        // Input Area
        Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 100),
          decoration: BoxDecoration(
            color: kWhite.withValues(alpha: 0.5),
            border: Border(top: BorderSide(color: kWhite.withValues(alpha: 0.7), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: LiquidTextField(
                  hint: 'Message coach...',
                  controller: _inputCtrl,
                  keyboardType: TextInputType.multiline,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: kPurple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kPurple.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: kWhite, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(_Message msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: kAmber,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: kWhite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      );
    } else {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          child: LiquidCard.solid(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            radius: 20,
            child: Text(
              msg.text,
              style: const TextStyle(
                color: kInk,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: LiquidCard.solid(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        radius: 20,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _AnimatedDot(delay: 0),
            SizedBox(width: 4),
            _AnimatedDot(delay: 200),
            SizedBox(width: 4),
            _AnimatedDot(delay: 400),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.2, end: 1.0).animate(_ctrl),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: kSub.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
