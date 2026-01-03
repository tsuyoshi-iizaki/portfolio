import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../Common/TournamentQrPayload.dart';
import '../FireBase/FireBase.dart';
import '../PropSetCofig.dart';

class TournamentConfirmPage extends StatefulWidget {
  final bool isHost;
  final String tournamentId;
  final String hostUserId;
  final String title;
  final String participantSummary;
  final int? participantLimit;
  final int? participantCountValue;
  final String format;
  final String description;
  final List<String> initialParticipants;
  final String qrPayload;

  const TournamentConfirmPage({
    Key? key,
    required this.isHost,
    required this.tournamentId,
    required this.hostUserId,
    required this.title,
    required this.participantSummary,
    this.participantLimit,
    this.participantCountValue,
    required this.format,
    required this.description,
    this.initialParticipants = const [],
    this.qrPayload = '',
  }) : super(key: key);

  @override
  State<TournamentConfirmPage> createState() => _TournamentConfirmPageState();
}

class _TournamentConfirmPageState extends State<TournamentConfirmPage> {
  late final List<_Participant> _initialParticipants;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _participantStream;
  int? _liveCount;
  List<_Participant> _cachedParticipants = [];
  bool _isConfirming = false;

  bool get _hasTournamentId => widget.tournamentId.isNotEmpty;
  int get _currentCount =>
      _liveCount ??
      widget.participantCountValue ??
      _initialParticipants.length;
  int? get _limit => widget.participantLimit;
  bool get _isFull => _limit != null && _currentCount >= _limit!;

  @override
  void initState() {
    super.initState();
    _initialParticipants = widget.initialParticipants
        .map((name) => _Participant(id: 'initial-${name.hashCode}', name: name))
        .toList();
    _cachedParticipants = List.of(_initialParticipants);
    _liveCount =
        widget.participantCountValue ?? widget.initialParticipants.length;
    if (_hasTournamentId) {
      _participantStream =
          FirestoreMethod.tournamentParticipantsSnapshot(widget.tournamentId);
    }
  }

  String get _qrValue {
    if (widget.qrPayload.isNotEmpty) return widget.qrPayload;
    if (!_hasTournamentId || widget.hostUserId.isEmpty) {
      return 'tournament:${widget.title}';
    }
    return TournamentQrPayload(
      tournamentId: widget.tournamentId,
      hostUserId: widget.hostUserId,
    ).encode();
  }

