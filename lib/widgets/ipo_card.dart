import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ipo.dart';
import '../utils/currency_formatter.dart';
import 'subscription_breakdown_sheet.dart';

class IpoCard extends StatelessWidget {
  final Ipo ipo;
  final int appliedCount;
  final int totalSyndicateAccounts;
  final VoidCallback onApply;
  final VoidCallback? onCheckAllotment;
  final VoidCallback? onViewApplications;
  final VoidCallback? onTap;
  final void Function(double? newGmp, bool isCustom)? onEditGmp;
  final bool isWatchlisted;
  final VoidCallback? onToggleWatchlist;
  final VoidCallback? onShowSubscription;

  const IpoCard({
    super.key,
    required this.ipo,
    required this.appliedCount,
    this.totalSyndicateAccounts = 1,
    required this.onApply,
    this.onCheckAllotment,
    this.onViewApplications,
    this.onTap,
    this.onEditGmp,
    this.isWatchlisted = false,
    this.onToggleWatchlist,
    this.onShowSubscription,
  });

  Color _getAvatarColor(String symbol) {
    final colors = [
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF2E7D32), // Green
      const Color(0xFF7B1FA2), // Purple
      const Color(0xFFC2185B), // Pink
      const Color(0xFFE65100), // Orange
      const Color(0xFF00838F), // Cyan
      const Color(0xFF283593), // Indigo
      const Color(0xFF455A64), // Blue Grey
    ];
    return colors[symbol.hashCode.abs() % colors.length];
  }

  String _getInitials(String symbol, String name) {
    if (symbol.isNotEmpty && symbol.length >= 2) {
      return symbol.substring(0, 2).toUpperCase();
    }
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return symbol.isNotEmpty ? symbol[0].toUpperCase() : 'IP';
  }

  Widget _buildStatusPill(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (ipo.isListed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B382B) : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.teal.shade700 : Colors.teal.shade400),
        ),
        child: Text(
          'LISTED',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
          ),
        ),
      );
    }

    if (ipo.isAllotmentOut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2B38) : Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.indigo.shade700 : Colors.indigo.shade300),
        ),
        child: Text(
          'ALLOTTED',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.indigo.shade300 : Colors.indigo.shade800,
          ),
        ),
      );
    }

    if (ipo.isClosed) {
      final localAllotment = ipo.allotmentDate.toLocal();
      final allotmentDay = DateTime(localAllotment.year, localAllotment.month, localAllotment.day);
      final today = DateTime(now.year, now.month, now.day);
      final isAllotmentToday = allotmentDay.isAtSameMomentAs(today);

      if (isAllotmentToday) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF231E3D) : Colors.purple.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.purple.shade700 : Colors.purple.shade300),
          ),
          child: Text(
            'ALLOTMENT TODAY',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.purple.shade300 : Colors.purple.shade800,
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22252A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        child: Text(
          'CLOSED',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
      );
    }

    if (ipo.isUpcoming) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C1E4A) : Colors.purple.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.purple.shade700 : Colors.purple.shade300),
        ),
        child: Text(
          'OPENS ${DateFormat('d MMM').format(ipo.openDate.toLocal()).toUpperCase()}',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.purple.shade300 : Colors.purple.shade800,
          ),
        ),
      );
    }

    // Open IPO: Check if closes today, tomorrow, or in X days
    final localClose = ipo.closeDate.toLocal();
    final closeDay = DateTime(localClose.year, localClose.month, localClose.day);
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = closeDay.difference(today).inDays;
    if (diffDays < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22252A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        ),
        child: Text(
          'CLOSED',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
      );
    } else if (diffDays == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3E2010) : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.deepOrange.shade600 : Colors.deepOrange.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_filled_rounded,
              size: 11,
              color: isDark ? Colors.amber.shade300 : Colors.deepOrange.shade700,
            ),
            const SizedBox(width: 3),
            Text(
              'CLOSES TODAY',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.amber.shade300 : Colors.deepOrange.shade800,
              ),
            ),
          ],
        ),
      );
    } else if (diffDays == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF332A15) : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.orange.shade300),
        ),
        child: Text(
          'CLOSES TOMORROW',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.amber.shade300 : Colors.orange.shade900,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14293D) : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade300),
        ),
        child: Text(
          'CLOSES IN ${diffDays}D',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
          ),
        ),
      );
    }
  }

  Widget _buildIssueSizeBadge(BuildContext context, bool isDark) {
    if (ipo.formattedIssueSize.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      child: Text(
        ipo.formattedIssueSize,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSme = ipo.category == IpoCategory.sme;

    // GMP Trend indicator
    IconData trendIcon;
    Color trendColor;
    switch (ipo.gmpTrend) {
      case GmpTrend.up:
        trendIcon = Icons.trending_up_rounded;
        trendColor = isDark ? Colors.greenAccent.shade400 : Colors.green.shade800;
        break;
      case GmpTrend.down:
        trendIcon = Icons.trending_down_rounded;
        trendColor = isDark ? Colors.redAccent.shade200 : Colors.red.shade800;
        break;
      case GmpTrend.stable:
        trendIcon = Icons.trending_flat_rounded;
        trendColor = isDark ? Colors.tealAccent.shade400 : Colors.teal.shade800;
        break;
    }

    final singleChance = ipo.getRetailAllotmentProbability(accountsCount: 1);
    final syndicateChance = appliedCount > 1
        ? ipo.getRetailAllotmentProbability(accountsCount: appliedCount)
        : singleChance;
    final potentialSyndicateChance = totalSyndicateAccounts > 1
        ? ipo.getRetailAllotmentProbability(accountsCount: totalSyndicateAccounts)
        : singleChance;

    final avatarColor = _getAvatarColor(ipo.symbol);
    final initials = _getInitials(ipo.symbol, ipo.name);

    return Card(
      elevation: isDark ? 0 : 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ZONE 1: Identity & Urgency (Top Row)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Brand Initial Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: isDark ? 0.3 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: avatarColor.withValues(alpha: isDark ? 0.6 : 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: avatarColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Symbol, Name & Issue Size
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                ipo.symbol,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSme
                                    ? (isDark ? const Color(0xFF2C1E4A) : Colors.purple.shade50)
                                    : (isDark ? const Color(0xFF14293D) : Colors.blue.shade50),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSme
                                      ? (isDark ? Colors.purple.shade700 : Colors.purple.shade200)
                                      : (isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                                ),
                              ),
                              child: Text(
                                isSme ? 'SME' : 'MAINBOARD',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSme
                                      ? (isDark ? Colors.purple.shade300 : Colors.purple.shade800)
                                      : (isDark ? Colors.blue.shade300 : Colors.blue.shade800),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ipo.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Urgency / Status Badge
                  _buildStatusPill(context),

                  // Watchlist Star
                  if (onToggleWatchlist != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onToggleWatchlist,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isWatchlisted ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 22,
                          color: isWatchlisted ? Colors.amber.shade600 : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Highlight banner for listed IPO
              if (ipo.isListed) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF132A24) : Colors.teal.shade50.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.teal.shade800 : Colors.teal.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.rocket_launch_rounded, size: 13, color: isDark ? Colors.tealAccent.shade400 : Colors.teal.shade800),
                          const SizedBox(width: 6),
                          Text(
                            'Listed on ${DateFormat('d MMM yyyy').format(ipo.listingDate!)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.tealAccent.shade400 : Colors.teal.shade900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Gain/Lot: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '${ipo.totalGainPerLot >= 0 ? '+' : ''}${CurrencyFormatter.format(ipo.totalGainPerLot)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: ipo.totalGainPerLot >= 0
                                  ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade800)
                                  : (isDark ? Colors.redAccent.shade200 : Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ZONE 2: Valuation & Profit Grid (3-Column Hero Metrics)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF15181F) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    // Col 1: Issue Price (if listed) or Price Range & Lot
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ipo.isListed ? 'ISSUE PRICE' : 'PRICE (LOT: ${ipo.lotSize})',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ipo.isListed
                                ? '₹${ipo.pricePerShare.toStringAsFixed(1)}'
                                : (ipo.minPrice == ipo.maxPrice
                                    ? '₹${ipo.pricePerShare.toStringAsFixed(0)}'
                                    : '₹${ipo.minPrice.toStringAsFixed(0)} - ₹${ipo.maxPrice.toStringAsFixed(0)}'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ipo.lotSize} shares • ${CurrencyFormatter.format(ipo.lotCost)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 36,
                      width: 1,
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                    const SizedBox(width: 10),

                    // Col 2: Listing Price (if listed) or GMP
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ipo.isListed ? 'LISTING PRICE' : 'GMP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (ipo.isListed) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ipo.listingGainPercent >= 0
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 13,
                                  color: ipo.listingGainPercent >= 0
                                      ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade800)
                                      : (isDark ? Colors.redAccent.shade200 : Colors.red.shade800),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '₹${ipo.effectiveListingPrice.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: ipo.listingGainPercent >= 0
                                          ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade800)
                                          : (isDark ? Colors.redAccent.shade200 : Colors.red.shade800),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ipo.listingGainPercent >= 0 ? '+' : ''}${ipo.listingGainPercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: ipo.listingGainPercent >= 0
                                    ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade800)
                                    : (isDark ? Colors.redAccent.shade200 : Colors.red.shade800),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else if (ipo.effectiveGmp > 0) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  trendIcon,
                                  size: 13,
                                  color: trendColor,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '+₹${ipo.effectiveGmp.toStringAsFixed(0)} (+${ipo.gmpPercent.toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: trendColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'List: ₹${ipo.estimatedListingPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else ...[
                            Text(
                              '-- (0%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'At Cut-off',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    Container(
                      height: 36,
                      width: 1,
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                    const SizedBox(width: 10),

                    // Col 3: Current Price (if listed) or Gain / Lot
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            ipo.isListed ? 'CURRENT PRICE' : 'EST. GAIN / LOT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (ipo.isListed) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ipo.gainFromIssuePrice >= 0
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 13,
                                  color: ipo.gainFromIssuePrice >= 0
                                      ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade800)
                                      : (isDark ? Colors.redAccent.shade200 : Colors.red.shade800),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    '₹${ipo.effectiveCurrentPrice.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: ipo.gainFromIssuePrice >= 0
                                          ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade800)
                                          : (isDark ? Colors.redAccent.shade200 : Colors.red.shade800),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ipo.gainPercentFromIssuePrice >= 0 ? '+' : ''}${ipo.gainPercentFromIssuePrice.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: ipo.gainFromIssuePrice >= 0
                                    ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade800)
                                    : (isDark ? Colors.redAccent.shade200 : Colors.red.shade800),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else ...[
                            Text(
                              ipo.effectiveGmp > 0
                                  ? '+${CurrencyFormatter.format(ipo.estimatedListingGainPerLot)}'
                                  : '₹0',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ipo.effectiveGmp > 0
                                    ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade800)
                                    : Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Per Lot',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ZONE 3: Subscription & Syndicate Intelligence Strip
              if (ipo.retailSubscription > 0 || ipo.totalSubscription > 0) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: onShowSubscription ??
                      () => SubscriptionBreakdownSheet.show(context, ipo, onApply: onApply),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131F33)
                          : Colors.blueGrey.shade50.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.pie_chart_outline,
                              size: 14,
                              color: isDark ? Colors.blue.shade300 : Colors.blueGrey.shade800,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sub: ${ipo.retailSubscription.toStringAsFixed(1)}x RII • ${ipo.totalSubscription.toStringAsFixed(1)}x Total',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.blue.shade200 : Colors.blueGrey.shade900,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: isDark ? Colors.blue.shade300 : Colors.blueGrey.shade600,
                            ),
                          ],
                        ),
                        Text(
                          appliedCount > 1
                              ? 'Win: ${syndicateChance.toStringAsFixed(1)}% ($appliedCount)'
                              : (totalSyndicateAccounts > 1 && ipo.retailSubscription > 0
                                  ? 'Win: ${singleChance.toStringAsFixed(0)}% → ${potentialSyndicateChance.toStringAsFixed(0)}% ($totalSyndicateAccounts)'
                                  : '~${singleChance.toStringAsFixed(1)}% chance'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ZONE 4: Footer & Action Zone (Clean, Spacious, Uncramped Buttons)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Bidding Dates & Applied Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ipo.isListed) ...[
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 3,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.rocket_launch_rounded,
                                    size: 13,
                                    color: isDark ? Colors.tealAccent.shade400 : Colors.teal.shade700,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Listed on ${DateFormat('d MMM yyyy').format(ipo.listingDate!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.tealAccent.shade400 : Colors.teal.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              if (ipo.formattedIssueSize.isNotEmpty)
                                _buildIssueSizeBadge(context, isDark),
                            ],
                          ),
                        ] else if (ipo.isAllotmentOut) ...[
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 3,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_available_outlined,
                                    size: 13,
                                    color: isDark ? Colors.indigoAccent.shade200 : Colors.indigo.shade700,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    ipo.listingDate != null
                                        ? 'Listing on ${DateFormat('d MMM yyyy').format(ipo.listingDate!)}'
                                        : 'Allotted • Awaiting Listing',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.indigoAccent.shade200 : Colors.indigo.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              if (ipo.formattedIssueSize.isNotEmpty)
                                _buildIssueSizeBadge(context, isDark),
                            ],
                          ),
                        ] else ...[
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 3,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 13,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${DateFormat('d MMM').format(ipo.openDate)} - ${DateFormat('d MMM').format(ipo.closeDate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              if (ipo.formattedIssueSize.isNotEmpty)
                                _buildIssueSizeBadge(context, isDark),
                            ],
                          ),
                        ],
                        if (appliedCount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B382B) : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? Colors.green.shade700 : Colors.green.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$appliedCount Applied',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Right: Action Buttons with generous padding
                  if (ipo.isOpen) ...[
                    // Stage 2: Bidding OPEN -> Apply Syndicate / Apply More ONLY. NEVER show Allotment!
                    ElevatedButton.icon(
                      onPressed: onApply,
                      icon: const Icon(Icons.flash_on, size: 15),
                      label: Text(appliedCount > 0 ? 'Apply More' : 'Apply Syndicate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade800,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else if (ipo.isClosed && !ipo.isAllotmentOut) ...[
                    // Stage 3: Bidding CLOSED & Awaiting Allotment -> View Bids or subtle 'Bidding Closed'
                    if (appliedCount > 0 && onViewApplications != null) ...[
                      OutlinedButton.icon(
                        onPressed: onViewApplications,
                        icon: const Icon(Icons.assignment_outlined, size: 15),
                        label: Text('View Bids ($appliedCount)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          foregroundColor: isDark ? Colors.indigo.shade300 : Colors.indigo.shade800,
                          side: BorderSide(
                            color: isDark ? Colors.indigo.shade700 : Colors.indigo.shade300,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Bidding Closed',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ] else if ((ipo.isAllotmentOut || ipo.isAllottedOrListed) &&
                      onCheckAllotment != null) ...[
                    // Stage 4 & 5: Allotment Out / Listed -> Check Allotment
                    ElevatedButton.icon(
                      onPressed: onCheckAllotment,
                      icon: const Icon(Icons.verified_outlined, size: 15),
                      label: const Text('Check Allotment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.teal.shade700 : Colors.teal.shade800,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