  @override
  Widget build(BuildContext context) {
    HeaderConfig().init(context, "大会確認");
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HeaderConfig.backGroundColor,
        title: HeaderConfig.appBarText,
        leading: HeaderConfig.backIcon,
      ),
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
          colors: [Color(0xFFe8f5e9), Color(0xFFc8e6c9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(),
              const SizedBox(height: 16),
              _buildInfoCard(),
              const SizedBox(height: 16),
              _buildParticipantSection(),
              const SizedBox(height: 16),
              widget.isHost
                  ? (_isFull ? _buildFullMessage() : _buildQrSection())
                  : _buildWaitingMessage(),
              const SizedBox(height: 24),
              if (widget.isHost) _buildConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final displayCount = _buildCountText(
        count: _currentCount,
        limit: _limit,
        fallbackText: widget.participantSummary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black12,
              ),
              child: Row(
                children: [
                  const Icon(Icons.grid_view, size: 16),
                  const SizedBox(width: 6),
                  Text(widget.format),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16),
                const SizedBox(width: 4),
                Text(displayCount),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF43a047), width: 0.8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '大会内容',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.description,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantSection() {
    if (_participantStream == null) {
      return _participantsCard(_initialParticipants);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _participantStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _participantsCard(_initialParticipants);
        }
        if (!snapshot.hasData) {
          return _participantsCard(_initialParticipants, isLoading: true);
        }
        final docs = snapshot.data!.docs;
        final participants = docs
            .map((doc) {
              final data = doc.data();
              final userId = (data['userId'] ?? doc.id).toString();
              final name = (data['displayName'] ?? '').toString();
              final image = (data['profileImage'] ?? '').toString();
              return _Participant(
                  id: userId,
                  name: name.isNotEmpty ? name : userId,
                  profileImage: image);
            })
            .toList();
        _cachedParticipants = participants;
        final newCount = participants.length;
        if (_liveCount != newCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _liveCount = newCount;
              });
            }
          });
        }
        return _participantsCard(participants);
      },
    );
  }

  Widget _participantsCard(List<_Participant> participants,
      {bool isLoading = false}) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF4caf50), width: 0.8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '参加者',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1b5e20)),
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (participants.isEmpty)
              const Text(
                'まだ参加者がいません',
                style: TextStyle(color: Colors.grey),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: participants
                    .map((participant) => InputChip(
                          avatar: participant.profileImage.isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(participant.profileImage),
                                )
                              : const Icon(Icons.sports_tennis,
                                  size: 18, color: Color(0xFF2e7d32)),
                          label: Text(
                            participant.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1b5e20)),
                          ),
                          backgroundColor: const Color(0xFFE8F5E9),
                          shape: StadiumBorder(
                            side: BorderSide(
                                color: const Color(0xFF66bb6a)
                                    .withValues(alpha: 0.7),
                                width: 0.5),
                          ),
                          onDeleted: widget.isHost
                              ? () => _confirmRemove(participant)
                              : null,
                          deleteIcon: widget.isHost
                              ? const Icon(Icons.close, color: Color(0xFFc62828))
                              : null,
                          deleteButtonTooltipMessage:
                              widget.isHost ? '参加者を削除' : null,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF43a047), width: 0.8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '参加確認QRコード',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1b5e20)),
            ),
            const SizedBox(height: 10),
            Center(
              child: QrImageView(
                data: _qrValue,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'このQRコードを読み込むとユーザー情報を取得し、参加者に即時反映します。',
              style: TextStyle(color: Colors.black54),
            ),
            if (_limit != null) ...[
              const SizedBox(height: 6),
              Text(
                '残り ${(_limit! - _currentCount).clamp(0, _limit!)} 人',
                style: const TextStyle(color: Color(0xFF1b5e20)),
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('主催者も参加者に追加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade100,
                foregroundColor: Colors.green.shade900,
              ),
              onPressed: () async {
                try {
                  final profile = await FirestoreMethod.getProfile();
                  await FirestoreMethod.addTournamentParticipant(
                    tournamentId: widget.tournamentId,
                    hostUserId: widget.hostUserId,
                    profile: profile,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('主催者を参加者に追加しました')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('追加に失敗しました。通信状況をご確認ください')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButtonSection() {
    // 未使用（参加者側のQR読み取りUIは非表示）
    return const SizedBox.shrink();
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isConfirming ? null : _handleConfirm,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFF1b5e20),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
        child: _isConfirming
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                '大会確定',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    final participants = _cachedParticipants.isNotEmpty
        ? List<_Participant>.from(_cachedParticipants)
        : List<_Participant>.from(_initialParticipants);
    if (participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('参加者が不足しています。2人以上で大会を開始してください。')));
      return;
    }
    Widget? nextPage;
    if (widget.format == 'リーグ戦') {
      nextPage = LeagueManagementPage(
        tournamentTitle: widget.title,
        tournamentId: widget.tournamentId,
        participants: participants,
      );
    } else if (widget.format == 'トーナメント戦') {
      nextPage = TournamentBracketPage(
        tournamentTitle: widget.title,
        tournamentId: widget.tournamentId,
        participants: participants,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('この形式は現在準備中です。リーグ戦またはトーナメント戦を選択してください。')));
      return;
    }
    setState(() => _isConfirming = true);
    try {
      if (_hasTournamentId) {
        await FirestoreMethod.tournamentsRef.doc(widget.tournamentId).set(
          {
            'status': 'ongoing',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => nextPage!));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('大会の確定に失敗しました。通信状況をご確認ください。')));
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  Widget _buildWaitingMessage() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF43a047), width: 0.8)),
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text(
          '人数が揃うまでお待ちください。',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1b5e20)),
        ),
      ),
    );
  }

  String _buildCountText(
      {int? count, int? limit, required String fallbackText}) {
    final c = count;
    if (c != null && limit != null) {
      return '$c/$limit人';
    }
    if (c != null) {
      return '$c人';
    }
    return fallbackText;
  }

  Widget _buildFullMessage() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFd32f2f), width: 0.8)),
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '募集上限に達しました',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFb71c1c)),
            ),
            SizedBox(height: 6),
            Text(
              '参加枠が上限に達したため、このQRコードは一時停止中です。',
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(_Participant participant) async {
    if (!widget.isHost) return;
    final bool? ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('参加者を削除しますか？'),
            content: Text('${participant.name} を参加者から外します。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('削除')),
            ],
          );
        });
    if (ok != true) return;
    try {
      await FirestoreMethod.tournamentParticipantsRef(widget.tournamentId)
          .doc(participant.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${participant.name} を削除しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('削除に失敗しました。もう一度お試しください。')));
      }
    }
  }
}

class _Participant {
  final String id;
  final String name;
  final String profileImage;

  const _Participant(
      {required this.id, required this.name, this.profileImage = ''});
}

class TournamentBracketPage extends StatefulWidget {
  final String tournamentTitle;
  final String tournamentId;
  final List<_Participant> participants;

  const TournamentBracketPage(
      {super.key,
      required this.tournamentTitle,
      required this.tournamentId,
      required this.participants});

  @override
  State<TournamentBracketPage> createState() => _TournamentBracketPageState();
}

class _TournamentBracketPageState extends State<TournamentBracketPage> {
  late List<List<_BracketMatch>> _rounds;
  late List<_Participant> _seedOrder;
  final Random _random = Random();
  _Participant? _champion;

  @override
  void initState() {
    super.initState();
    _seedOrder = List<_Participant>.from(widget.participants)..shuffle(_random);
    _rounds = _buildAdaptiveBracket(_seedOrder);
    _autoAdvanceByes();
  }

  @override
  Widget build(BuildContext context) {
    HeaderConfig().init(context, '${widget.tournamentTitle} トーナメント');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HeaderConfig.backGroundColor,
        title: HeaderConfig.appBarText,
        leading: HeaderConfig.backIcon,
      ),
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
          colors: [Color(0xFFe8f5e9), Color(0xFFdcedc8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildBracketBoard()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _champion != null ? _finishTournament : null,
                  icon: const Icon(Icons.emoji_events),
                  label: Text(
                      _champion != null ? '大会終了（結果発表へ）' : '全試合の勝者を決めてください'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF1b5e20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tournamentTitle,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1b5e20)),
          ),
          const SizedBox(height: 4),
          const Text(
            'ランダムシードでトーナメントを作成。スコア入力で自動的に勝者が進みます。',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildBracketBoard() {
    return LayoutBuilder(builder: (context, constraints) {
      final boardMinHeight =
          max(constraints.maxHeight, 140.0 * (_rounds.first.length / 1.3));
      final board = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
              _rounds.length, (index) => _buildRoundColumn(index)),
        ),
      );

      return InteractiveViewer(
        constrained: false,
        minScale: 0.75,
        maxScale: 1.6,
        boundaryMargin: const EdgeInsets.all(64),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: boardMinHeight),
              child: board,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildRoundColumn(int roundIndex) {
    final matches = _rounds[roundIndex];
    final gap = min(110.0, 16.0 * pow(2, roundIndex).toDouble());
    return Padding(
      padding: EdgeInsets.only(right: roundIndex == _rounds.length - 1 ? 0 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _roundBadge(_roundLabel(roundIndex)),
          const SizedBox(height: 10),
          ...List.generate(matches.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: _buildMatchCard(matches[i]),
            );
          }),
        ],
      ),
    );
  }

  Widget _roundBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFF1b5e20),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
          ]),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMatchCard(_BracketMatch match) {
    final hasResult = match.score1 != null && match.score2 != null;
    final isClickable = match.isReady;
    final borderColor =
        match.winner != null ? const Color(0xFF2e7d32) : Colors.grey.shade300;
    return GestureDetector(
      onTap: isClickable ? () => _openScoreDialog(match) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: match.winner != null
                ? [const Color(0xFFc8e6c9), const Color(0xFFaed581)]
                : [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _matchLabel(match),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1b5e20)),
                ),
                Icon(
                  isClickable ? Icons.sports_tennis : Icons.hourglass_empty,
                  color: isClickable ? const Color(0xFF2e7d32) : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildPlayerTile(match, true),
            const SizedBox(height: 8),
            _buildPlayerTile(match, false),
            const SizedBox(height: 10),
            if (hasResult)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'スコア: ${match.score1 ?? '-'} - ${match.score2 ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            else
              Text(
                isClickable ? 'タップしてスコア入力' : '相手決定を待っています',
                style: TextStyle(color: Colors.grey.shade700),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerTile(_BracketMatch match, bool isPlayer1) {
    final player = isPlayer1 ? match.player1 : match.player2;
    final hasPlayer = player != null;
    final isWinner = match.winner?.id == player?.id;
    final enableSwap = _canSwap(match) && hasPlayer;
    final content = Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor:
              isWinner ? Colors.green.shade100 : Colors.grey.shade200,
          backgroundImage: hasPlayer && player!.profileImage.isNotEmpty
              ? NetworkImage(player.profileImage)
              : null,
          child: !hasPlayer
              ? const Icon(Icons.remove, color: Colors.grey)
              : (player!.profileImage.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF2e7d32))
                  : null),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hasPlayer ? player!.name : 'シード/空き枠',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: hasPlayer ? Colors.black87 : Colors.black45),
          ),
        ),
        if (isWinner)
          const Icon(Icons.trending_flat, color: Color(0xFF2e7d32), size: 20),
      ],
    );

    return LongPressDraggable<_BracketDragData>(
      data: enableSwap
          ? _BracketDragData(match.round, match.index, isPlayer1)
          : null,
      maxSimultaneousDrags: enableSwap ? 1 : 0,
      feedback: Material(
        color: Colors.transparent,
        child: Chip(
          label: Text(
            player?.name ?? '空き枠',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF2e7d32),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: content),
      child: DragTarget<_BracketDragData>(
        onWillAccept: (data) {
          if (data == null) return false;
          if (!_isValidDrag(data)) return false;
          final targetHasPlayer =
              isPlayer1 ? match.player1 != null : match.player2 != null;
          return targetHasPlayer && _canSwap(match);
        },
        onAccept: (data) {
          _handleSwapPlayers(data, match.round, match.index, isPlayer1);
        },
        builder: (context, candidateData, rejectedData) {
          final isActive = candidateData.isNotEmpty;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isActive ? const Color(0xFF66bb6a) : Colors.transparent,
                  width: 1),
              color: isActive ? Colors.green.shade50 : Colors.transparent,
            ),
            child: content,
          );
        },
      ),
    );
  }

  String _roundLabel(int roundIndex) {
    final last = _rounds.length - 1;
    if (roundIndex == last) return '決勝';
    if (roundIndex == last - 1) return '準決勝';
    if (roundIndex == last - 2) return '準々決勝';
    return 'Round ${roundIndex + 1}';
  }

  String _matchLabel(_BracketMatch match) {
    if (_rounds.length == 1) return '決勝';
    if (match.round == _rounds.length - 1) return '決勝';
    return '第${match.round + 1}ラウンド';
  }

  Future<void> _openScoreDialog(_BracketMatch match) async {
    if (!match.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('対戦相手がまだ揃っていません。自動で決まるまでお待ちください。')));
      return;
    }
    final p1 = match.player1!;
    final p2 = match.player2!;
    final p1Controller =
        TextEditingController(text: match.score1?.toString() ?? '');
    final p2Controller =
        TextEditingController(text: match.score2?.toString() ?? '');
    String? error;

    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            scrollable: true,
            title: Text('${p1.name} vs ${p2.name}'),
            content: Padding(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: p1Controller,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: '${p1.name}のスコア'),
                    ),
                    TextField(
                      controller: p2Controller,
                      keyboardType: TextInputType.number,
                      decoration:
                          InputDecoration(labelText: '${p2.name}のスコア'),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(error!,
                            style: const TextStyle(color: Colors.red)),
                      )
                  ],
                ),
              ),
            ),
            actions: [
              if (match.score1 != null || match.score2 != null)
                TextButton(
                    onPressed: () => Navigator.of(context).pop({'clear': -1}),
                    child: const Text('結果をクリア')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル')),
              ElevatedButton(
                  onPressed: () {
                    final s1 = int.tryParse(p1Controller.text.trim());
                    final s2 = int.tryParse(p2Controller.text.trim());
                    if (s1 == null || s2 == null) {
                      setStateDialog(
                          () => error = 'スコアは数字で入力してください。');
                      return;
                    }
                    if (s1 == s2) {
                      setStateDialog(() => error = '引き分けは登録できません。');
                      return;
                    }
                    Navigator.of(context).pop({'p1': s1, 'p2': s2});
                  },
                  child: const Text('勝者を決定')),
            ],
          );
        });
      },
    );

    if (result == null) return;
    if (result.containsKey('clear')) {
      setState(() {
        match.score1 = null;
        match.score2 = null;
        match.winner = null;
      });
      _clearBranch(match);
      return;
    }
    final s1 = result['p1']!;
    final s2 = result['p2']!;
    _updateScore(match, s1, s2);
  }

  void _updateScore(_BracketMatch match, int s1, int s2) {
    setState(() {
      match.score1 = s1;
      match.score2 = s2;
      match.winner = s1 > s2 ? match.player1 : match.player2;
    });
    _propagateWinner(match);
  }

  void _propagateWinner(_BracketMatch match) {
    _Participant? winner = match.winner;
    _BracketMatch? current = match;

    while (winner != null && current != null) {
      if (current.nextMatchIndex == null) {
        setState(() => _champion = winner);
        return;
      }
      final nextRound = current.round + 1;
      if (nextRound >= _rounds.length) {
        setState(() => _champion = winner);
        return;
      }
      final targetIdx = current.nextMatchIndex!;
      if (targetIdx >= _rounds[nextRound].length) {
        setState(() => _champion = winner);
        return;
      }
      final target = _rounds[nextRound][targetIdx];
      final preferredLeft = current.nextIsPlayer1 ?? current.index.isEven;
      final bool canFillLeft =
          target.player1 == null || target.player1?.id == winner.id;
      final bool canFillRight =
          target.player2 == null || target.player2?.id == winner.id;

      bool filled = false;
      setState(() {
        if (canFillLeft && target.player1 == null) {
          target.player1 = winner;
          target.player1Pending = false;
          filled = true;
        } else if (canFillRight && target.player2 == null) {
          target.player2 = winner;
          target.player2Pending = false;
          filled = true;
        } else if (preferredLeft && canFillLeft) {
          filled = true; // already same winner on left
        } else if (!preferredLeft && canFillRight) {
          filled = true; // already same winner on right
        }

        if (filled) {
          target.score1 = null;
          target.score2 = null;
          target.winner = null;
          _champion = null;
        }
      });

      if (!filled) {
        // 両枠が他のプレイヤーで埋まっている場合は上位ラウンドへ伝播を試みる
        current = target;
        continue;
      }

      if (_isTrueBye(target)) {
        _assignByeWin(target);
      }
      return;
    }
  }

  void _clearBranch(_BracketMatch match) {
    _invalidateUpwards(match, detachFromParent: true);
  }

  void _invalidateUpwards(_BracketMatch match,
      {required bool detachFromParent}) {
    int? parentIdx = match.nextMatchIndex;
    int parentRound = match.round + 1;
    bool detach = detachFromParent;

    setState(() {
      match.score1 = null;
      match.score2 = null;
      match.winner = null;
      _champion = null;
    });

    while (parentIdx != null &&
        parentRound < _rounds.length &&
        parentIdx < _rounds[parentRound].length) {
      final parent = _rounds[parentRound][parentIdx];
      final isLeft = match.nextIsPlayer1 ?? match.index.isEven;
      setState(() {
        if (detach) {
          if (isLeft) {
            parent.player1 = null;
            parent.player1Pending = true;
          } else {
            parent.player2 = null;
            parent.player2Pending = true;
          }
        }
        parent.score1 = null;
        parent.score2 = null;
        parent.winner = null;
        _champion = null;
      });

      match = parent;
      parentIdx = match.nextMatchIndex;
      parentRound = match.round + 1;
      detach = false; // only detach the immediate parent
    }
  }

  void _assignByeWin(_BracketMatch match) {
    final winner = match.player1 ?? match.player2;
    if (winner == null) return;
    setState(() {
      match.score1 = match.player1 != null ? 1 : 0;
      match.score2 = match.player2 != null ? 0 : 1;
      match.winner = winner;
    });
    _propagateWinner(match);
  }

  void _autoAdvanceByes() {
    for (final round in _rounds) {
      for (final match in round) {
        if (_isTrueBye(match) && match.winner == null) {
          _assignByeWin(match);
        }
      }
    }
  }

  bool _isTrueBye(_BracketMatch match) {
    if (!match.isBye || !match.hasAnyPlayer) return false;
    if (match.player1 == null && match.player1Pending) return false;
    if (match.player2 == null && match.player2Pending) return false;
    return true;
  }

  List<List<_BracketMatch>> _buildBracket(List<_Participant> participants) {
    // Not used in the adaptive bracket anymore.
    return _buildAdaptiveBracket(participants);
  }

  void _finishTournament() {
    if (_champion == null) return;
    final snapshots = _rounds
        .map((round) => round
            .map((m) => _BracketMatchSnapshot(
                  round: m.round,
                  index: m.index,
                  player1: m.player1,
                  player2: m.player2,
                  score1: m.score1,
                  score2: m.score2,
                  winner: m.winner,
                ))
            .toList())
        .toList();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => KnockoutResultPage(
              title: widget.tournamentTitle,
              champion: _champion!,
              rounds: snapshots,
            )));
  }

  bool _canSwap(_BracketMatch match) => !match.hasPlayedMatch;

  bool _isValidDrag(_BracketDragData data) {
    if (_rounds.isEmpty ||
        data.roundIndex >= _rounds.length ||
        data.matchIndex >= _rounds[data.roundIndex].length) {
      return false;
    }
    final source = _rounds[data.roundIndex][data.matchIndex];
    return _canSwap(source);
  }

  void _handleSwapPlayers(_BracketDragData from, int targetRoundIndex,
      int targetMatchIndex, bool targetIsPlayer1) {
    if (_rounds.isEmpty ||
        from.roundIndex >= _rounds.length ||
        targetRoundIndex >= _rounds.length) return;
    if (from.matchIndex >= _rounds[from.roundIndex].length ||
        targetMatchIndex >= _rounds[targetRoundIndex].length) return;

    final source = _rounds[from.roundIndex][from.matchIndex];
    final target = _rounds[targetRoundIndex][targetMatchIndex];
    if (!_canSwap(source) || !_canSwap(target)) return;

    _Participant? fromPlayer =
        from.isPlayer1 ? source.player1 : source.player2;
    _Participant? targetPlayer =
        targetIsPlayer1 ? target.player1 : target.player2;
    if (fromPlayer == null || targetPlayer == null) return;

    setState(() {
      if (from.isPlayer1) {
        source.player1 = targetPlayer;
      } else {
        source.player2 = targetPlayer;
      }
      if (targetIsPlayer1) {
        target.player1 = fromPlayer;
      } else {
        target.player2 = fromPlayer;
      }
      _champion = null;
    });
    _invalidateUpwards(source, detachFromParent: true);
    _invalidateUpwards(target, detachFromParent: true);
  }

  List<_Participant> _collectRoundZeroPlayers() {
    if (_rounds.isEmpty) return [];
    final setIds = <String>{};
    final list = <_Participant>[];
    for (final m in _rounds.first) {
      for (final p in [m.player1, m.player2]) {
        if (p != null && setIds.add(p.id)) {
          list.add(p);
        }
      }
    }
    return list;
  }

  List<List<_BracketMatch>> _buildAdaptiveBracket(
      List<_Participant> participants) {
    final List<List<_BracketMatch>> rounds = [];
    final currentSlots =
        participants.map((p) => _AdvanceSlot(player: p, hadBye: false)).toList();
    _buildAdaptiveRound(rounds, currentSlots, 0);
    return rounds;
  }

  void _buildAdaptiveRound(List<List<_BracketMatch>> rounds,
      List<_AdvanceSlot> slots, int roundIndex) {
    if (slots.length <= 1) return;

    final matches = <_BracketMatch>[];
    final nextSlots = <_AdvanceSlot>[];
    final working = List<_AdvanceSlot>.from(slots);

    if (working.length.isOdd) {
      final byeIdx = _pickByeIndex(working);
      final byeSlot = working.removeAt(byeIdx);
      nextSlots.add(_AdvanceSlot(
          fromMatch: byeSlot.fromMatch,
          player: byeSlot.player,
          hadBye: true));
    }

    for (int i = 0; i + 1 < working.length; i += 2) {
      final a = working[i];
      final b = working[i + 1];
      final match = _BracketMatch(
        round: roundIndex,
        index: matches.length,
        player1Pending: a.fromMatch != null && a.player == null,
        player2Pending: b.fromMatch != null && b.player == null,
        player1: a.player,
        player2: b.player,
      );
      matches.add(match);
      if (a.fromMatch != null) {
        a.fromMatch!.nextMatchIndex = match.index;
        a.fromMatch!.nextIsPlayer1 = true;
      }
      if (b.fromMatch != null) {
        b.fromMatch!.nextMatchIndex = match.index;
        b.fromMatch!.nextIsPlayer1 = false;
      }
      nextSlots.add(_AdvanceSlot(
          fromMatch: match, hadBye: a.hadBye || b.hadBye));
    }

    rounds.add(matches);
    if (nextSlots.length <= 1) return;
    _buildAdaptiveRound(rounds, nextSlots, roundIndex + 1);
  }

  int _pickByeIndex(List<_AdvanceSlot> slots) {
    // 1st: bye未経験の枠を優先（確定プレイヤー・未確定いずれも）
    for (int i = 0; i < slots.length; i++) {
      if (!slots[i].hadBye) return i;
    }
    // 2nd: それでもなければ先頭
    return 0;
  }
}

class _BracketMatch {
  final int round;
  final int index;
  int? nextMatchIndex;
  bool? nextIsPlayer1;
  bool player1Pending;
  bool player2Pending;
  _Participant? player1;
  _Participant? player2;
  int? score1;
  int? score2;
  _Participant? winner;

  _BracketMatch(
      {required this.round,
      required this.index,
      this.player1Pending = false,
      this.player2Pending = false,
      this.player1,
      this.player2,
      this.score1,
      this.score2,
      this.winner});

  bool get isReady => player1 != null && player2 != null;
  bool get isBye =>
      (player1 != null && player2 == null) || (player1 == null && player2 != null);
  bool get hasAnyPlayer => player1 != null || player2 != null;
  bool get hasPlayedMatch =>
      score1 != null &&
      score2 != null &&
      player1 != null &&
      player2 != null &&
      !isBye;
}

class _BracketDragData {
  final int roundIndex;
  final int matchIndex;
  final bool isPlayer1;

  const _BracketDragData(this.roundIndex, this.matchIndex, this.isPlayer1);
}

class _AdvanceSlot {
  final _BracketMatch? fromMatch;
  final _Participant? player;
  final bool hadBye;

  const _AdvanceSlot({this.fromMatch, this.player, this.hadBye = false});
}

class _BracketMatchSnapshot {
  final int round;
  final int index;
  final _Participant? player1;
  final _Participant? player2;
  final int? score1;
  final int? score2;
  final _Participant? winner;

  const _BracketMatchSnapshot(
      {required this.round,
      required this.index,
      this.player1,
      this.player2,
      this.score1,
      this.score2,
      this.winner});
}

class KnockoutResultPage extends StatelessWidget {
  final String title;
  final _Participant champion;
  final List<List<_BracketMatchSnapshot>> rounds;

  const KnockoutResultPage(
      {super.key,
      required this.title,
      required this.champion,
      required this.rounds});

  @override
  Widget build(BuildContext context) {
    HeaderConfig().init(context, '$title 結果');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HeaderConfig.backGroundColor,
        title: HeaderConfig.appBarText,
        leading: HeaderConfig.backIcon,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildChampionCard(),
          const SizedBox(height: 12),
          ...rounds.asMap().entries.map((entry) {
            final roundIndex = entry.key;
            final matches = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      BorderSide(color: Colors.green.shade200, width: 0.8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_resultRoundLabel(roundIndex),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...matches.map((m) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade50,
                            foregroundColor: Colors.green.shade900,
                            child: Text('${roundIndex + 1}-${m.index + 1}'),
                          ),
                          title: Text(
                              '${m.player1?.name ?? 'シード'} vs ${m.player2?.name ?? 'シード'}'),
                          subtitle: Text(
                              m.score1 != null && m.score2 != null
                                  ? 'スコア: ${m.score1}-${m.score2}'
                                  : 'スコア未入力'),
                          trailing: m.winner != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('勝者',
                                        style: TextStyle(
                                            color: Color(0xFF2e7d32),
                                            fontWeight: FontWeight.bold)),
                                    Text(m.winner!.name),
                                  ],
                                )
                              : null,
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChampionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFF59D), Color(0xFFFFF176)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD54F)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.emoji_events,
                color: Color(0xFFF9A825), size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('優勝',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF795548))),
              Text(
                champion.name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1b5e20)),
              ),
            ],
          )
        ],
      ),
    );
  }

  String _resultRoundLabel(int roundIndex) {
    final last = rounds.length - 1;
    if (roundIndex == last) return '決勝';
    if (roundIndex == last - 1) return '準決勝';
    if (roundIndex == last - 2) return '準々決勝';
    return 'Round ${roundIndex + 1}';
  }
}

class LeagueManagementPage extends StatefulWidget {
  final String tournamentTitle;
  final String tournamentId;
  final List<_Participant> participants;

  const LeagueManagementPage(
      {super.key,
      required this.tournamentTitle,
      required this.tournamentId,
      required this.participants});

  @override
  State<LeagueManagementPage> createState() => _LeagueManagementPageState();
}

class _LeagueManagementPageState extends State<LeagueManagementPage> {
  late List<_LeagueBlock> _blocks;
  late List<_LeagueMatch> _matches;
  final Random _random = Random();

  bool get _hasThinBlock =>
      _blocks.length > 1 && _blocks.any((b) => b.players.length < 2);
  bool get _allResultsFilled =>
      _matches.isNotEmpty && _matches.every((m) => m.isCompleted);
  bool get _canFinish => _allResultsFilled && !_hasThinBlock;

  @override
  void initState() {
    super.initState();
    _blocks = _buildInitialBlocks(List.of(widget.participants));
    _matches = _generateMatches(_blocks);
  }

  @override
  Widget build(BuildContext context) {
    HeaderConfig().init(context, '${widget.tournamentTitle} 進行');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HeaderConfig.backGroundColor,
        title: HeaderConfig.appBarText,
        leading: HeaderConfig.backIcon,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.tournamentId.isNotEmpty) ...[
              Text('大会ID: ${widget.tournamentId}',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
            ],
            _buildBlockSection(),
            const SizedBox(height: 12),
            if (_hasThinBlock)
              const Text(
                '各ブロック2人以上になるように調整してください（1人のみのブロックは作成しません）。',
                style: TextStyle(color: Colors.redAccent),
              ),
            const SizedBox(height: 12),
            _buildMatchSection(),
            const SizedBox(height: 24),
            _buildFinishButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ブロック振り分け（ランダム作成済み）',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 6),
        const Text('長押しでドラッグ&ドロップするとブロック間で入れ替えできます。'),
        const SizedBox(height: 2),
        const Text(
          '入れ替え後は対戦カードも自動で更新されます（スコアは再入力が必要です）。',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ...List.generate(_blocks.length, (index) => _buildBlockCard(index)),
      ],
    );
  }

  Widget _buildBlockCard(int blockIndex) {
    final block = _blocks[blockIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF4caf50), width: 0.8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  block.name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1b5e20)),
                ),
                Text('${block.players.length}人'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                block.players.length,
                (playerIndex) =>
                    _buildDraggableChip(blockIndex, playerIndex, block),
              ),
            ),
            const SizedBox(height: 10),
            DragTarget<_DragData>(
              onWillAccept: (_) => true,
              onAccept: (data) => _moveToBlock(data, blockIndex),
              builder: (context, candidateData, rejectedData) {
                final isActive = candidateData.isNotEmpty;
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            isActive ? Colors.green : Colors.grey.shade400,
                        style: BorderStyle.solid),
                    color: isActive
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                  ),
                  child: Text(
                    'ここにドロップで${block.name}へ移動',
                    style: TextStyle(
                        color: isActive ? Colors.green.shade800 : Colors.black),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableChip(
      int blockIndex, int playerIndex, _LeagueBlock block) {
    final player = block.players[playerIndex];
    return LongPressDraggable<_DragData>(
      data: _DragData(blockIndex, playerIndex),
      feedback: Material(
        color: Colors.transparent,
        child: Chip(
          label: Text(player.name,
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildChipContent(player, isHighlighted: true),
      ),
      child: DragTarget<_DragData>(
        onWillAccept: (_) => true,
        onAccept: (data) => _swapPlayers(data, blockIndex, playerIndex),
        builder: (context, candidateData, rejectedData) {
          final isActive = candidateData.isNotEmpty;
          return _buildChipContent(player, isHighlighted: isActive);
        },
      ),
    );
  }

  Widget _buildChipContent(_Participant player, {bool isHighlighted = false}) {
    return InputChip(
      label: Text(
        player.name,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isHighlighted ? Colors.green.shade900 : Colors.black87),
      ),
      avatar: player.profileImage.isNotEmpty
          ? CircleAvatar(backgroundImage: NetworkImage(player.profileImage))
          : const Icon(Icons.person, size: 18, color: Color(0xFF2e7d32)),
      backgroundColor: isHighlighted
          ? Colors.green.shade50
          : const Color(0xFFE8F5E9),
    );
  }

  Widget _buildMatchSection() {
    final grouped = _groupedMatches();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '対戦カード',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (_matches.isEmpty)
          const Text('対戦カードを作成できませんでした。参加者数を確認してください。'),
        ...grouped.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF1b5e20)),
                    ),
                  ),
                  ...entry.value.map((m) => ListTile(
                        onTap: () => _editScore(m),
                        title: Text('${m.player1.name} vs ${m.player2.name}'),
                        subtitle: Text(m.isCompleted
                            ? 'スコア: ${m.score1} - ${m.score2}'
                            : 'タップしてスコア入力'),
                        trailing: Icon(
                          m.isCompleted ? Icons.check_circle : Icons.edit,
                          color: m.isCompleted
                              ? Colors.green
                              : Colors.grey.shade400,
                        ),
                      )),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFinishButton() {
    final label = _canFinish ? '大会終了（結果発表へ）' : '全ての対戦結果を入力してください';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canFinish ? _finishTournament : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFF1b5e20),
          foregroundColor: Colors.white,
        ),
        child: Text(label),
      ),
    );
  }

  List<_LeagueBlock> _buildInitialBlocks(List<_Participant> participants) {
    final players = List<_Participant>.from(participants)..shuffle(_random);
    final blockSizes = _decideBlockSizes(players.length);
    final List<_LeagueBlock> blocks = [];
    int cursor = 0;
    for (int i = 0; i < blockSizes.length; i++) {
      final size = blockSizes[i];
      final end = min(cursor + size, players.length);
      final chunk = players.sublist(cursor, end);
      blocks.add(_LeagueBlock(name: _blockLabel(i), players: chunk));
      cursor = end;
    }
    return blocks;
  }

  List<int> _decideBlockSizes(int count) {
    if (count <= 5) {
      return [count];
    }
    final sizes = <int>[];
    int remaining = count;
    while (remaining > 0) {
      if (remaining == 5) {
        if (sizes.isEmpty) {
          sizes.add(5);
        } else {
          sizes.addAll([3, 2]);
        }
        break;
      }
      if (remaining == 6) {
        sizes.addAll([3, 3]);
        break;
      }
      if (remaining == 7) {
        sizes.addAll([4, 3]);
        break;
      }
      if (remaining <= 4) {
        sizes.add(remaining);
        break;
      }
      if (remaining % 4 == 1) {
        sizes.add(3);
        remaining -= 3;
      } else {
        sizes.add(4);
        remaining -= 4;
      }
    }
    return sizes;
  }

  List<_LeagueMatch> _generateMatches(List<_LeagueBlock> blocks) {
    final List<_LeagueMatch> matches = [];
    for (final block in blocks) {
      final players = block.players;
      for (int i = 0; i < players.length; i++) {
        for (int j = i + 1; j < players.length; j++) {
          matches.add(_LeagueMatch(
              blockName: block.name,
              player1: players[i],
              player2: players[j]));
        }
      }
    }
    return matches;
  }

  Map<String, List<_LeagueMatch>> _groupedMatches() {
    final Map<String, List<_LeagueMatch>> grouped = {};
    for (final match in _matches) {
      grouped.putIfAbsent(match.blockName, () => []).add(match);
    }
    return grouped;
  }

  String _blockLabel(int index) {
    final charCode = 'A'.codeUnitAt(0) + index;
    return '${String.fromCharCode(charCode)}ブロック';
  }

  void _swapPlayers(_DragData data, int targetBlockIndex, int targetIndex) {
    if (data.blockIndex >= _blocks.length ||
        targetBlockIndex >= _blocks.length) {
      return;
    }
    final fromBlock = _blocks[data.blockIndex];
    final toBlock = _blocks[targetBlockIndex];
    if (data.playerIndex >= fromBlock.players.length ||
        targetIndex >= toBlock.players.length) return;

    setState(() {
      final swappedPlayer = fromBlock.players[data.playerIndex];
      fromBlock.players[data.playerIndex] = toBlock.players[targetIndex];
      toBlock.players[targetIndex] = swappedPlayer;
      _matches = _generateMatches(_blocks);
    });
  }

  void _moveToBlock(_DragData data, int targetBlockIndex) {
    if (data.blockIndex >= _blocks.length ||
        targetBlockIndex >= _blocks.length) return;
    if (data.blockIndex == targetBlockIndex) return;
    final fromBlock = _blocks[data.blockIndex];
    if (data.playerIndex >= fromBlock.players.length) return;
    if (fromBlock.players.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ブロックの人数が1人にならないように調整してください')));
      return;
    }
    final movingPlayer = fromBlock.players[data.playerIndex];

    setState(() {
      fromBlock.players.removeAt(data.playerIndex);
      _blocks[targetBlockIndex].players.add(movingPlayer);
      _matches = _generateMatches(_blocks);
    });
  }

  Future<void> _editScore(_LeagueMatch match) async {
    final p1Controller =
        TextEditingController(text: match.score1?.toString() ?? '');
    final p2Controller =
        TextEditingController(text: match.score2?.toString() ?? '');
    String? error;

    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            scrollable: true,
            title: Text('${match.player1.name} vs ${match.player2.name}'),
            content: Padding(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: p1Controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: '${match.player1.name}のスコア'),
                    ),
                    TextField(
                      controller: p2Controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: '${match.player2.name}のスコア'),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル')),
              ElevatedButton(
                  onPressed: () {
                    final s1 = int.tryParse(p1Controller.text.trim());
                    final s2 = int.tryParse(p2Controller.text.trim());
                    if (s1 == null || s2 == null) {
                      setStateDialog(
                          () => error = 'スコアは数字で入力してください。');
                      return;
                    }
                    Navigator.of(context).pop({'p1': s1, 'p2': s2});
                  },
                  child: const Text('入力完了')),
            ],
          );
        });
      },
    );

    if (result == null) return;
    setState(() {
      match.score1 = result['p1'];
      match.score2 = result['p2'];
    });
  }

  void _finishTournament() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TournamentResultPage(
              title: widget.tournamentTitle,
              blocks: _blocks,
              matches: _matches,
            )));
  }
}

class _LeagueBlock {
  final String name;
  final List<_Participant> players;

  _LeagueBlock({required this.name, required this.players});
}

class _LeagueMatch {
  final String blockName;
  final _Participant player1;
  final _Participant player2;
  int? score1;
  int? score2;

  _LeagueMatch(
      {required this.blockName,
      required this.player1,
      required this.player2,
      this.score1,
      this.score2});

  bool get isCompleted => score1 != null && score2 != null;
}

class _DragData {
  final int blockIndex;
  final int playerIndex;

  const _DragData(this.blockIndex, this.playerIndex);
}

class TournamentResultPage extends StatelessWidget {
  final String title;
  final List<_LeagueBlock> blocks;
  final List<_LeagueMatch> matches;

  const TournamentResultPage(
      {super.key,
      required this.title,
      required this.blocks,
      required this.matches});

  @override
  Widget build(BuildContext context) {
    final standings = _buildStandings();
    HeaderConfig().init(context, '$title 結果');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HeaderConfig.backGroundColor,
        title: HeaderConfig.appBarText,
        leading: HeaderConfig.backIcon,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '結果発表（仮）',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('スコア入力済みの結果を元に暫定順位を表示しています。'),
          const SizedBox(height: 16),
          ...standings.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...entry.value.map((s) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Text(
                              s.rank.toString(),
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                          title: Text(s.player.name),
                          subtitle: Text(
                              '勝ち:${s.wins} / 負け:${s.losses} / 試合数:${s.played} / 得失点:${s.pointDiff}'),
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Map<String, List<_StandingRow>> _buildStandings() {
    final Map<String, List<_StandingRow>> result = {};
    for (final block in blocks) {
      final map = {for (final p in block.players) p.id: _StandingRow(player: p)};
      for (final match in matches.where((m) => m.blockName == block.name)) {
        if (!match.isCompleted) continue;
        final s1 = map[match.player1.id];
        final s2 = map[match.player2.id];
        if (s1 == null || s2 == null) continue;
        s1.played++;
        s2.played++;
        s1.pointDiff += (match.score1 ?? 0) - (match.score2 ?? 0);
        s2.pointDiff += (match.score2 ?? 0) - (match.score1 ?? 0);
        if ((match.score1 ?? 0) > (match.score2 ?? 0)) {
          s1.wins++;
          s2.losses++;
        } else if ((match.score1 ?? 0) < (match.score2 ?? 0)) {
          s2.wins++;
          s1.losses++;
        }
      }
      final list = map.values.toList()
        ..sort((a, b) {
          if (b.wins != a.wins) return b.wins.compareTo(a.wins);
          if (b.pointDiff != a.pointDiff) {
            return b.pointDiff.compareTo(a.pointDiff);
          }
          return a.player.name.compareTo(b.player.name);
        });
      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
      }
      result[block.name] = list;
    }
    return result;
  }
}

class _StandingRow {
  final _Participant player;
  int wins = 0;
  int losses = 0;
  int played = 0;
  int pointDiff = 0;
  int rank = 0;

  _StandingRow({required this.player});
}
